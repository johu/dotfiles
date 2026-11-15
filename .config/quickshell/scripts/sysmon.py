#!/usr/bin/env python3
"""Collector for the launcher's system view: one JSON object per second.

Runs only while the view is open (QML starts and stops it) and reads /proc and
/sys directly, so there are no per-sample process spawns. Output keys:
  cpu {total, cores[], freqMhz, maxMhz, model, cores, threads, load[3], ctxt,
       procs, threadsTotal}
  mem {total, used, avail, free, cached, buffers, swapTotal, swapUsed}
  gpu [{name, util, vramUsed, vramTotal, temp, power, powerLimit, fan,
        clock, memClock, vendor}]
  disks [{name, model, size, readBps, writeBps, util, temp}]
  mounts [{mount, device, fs, used, total, percent}]   (every 5 s)
  net [{name, kind, state, ip, speed, rxBps, txBps, rxTotal, txTotal}]
  temps [{chip, label, value}], fans [{chip, label, rpm}], cpuTemp
  battery {status, percent, powerW, energyNow, energyFull, energyDesign,
           secondsLeft, ac, cycles} | null
  uptime, host, kernel, uid
  procs [{pid, ppid, name, exe, user, uid, cpu, mem, threads, io, cmd,
          kernel}]                                       (every 2 s)
The process list's cpu is a percentage of ONE core (like top).
Set SYSMON_PSU to a directory to read a fake power_supply tree (testing).
"""
import glob
import json
import os
import pwd
import re
import socket
import struct
import subprocess
import sys
import threading
import time
import fcntl

PAGE = os.sysconf("SC_PAGE_SIZE")
CLK = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count() or 1
UID = os.getuid()
PSU = os.environ.get("SYSMON_PSU", "/sys/class/power_supply")


def rd(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def num(path, default=None):
    v = rd(path)
    try:
        return float(v)
    except ValueError:
        return default


# ---------------------------------------------------------------- CPU
def read_cpu_times():
    out = {}
    ctxt = 0
    for line in rd("/proc/stat").splitlines():
        if line.startswith("cpu"):
            parts = line.split()
            vals = [int(x) for x in parts[1:9]]
            out[parts[0]] = (sum(vals), vals[3] + vals[4])  # total, idle+iowait
        elif line.startswith("ctxt"):
            ctxt = int(line.split()[1])
    return out, ctxt


def cpu_model():
    model = ""
    phys = set()
    pid = cid = None
    for line in rd("/proc/cpuinfo").splitlines():
        if line.startswith("model name") and not model:
            model = line.split(":", 1)[1].strip()
        elif line.startswith("physical id"):
            pid = line.split(":", 1)[1].strip()
        elif line.startswith("core id"):
            cid = line.split(":", 1)[1].strip()
            phys.add((pid, cid))
    return model, len(phys) or NCPU


MODEL, PHYS = cpu_model()


def cpu_freqs():
    cur = []
    for i in range(NCPU):
        v = num(f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_cur_freq")
        if v:
            cur.append(v / 1000.0)
    return cur


# ---------------------------------------------------------------- memory
def read_mem():
    m = {}
    for line in rd("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        m[k] = int(v.split()[0]) * 1024 if v.split() else 0
    total = m.get("MemTotal", 0)
    avail = m.get("MemAvailable", 0)
    return {
        "total": total,
        "used": total - avail,
        "avail": avail,
        "free": m.get("MemFree", 0),
        "cached": m.get("Cached", 0) + m.get("SReclaimable", 0),
        "buffers": m.get("Buffers", 0),
        "swapTotal": m.get("SwapTotal", 0),
        "swapUsed": m.get("SwapTotal", 0) - m.get("SwapFree", 0),
    }


# ---------------------------------------------------------------- hwmon
def read_hwmon():
    temps, fans, chips = [], [], {}
    for d in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        chip = rd(d + "/name") or os.path.basename(d)
        dev = os.path.basename(os.path.realpath(d + "/device")) if os.path.exists(d + "/device") else ""
        chips[chip + ":" + dev] = d
        for f in sorted(glob.glob(d + "/temp*_input")):
            n = re.search(r"temp(\d+)_input", f).group(1)
            v = num(f)
            if v is None:
                continue
            label = rd(f"{d}/temp{n}_label") or f"temp{n}"
            temps.append({"chip": chip, "dev": dev, "label": label, "value": round(v / 1000.0, 1)})
        for f in sorted(glob.glob(d + "/fan*_input")):
            n = re.search(r"fan(\d+)_input", f).group(1)
            v = num(f)
            if v is not None:
                fans.append({"chip": chip, "label": rd(f"{d}/fan{n}_label") or f"fan{n}", "rpm": int(v)})
    return temps, fans


def pick_cpu_temp(temps):
    for want in (("k10temp", "Tctl"), ("k10temp", "Tdie"), ("coretemp", "Package id 0"), ("zenpower", "Tdie")):
        for t in temps:
            if t["chip"] == want[0] and t["label"] == want[1]:
                return t["value"]
    for t in temps:
        if t["chip"] in ("k10temp", "coretemp", "zenpower", "cpu_thermal"):
            return t["value"]
    vals = [num(p) for p in glob.glob("/sys/class/thermal/thermal_zone*/temp")]
    vals = [v / 1000.0 for v in vals if v]
    return max(vals) if vals else None


# ---------------------------------------------------------------- GPU
class Gpu:
    """nvidia-smi streamed in the background (one process, loops itself)."""

    def __init__(self):
        self.nv = []
        self.proc = None
        if any(os.access(os.path.join(p, "nvidia-smi"), os.X_OK) for p in os.environ.get("PATH", "").split(":")):
            threading.Thread(target=self.run_nvidia, daemon=True).start()

    def run_nvidia(self):
        q = "name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed,clocks.gr,clocks.mem"
        try:
            self.proc = subprocess.Popen(["nvidia-smi", f"--query-gpu={q}", "--format=csv,noheader,nounits", "-l", "1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            return
        for line in self.proc.stdout:
            gpus = []
            # several GPUs arrive as consecutive lines within one second; keep the last batch per name
            parts = [p.strip() for p in line.split(",")]
            if len(parts) < 10:
                continue

            def f(x):
                try:
                    return float(x)
                except ValueError:
                    return None

            gpus.append({"name": parts[0], "vendor": "nvidia", "util": f(parts[1]), "vramUsed": (f(parts[2]) or 0) * 1048576, "vramTotal": (f(parts[3]) or 0) * 1048576, "temp": f(parts[4]), "power": f(parts[5]), "powerLimit": f(parts[6]), "fan": f(parts[7]), "clock": f(parts[8]), "memClock": f(parts[9])})
            by = {g["name"] + str(i): g for i, g in enumerate(self.nv)}
            self.nv = [g for g in self.nv if g["name"] != gpus[0]["name"]] + gpus

    def amd(self):
        out = []
        for card in sorted(glob.glob("/sys/class/drm/card[0-9]")):
            dev = card + "/device"
            if rd(dev + "/vendor") != "0x1002":
                continue
            hw = (glob.glob(dev + "/hwmon/hwmon*") or [None])[0]
            out.append({
                "name": rd(dev + "/product_name") or "AMD GPU",
                "vendor": "amd",
                "util": num(dev + "/gpu_busy_percent"),
                "vramUsed": num(dev + "/mem_info_vram_used") or 0,
                "vramTotal": num(dev + "/mem_info_vram_total") or 0,
                "temp": (num(hw + "/temp1_input") or 0) / 1000.0 if hw else None,
                "power": (num(hw + "/power1_average") or 0) / 1e6 if hw else None,
                "powerLimit": (num(hw + "/power1_cap") or 0) / 1e6 if hw else None,
                "fan": None,
                "clock": None,
                "memClock": None,
            })
        return out

    def sample(self):
        return list(self.nv) + self.amd()


# ---------------------------------------------------------------- disks / net / mounts
DISK_RE = re.compile(r"^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|mmcblk\d+)$")


def read_diskstats():
    out = {}
    for line in rd("/proc/diskstats").splitlines():
        p = line.split()
        if len(p) < 13 or not DISK_RE.match(p[2]):
            continue
        out[p[2]] = (int(p[5]) * 512, int(p[9]) * 512, int(p[12]))  # read bytes, write bytes, io ms
    return out


def disk_info(name):
    model = rd(f"/sys/block/{name}/device/model") or rd(f"/sys/block/{name}/device/name")
    size = (num(f"/sys/block/{name}/size") or 0) * 512
    return model, size


def read_netdev():
    out = {}
    for line in rd("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        name = name.strip()
        if name == "lo" or re.match(r"^(docker|veth|br-|virbr|vmnet|tun|tap)", name):
            continue
        p = rest.split()
        out[name] = (int(p[0]), int(p[8]))
    return out


def iface_ip(name):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        r = fcntl.ioctl(s.fileno(), 0x8915, struct.pack("256s", name[:15].encode()))
        s.close()
        return socket.inet_ntoa(r[20:24])
    except OSError:
        return ""


def read_mounts():
    seen, out = set(), []
    good = {"ext4", "ext3", "xfs", "btrfs", "f2fs", "vfat", "ntfs", "ntfs3", "exfat", "zfs", "bcachefs", "fuseblk"}
    for line in rd("/proc/mounts").splitlines():
        p = line.split()
        if len(p) < 3 or p[2] not in good or not p[0].startswith("/dev/") or p[0] in seen:
            continue
        seen.add(p[0])
        mnt = p[1].replace("\\040", " ")
        try:
            st = os.statvfs(mnt)
        except OSError:
            continue
        total = st.f_blocks * st.f_frsize
        used = (st.f_blocks - st.f_bfree) * st.f_frsize
        avail = st.f_bavail * st.f_frsize
        if total <= 0:
            continue
        out.append({"mount": mnt, "device": p[0], "fs": p[2], "used": used, "total": total, "percent": round(100.0 * used / max(1, used + avail), 1)})
    return out


# ---------------------------------------------------------------- battery
def read_battery():
    bats = sorted(glob.glob(PSU + "/BAT*"))
    if not bats:
        return None
    b = bats[0]
    ac = any(rd(p + "/online") == "1" for p in glob.glob(PSU + "/A*") + glob.glob(PSU + "/*AC*"))
    status = rd(b + "/status")
    cap = num(b + "/capacity")
    now = num(b + "/energy_now")
    full = num(b + "/energy_full")
    design = num(b + "/energy_full_design")
    power = num(b + "/power_now")
    if now is None:  # charge-based batteries
        v = (num(b + "/voltage_now") or 0) / 1e6
        c_now, c_full, c_des, cur = (num(b + "/charge_now"), num(b + "/charge_full"), num(b + "/charge_full_design"), num(b + "/current_now"))
        if c_now is not None:
            now, full, design = c_now * v, (c_full or 0) * v, (c_des or 0) * v
            power = (cur or 0) * v if power is None else power
    watts = (power or 0) / 1e6
    secs = None
    if watts > 0.5 and now is not None and full is not None:
        if status == "Discharging":
            secs = int(now / (watts * 1e6) * 3600)
        elif status == "Charging":
            secs = int(max(0.0, full - now) / (watts * 1e6) * 3600)
    return {"status": status, "percent": cap, "powerW": round(watts, 2), "energyNow": (now or 0) / 1e6, "energyFull": (full or 0) / 1e6, "energyDesign": (design or 0) / 1e6, "secondsLeft": secs, "ac": ac, "cycles": num(b + "/cycle_count")}


# ---------------------------------------------------------------- processes
class Procs:
    def __init__(self):
        self.prev = {}      # pid -> (ticks, start, io_bytes)
        self.static = {}    # (pid, start) -> (exe, cmd, kernel)
        self.users = {}
        self.last = time.monotonic()

    def user(self, uid):
        if uid not in self.users:
            try:
                self.users[uid] = pwd.getpwuid(uid).pw_name
            except KeyError:
                self.users[uid] = str(uid)
        return self.users[uid]

    def sample(self):
        now = time.monotonic()
        dt = max(0.001, now - self.last)
        self.last = now
        out, prev = [], {}
        for ent in os.listdir("/proc"):
            if not ent.isdigit():
                continue
            pid = int(ent)
            try:
                with open(f"/proc/{pid}/stat") as f:
                    stat = f.read()
                rp = stat.rindex(")")
                comm = stat[stat.index("(") + 1:rp]
                rest = stat[rp + 2:].split()
                ppid = int(rest[1])
                ticks = int(rest[11]) + int(rest[12])
                threads = int(rest[17])
                start = int(rest[19])
                rss = int(rest[21]) * PAGE
                uid = os.stat(f"/proc/{pid}").st_uid
            except (OSError, ValueError, IndexError):
                continue
            key = (pid, start)
            if key not in self.static:
                exe, cmd, kernel = "", "", False
                try:
                    exe = os.path.basename(os.readlink(f"/proc/{pid}/exe")).replace(" (deleted)", "")
                except OSError:
                    pass
                try:
                    with open(f"/proc/{pid}/cmdline", "rb") as f:
                        raw = f.read(400)
                    cmd = raw.replace(b"\0", b" ").decode("utf-8", "replace").strip()
                except OSError:
                    pass
                kernel = pid == 2 or ppid == 2 or (exe == "" and cmd == "" and rss == 0)
                self.static[key] = (exe, cmd[:160], kernel)
            exe, cmd, kernel = self.static[key]
            io = 0
            if uid == UID:
                rb = wb = 0
                try:
                    for line in open(f"/proc/{pid}/io"):
                        if line.startswith("read_bytes"):
                            rb = int(line.split()[1])
                        elif line.startswith("write_bytes"):
                            wb = int(line.split()[1])
                except OSError:
                    pass
                io = rb + wb
            p = self.prev.get(pid)
            cpu = 0.0
            iorate = 0
            if p and p[1] == start:
                cpu = max(0.0, (ticks - p[0]) / CLK / dt * 100.0)
                iorate = max(0, int((io - p[2]) / dt))
            prev[pid] = (ticks, start, io)
            out.append({"pid": pid, "ppid": ppid, "name": comm, "exe": exe, "user": self.user(uid), "uid": uid, "cpu": round(cpu, 1), "mem": rss, "threads": threads, "io": iorate, "cmd": cmd, "kernel": kernel})
        self.prev = prev
        if len(self.static) > 4 * len(prev) + 200:
            self.static = {k: v for k, v in self.static.items() if k[0] in prev}
        return out


# ---------------------------------------------------------------- main loop
def main():
    gpu = Gpu()
    procs = Procs()
    cpu0, ctxt0 = read_cpu_times()
    disks0, net0 = read_diskstats(), read_netdev()
    t0 = time.monotonic()
    procs.sample()  # baseline for the cpu deltas
    mounts, tick = read_mounts(), 0
    host = socket.gethostname()
    kernel = os.uname().release
    nxt = time.monotonic() + 1.0
    while True:
        time.sleep(max(0.0, nxt - time.monotonic()))
        nxt += 1.0
        now = time.monotonic()
        dt = max(0.001, now - t0)
        t0 = now
        tick += 1

        cpu1, ctxt1 = read_cpu_times()
        cores = []
        for i in range(NCPU):
            a, b = cpu0.get(f"cpu{i}"), cpu1.get(f"cpu{i}")
            cores.append(round(100.0 * (1 - (b[1] - a[1]) / max(1, b[0] - a[0])), 1) if a and b else 0.0)
        a, b = cpu0.get("cpu"), cpu1.get("cpu")
        total = round(100.0 * (1 - (b[1] - a[1]) / max(1, b[0] - a[0])), 1)
        freqs = cpu_freqs()
        load = rd("/proc/loadavg").split()
        running_threads = load[3].split("/") if len(load) > 3 else ["0", "0"]
        temps, fans = read_hwmon()
        mem = read_mem()

        d1 = read_diskstats()
        disks = []
        for name, v in d1.items():
            p = disks0.get(name)
            if not p:
                continue
            model, size = disk_info(name)
            temp = None
            ctl = re.match(r"(nvme\d+)n\d+", name)
            for t in temps:
                if ctl and t["chip"] == "nvme" and t["dev"] == ctl.group(1) and t["label"] == "Composite":
                    temp = t["value"]
            disks.append({"name": name, "model": model, "size": size, "readBps": int((v[0] - p[0]) / dt), "writeBps": int((v[1] - p[1]) / dt), "util": round(min(100.0, (v[2] - p[2]) / (dt * 10.0)), 1), "temp": temp})

        n1 = read_netdev()
        net = []
        for name, v in n1.items():
            p = net0.get(name)
            if not p:
                continue
            kind = "wifi" if os.path.exists(f"/sys/class/net/{name}/wireless") else "ethernet"
            net.append({"name": name, "kind": kind, "state": rd(f"/sys/class/net/{name}/operstate"), "ip": iface_ip(name), "speed": num(f"/sys/class/net/{name}/speed"), "rxBps": int((v[0] - p[0]) / dt), "txBps": int((v[1] - p[1]) / dt), "rxTotal": v[0], "txTotal": v[1]})

        if tick % 5 == 0:
            mounts = read_mounts()

        obj = {
            "t": time.time(),
            "cpu": {"total": total, "cores": cores, "freqMhz": round(sum(freqs) / len(freqs)) if freqs else None, "maxMhz": round(max(freqs)) if freqs else None, "model": MODEL, "physical": PHYS, "threads": NCPU, "load": [float(x) for x in load[:3]], "ctxt": int((ctxt1 - ctxt0) / dt), "running": int(running_threads[0]), "threadsTotal": int(running_threads[1])},
            "cpuTemp": pick_cpu_temp(temps),
            "mem": mem,
            "gpu": gpu.sample(),
            "disks": disks,
            "mounts": mounts,
            "net": net,
            "temps": temps,
            "fans": fans,
            "battery": read_battery(),
            "uptime": float(rd("/proc/uptime").split()[0]) if rd("/proc/uptime") else 0,
            "host": host,
            "kernel": kernel,
            "uid": UID,
        }
        if tick % 2 == 0:
            obj["procs"] = procs.sample()
            obj["cpu"]["procCount"] = len(obj["procs"])
        cpu0, ctxt0, disks0, net0 = cpu1, ctxt1, d1, n1
        try:
            sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, OSError):
            return


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
