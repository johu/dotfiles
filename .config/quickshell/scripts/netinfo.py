#!/usr/bin/env python3
"""NetworkManager helper for the launcher's Network view (all nmcli in one place).

  netinfo.py snapshot [--aps]     JSON: radio, connectivity, devices (ip4 + ip6, gateway, dns,
                                  dns, mac, speed), saved connections (wifi / vpn /
                                  ethernet), active connections and, with --aps, the
                                  access points with band / channel (one entry per
                                  SSID, strongest access point, count of the rest)
  netinfo.py psk UUID             prints the saved Wi-Fi password (empty if none)
  netinfo.py qr UUID              JSON {"rows": ["0101..", ...]} QR code of the Wi-Fi
                                  join string (WIFI:S:..;T:..;P:..;;)
  netinfo.py connect-new SSID SECURITY
                                  create + activate a Wi-Fi profile (hidden network).
                                  SECURITY is wpa-psk | sae | open. The password is read
                                  as ONE LINE from stdin, never from the command line;
                                  it reaches nmcli through a 0600 passwd-file that is
                                  removed afterwards. A profile that fails to activate
                                  is deleted again.

Secrets never appear in an argument list (those are world readable in /proc).
Test hook: NETINFO_NMCLI=/path/to/fake-nmcli replaces the nmcli binary.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import uuid as uuidlib

NMCLI = os.environ.get("NETINFO_NMCLI", "nmcli")


def run(args, stdin=None, timeout=15):
    try:
        p = subprocess.run([NMCLI] + args, capture_output=True, text=True, timeout=timeout, input=stdin)
        return p.returncode, p.stdout, p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, "", str(e)


def split_t(line):
    """Split a terse (-t) nmcli line on unescaped colons and unescape."""
    out, cur, esc = [], [], False
    for ch in line:
        if esc:
            cur.append(ch)
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def lines(args):
    rc, out, _ = run(args)
    return [l for l in out.split("\n") if l] if rc == 0 else []


def devices():
    res = []
    for l in lines(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]):
        dev, typ, state, conn = (split_t(l) + ["", "", "", ""])[:4]
        if typ not in ("ethernet", "wifi"):
            continue
        d = {"name": dev, "type": typ, "state": state, "connection": conn, "hwaddr": "", "speed": "", "ip4": [], "gateway": "", "dns": [], "ip6": [], "gateway6": "", "dns6": []}
        for k in lines(["-t", "-f", "GENERAL.HWADDR,CAPABILITIES.SPEED,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS", "device", "show", dev]):
            key, _, val = k.partition(":")
            val = val.replace("\\:", ":")
            if key.startswith("GENERAL.HWADDR"):
                d["hwaddr"] = val
            elif key.startswith("CAPABILITIES.SPEED"):
                d["speed"] = val
            elif key.startswith("IP4.ADDRESS"):
                d["ip4"].append(val)
            elif key.startswith("IP4.GATEWAY"):
                d["gateway"] = val if val != "--" else ""
            elif key.startswith("IP4.DNS"):
                d["dns"].append(val)
            elif key.startswith("IP6.ADDRESS"):
                d["ip6"].append(val)
            elif key.startswith("IP6.GATEWAY"):
                d["gateway6"] = val if val != "--" else ""
            elif key.startswith("IP6.DNS"):
                d["dns6"].append(val)
        res.append(d)
    return res


def conn_field(uid, fields):
    rc, out, _ = run(["-g", ",".join(fields), "connection", "show", "uuid", uid])
    vals = out.split("\n") if rc == 0 else []
    return {f: (vals[i] if i < len(vals) else "") for i, f in enumerate(fields)}


def saved():
    active = {}
    for l in lines(["-t", "-f", "UUID,DEVICE,STATE", "connection", "show", "--active"]):
        u, dev, st = (split_t(l) + ["", "", ""])[:3]
        active[u] = {"device": dev, "state": st}
    res = []
    for l in lines(["-t", "-f", "UUID,TYPE,NAME", "connection", "show"]):
        u, typ, name = (split_t(l) + ["", "", ""])[:3]
        kind = {"802-11-wireless": "wifi", "wifi": "wifi", "vpn": "vpn", "wireguard": "vpn", "802-3-ethernet": "ethernet", "ethernet": "ethernet"}.get(typ)
        if kind is None:
            continue
        base = conn_field(u, ["connection.autoconnect", "connection.timestamp"])
        e = {"uuid": u, "id": name, "type": kind, "autoconnect": base["connection.autoconnect"] == "yes",
             "timestamp": int(base["connection.timestamp"] or 0), "ssid": "", "keyMgmt": "", "hidden": False,
             "active": u in active, "device": active.get(u, {}).get("device", "")}
        if kind == "wifi":
            w = conn_field(u, ["802-11-wireless.ssid", "802-11-wireless-security.key-mgmt", "802-11-wireless.hidden"])
            e["ssid"] = w["802-11-wireless.ssid"]
            e["keyMgmt"] = w["802-11-wireless-security.key-mgmt"]
            e["hidden"] = w["802-11-wireless.hidden"] == "yes"
        elif kind == "vpn":
            e["serviceType"] = conn_field(u, ["vpn.service-type"])["vpn.service-type"].split(".")[-1]
        res.append(e)
    return res


def read_counter(dev, name):
    try:
        with open("/sys/class/net/%s/statistics/%s" % (dev, name)) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None


def aps():
    by = {}
    for l in lines(["-t", "-f", "IN-USE,SSID,BSSID,SIGNAL,FREQ,CHAN,SECURITY,RATE", "device", "wifi", "list", "--rescan", "no"]):
        f = split_t(l)
        if len(f) < 8:
            continue
        use, ssid, bssid, sig, freq, chan, sec, rate = f[:8]
        if not ssid:
            continue
        try:
            sig = int(sig)
            mhz = int(freq.split()[0])
        except ValueError:
            continue
        band = "2.4 GHz" if mhz < 3000 else ("5 GHz" if mhz < 5925 else "6 GHz")
        e = by.get(ssid)
        ap = {"signal": sig, "freq": mhz, "band": band, "chan": chan, "bssid": bssid, "security": sec, "inuse": use == "*", "rate": rate}
        if e is None:
            by[ssid] = {"ssid": ssid, "best": ap, "count": 1, "inuse": ap["inuse"]}
        else:
            e["count"] += 1
            e["inuse"] = e["inuse"] or ap["inuse"]
            if sig > e["best"]["signal"]:
                e["best"] = ap
    return list(by.values())


def snapshot(with_aps):
    _, radio, _ = run(["-t", "-f", "WIFI,WIFI-HW", "radio"])
    wifi, _, hw = radio.strip().partition(":")
    out = {
        "time": int(time.time()),
        "radio": {"wifi": wifi == "enabled", "wifiHw": hw.strip() == "enabled"},
        "connectivity": (run(["-t", "-f", "CONNECTIVITY", "general"])[1].strip() or "unknown"),
        "devices": devices(),
        "saved": saved(),
    }
    for s in out["saved"]:
        if s["type"] == "vpn" and s["active"] and s["device"]:
            s["rx"] = read_counter(s["device"], "rx_bytes")
            s["tx"] = read_counter(s["device"], "tx_bytes")
    if with_aps:
        out["aps"] = aps()
    return out


def wifi_esc(s):
    return re.sub(r'([\\;,:"])', r"\\\1", s)


def get_psk(uid):
    rc, out, _ = run(["-s", "-g", "802-11-wireless-security.psk", "connection", "show", "uuid", uid])
    return out.rstrip("\n") if rc == 0 else ""


def qr(uid):
    info = conn_field(uid, ["802-11-wireless.ssid", "802-11-wireless-security.key-mgmt", "802-11-wireless.hidden"])
    ssid = info["802-11-wireless.ssid"]
    km = info["802-11-wireless-security.key-mgmt"]
    if not ssid:
        print(json.dumps({"error": "not a Wi-Fi connection"}))
        return 1
    if km == "":
        payload = "WIFI:S:%s;T:nopass;;" % wifi_esc(ssid)
    elif km in ("wpa-psk", "sae"):
        psk = get_psk(uid)
        if not psk:
            print(json.dumps({"error": "password not stored"}))
            return 1
        payload = "WIFI:S:%s;T:WPA;P:%s;%s;" % (wifi_esc(ssid), wifi_esc(psk), "H:true;" if info["802-11-wireless.hidden"] == "yes" else "")
    else:
        print(json.dumps({"error": "unsupported security (" + km + ")"}))
        return 1
    try:
        p = subprocess.run(["qrencode", "-t", "ASCII", "-m", "1", "-o", "-"], input=payload, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        print(json.dumps({"error": "qrencode missing"}))
        return 1
    if p.returncode != 0:
        print(json.dumps({"error": "qrencode failed"}))
        return 1
    rows = []
    for l in p.stdout.split("\n"):
        if not l:
            continue
        rows.append("".join("1" if l[i:i + 2] == "##" else "0" for i in range(0, len(l) - 1, 2)))
    print(json.dumps({"rows": rows}))
    return 0


def connect_new(ssid, sec):
    pw = sys.stdin.readline().rstrip("\n") if sec != "open" else ""
    if sec not in ("wpa-psk", "sae", "open"):
        print("bad security", file=sys.stderr)
        return 2
    if sec != "open" and len(pw) < 8:
        print("password too short", file=sys.stderr)
        return 2
    uid = str(uuidlib.uuid4())
    add = ["connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid, "connection.uuid", uid, "wifi.hidden", "yes"]
    if sec != "open":
        add += ["wifi-sec.key-mgmt", sec]
    rc, _, err = run(add)
    if rc != 0:
        print(err.strip(), file=sys.stderr)
        return rc
    path = None
    try:
        up = ["--wait", "30", "connection", "up", "uuid", uid]
        if sec != "open":
            fd, path = tempfile.mkstemp(prefix="qs-nm.", dir=os.environ.get("XDG_RUNTIME_DIR") or None)
            os.chmod(path, 0o600)
            with os.fdopen(fd, "w") as f:
                f.write("802-11-wireless-security.psk:%s\n" % pw)
            up += ["passwd-file", path]
        rc, _, err = run(up, timeout=45)
    finally:
        if path:
            try:
                os.unlink(path)
            except OSError:
                pass
    if rc != 0:
        run(["connection", "delete", "uuid", uid])
        print(err.strip(), file=sys.stderr)
        return rc
    return 0


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "snapshot":
        print(json.dumps(snapshot("--aps" in argv)))
        return 0
    if cmd == "psk" and len(argv) == 3:
        print(get_psk(argv[2]))
        return 0
    if cmd == "qr" and len(argv) == 3:
        return qr(argv[2])
    if cmd == "connect-new" and len(argv) == 4:
        return connect_new(argv[2], argv[3])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
