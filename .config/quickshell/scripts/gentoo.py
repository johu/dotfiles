#!/usr/bin/env python3
"""Data helper for the launcher's Gentoo view (LauncherGentooView.qml).

Usage: gentoo.py [--fixture DIR] SUBCOMMAND [args]
Every subcommand prints one JSON object (or {"text": ...}); nothing needs root.

  sync                     timer / service state, skip conditions, repos, recent runs
  news                     news items (unread / read / hidden) with their text
  news-mark OP [ID ...]    OP: read | unread | purge | allread | purgeall; ID = repo/name
  build                    emerge state, queue of the running session, log tail, history
  build-log ATOM           tail of the newest build log of cat/name-version
  housekeeping [--refresh] config files, depclean, distfiles, kernels, orphans (cached 30 min)
  stats [--refresh]        counts per repo / EAPI / category, slowest builds (cached 6 h)
  glsa [--refresh]         security advisories that affect this system (cached 6 h)
  glsa-text ID             the advisory text
  live [--refresh]         installed live ebuilds, built age, upstream hash via smart-live-rebuild -p (cached 30 min)\n  flatpak [--refresh]      pending flatpak updates (cached 30 min)\n  pause [on|off|toggle]    flag file ~/.cache/portage-sync-paused
  sync-now                 drops the sync stamp and starts portage-sync.service

--fixture DIR prints DIR/SUBCOMMAND.json instead (tests, mockups).
"""
import json
import os
import re
import subprocess
import sys
import time
import glob

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", HOME + "/.cache"), "quickshell", "gentoo")
NEWS_DIR = "/var/lib/gentoo/news"
PAUSE_FLAG = os.path.join(HOME, ".cache", "portage-sync-paused")
SYNC_STAMP = os.path.join(HOME, ".cache", "portage-sync.stamp")
GAMEMODE = os.path.join(HOME, ".cache", "gamemode")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def run(cmd, timeout=120, env=None):
    """stdout of a command (ANSI stripped), "" when it cannot run."""
    try:
        e = dict(os.environ, LC_ALL="C.UTF-8", **(env or {}))
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=e)
        return ANSI.sub("", p.stdout + (p.stderr if env and env.get("_ERR") else ""))
    except Exception:
        return ""


def run_all(cmd, timeout=120):
    """stdout + stderr (portage prints some tables on stderr)."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return ANSI.sub("", p.stdout + "\n" + p.stderr)
    except Exception:
        return ""


def emit(obj):
    sys.stdout.write(json.dumps(obj))
    sys.stdout.write("\n")


def read(path, default=""):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except OSError:
        return default


def envvars():
    out = run(["portageq", "envvar", "-v", "PORT_LOGDIR", "PORTAGE_TMPDIR", "DISTDIR", "PKGDIR", "CONFIG_PROTECT"])
    d = {}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            d[k] = v.strip('"')
    return d


def repos():
    """[{name, location, sync, priority}] from portage's own configuration."""
    out = run(["portageq", "repositories_configuration", "/"])
    res, cur = [], None
    for line in out.splitlines():
        m = re.match(r"\[(.+)\]$", line.strip())
        if m:
            cur = {"name": m.group(1)}
            if cur["name"] != "DEFAULT":
                res.append(cur)
            continue
        if cur is not None and "=" in line:
            k, v = [s.strip() for s in line.split("=", 1)]
            if k in ("location", "sync-type", "priority", "auto-sync"):
                cur[k] = v
    return [{"name": r["name"], "location": r.get("location", ""), "sync": r.get("sync-type", ""),
             "priority": int(r["priority"]) if r.get("priority", "").lstrip("-").isdigit() else 0,
             "autoSync": r.get("auto-sync", "") in ("yes", "true")} for r in res if r.get("location")]


def installed_pkgs():
    """[(category, pf, repository, eapi)] from the vdb."""
    res = []
    for d in glob.glob("/var/db/pkg/*/*"):
        cat = d.split("/")[-2]
        pf = d.split("/")[-1]
        res.append((cat, pf, read(d + "/repository").strip(), read(d + "/EAPI").strip()))
    return res


def count_ebuilds(location):
    out = run(["find", location, "-mindepth", "3", "-maxdepth", "3", "-name", "*.ebuild"])
    return out.count("\n")


def cached(name, max_age, refresh, fn):
    path = os.path.join(CACHE, name + ".json")
    if not refresh:
        try:
            if time.time() - os.path.getmtime(path) < max_age:
                with open(path) as f:
                    return json.load(f)
        except Exception:
            pass
    t0 = time.time()
    data = fn()
    data["checkedEpoch"] = int(time.time())
    data["tookSeconds"] = round(time.time() - t0, 1)
    try:
        os.makedirs(CACHE, exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f)
        os.replace(tmp, path)
    except OSError:
        pass
    return data


def emerge_running():
    out = run(["pgrep", "-x", "emerge", "-a"])
    return any(l.strip() and "-pvuDN @world" not in l and "--pretend" not in l and " -p " not in l
               for l in out.splitlines())


# ---------------------------------------------------------------- sync

def cmd_sync():
    tm = {}
    try:
        timers = json.loads(run(["systemctl", "--user", "list-timers", "portage-sync.timer", "--output=json"]) or "[]")
        if timers:
            tm = timers[0]
    except Exception:
        pass
    show = run(["systemctl", "--user", "show", "portage-sync.timer", "-p", "ActiveState,TimersMonotonic"])
    active = "ActiveState=active" in show
    intervals = re.findall(r"On(Active|UnitActive)USec=([^ ;}]+(?: \d+\w+)*)", show)
    interval = ""
    for kind, v in intervals:
        if kind == "UnitActive":
            interval = v.strip()
    first = ""
    for kind, v in intervals:
        if kind == "Active":
            first = v.strip()
    svc = run(["systemctl", "--user", "show", "portage-sync.service", "-p", "ActiveState,Result,ExecMainStatus"])
    svc_d = dict(l.split("=", 1) for l in svc.splitlines() if "=" in l)

    sync_epoch = 0
    try:
        sync_epoch = int(os.path.getmtime("/var/cache/eix/portage.eix"))
    except OSError:
        pass

    # real sync history (emerge.log "=== sync" entries, via qlop): epoch, repo, seconds
    syncs = []
    for line in run(["qlop", "-s", "-t", "-M", "-C"]).splitlines():
        m = re.match(r"(\d+) \*\*\* (.+?): (\d+)", line)
        if m:
            syncs.append((int(m.group(1)), m.group(2), int(m.group(3))))

    # journal: one entry per timer run; skip reasons are written by portage-sync.sh
    runs = []
    cur = None
    for line in run(["journalctl", "--user", "-u", "portage-sync.service", "--no-pager", "-o", "short-unix",
                     "--since", "-4d"]).splitlines():
        m = re.match(r"(\d+)\.\d+ \S+ (.*)", line)
        if not m:
            continue
        ts, msg = int(m.group(1)), m.group(2)
        if "Starting " in msg:
            cur = {"epoch": ts, "result": "ok", "detail": ""}
            runs.append(cur)
        elif cur is not None and "skipping" in msg:
            cur["result"] = "skipped"
            r = re.search(r"portage-sync\.sh: (.*?)(,| skipping|$)", msg)
            cur["detail"] = r.group(1) if r else "skipped"
            cur["detail"] = cur["detail"].replace("last sync ", "last sync ").strip()
        elif cur is not None and ("Failed" in msg or "never appeared" in msg or "no herdr client" in msg and "found" in msg):
            cur["result"] = "failed"
            cur["detail"] = msg.split(": ", 1)[-1][:120]
    for r in runs:
        if r["result"] == "ok":
            hit = [s for s in syncs if 0 <= s[0] - r["epoch"] <= 900]
            if hit:
                r["detail"] = "%s %d s" % (hit[0][1], hit[0][2])
    runs = runs[-8:][::-1]

    # repos
    inst = {}
    for _cat, _pf, repo, _eapi in installed_pkgs():
        inst[repo] = inst.get(repo, 0) + 1
    rlist = []
    for r in repos():
        loc = r["location"]
        entry = {"name": r["name"], "location": loc, "type": "git" if os.path.isdir(loc + "/.git") else
                 ("local" if not r["sync"] else r["sync"]), "head": "", "commitEpoch": 0, "subject": "",
                 "ebuilds": count_ebuilds(loc), "installed": inst.get(r["name"], 0), "priority": r["priority"],
                 "autoSync": r["autoSync"], "sync": r["sync"]}
        if entry["type"] == "git":
            out = run(["git", "-C", loc, "log", "-1", "--format=%H%x1f%ct%x1f%s"]).strip().split("\x1f")
            if len(out) == 3:
                entry["head"], entry["commitEpoch"], entry["subject"] = out[0][:8], int(out[1]), out[2]
        rlist.append(entry)
    rlist.sort(key=lambda e: (e["name"] != "gentoo", e["type"] == "local", -e["ebuilds"]))

    emit({
        "timerActive": active, "interval": interval, "first": first,
        "nextEpoch": int(tm.get("next", 0) / 1e6) if tm.get("next") else 0,
        "lastTriggerEpoch": int(tm.get("last", 0) / 1e6) if tm.get("last") else 0,
        "service": svc_d.get("ActiveState", ""), "result": svc_d.get("Result", ""),
        "gamemode": os.path.exists(GAMEMODE), "paused": os.path.exists(PAUSE_FLAG),
        "emergeRunning": emerge_running(), "lastSyncEpoch": sync_epoch,
        "world": len([l for l in read("/var/lib/portage/world").splitlines() if l.strip()]),
        "repos": rlist, "runs": runs,
    })


def cmd_pause(arg):
    cur = os.path.exists(PAUSE_FLAG)
    want = (not cur) if arg in ("", "toggle") else arg == "on"
    if want and not cur:
        open(PAUSE_FLAG, "w").close()
    elif not want and cur:
        os.remove(PAUSE_FLAG)
    emit({"paused": os.path.exists(PAUSE_FLAG)})


def cmd_sync_now():
    # portage-sync.sh refuses a second sync within 3 h of the stamp (a guard against
    # daemon-reload re-arming the timer); an explicit request must bypass it.
    try:
        os.remove(SYNC_STAMP)
    except OSError:
        pass
    subprocess.run(["systemctl", "--user", "start", "--no-block", "portage-sync.service"])
    emit({"started": True})


# ---------------------------------------------------------------- news

def news_dirs():
    return {r["name"]: r["location"] for r in repos()}


def news_list_file(repo, stat):
    return [l.strip() for l in read("%s/news-%s.%s" % (NEWS_DIR, repo, stat)).splitlines() if l.strip()]


def news_write(repo, stat, items):
    path = "%s/news-%s.%s" % (NEWS_DIR, repo, stat)
    with open(path, "w") as f:  # in place: the directory is group-writable, not sticky-safe for rename
        for i in items:
            f.write(i + "\n")


def parse_news(path):
    txt = read(path)
    head, _, body = txt.partition("\n\n")
    meta = {}
    for line in head.splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta.setdefault(k.strip(), v.strip())
    return meta, body.strip("\n")


def cmd_news():
    items = []
    dirs = news_dirs()
    for repo, loc in dirs.items():
        unread = set(news_list_file(repo, "unread"))
        rd = set(news_list_file(repo, "read"))
        skip = set(news_list_file(repo, "skip"))
        for name in sorted(unread | rd | skip):
            state = "unread" if name in unread else ("read" if name in rd else "hidden")
            f = "%s/metadata/news/%s/%s.en.txt" % (loc, name, name)
            if not os.path.exists(f):
                alt = glob.glob("%s/metadata/news/%s/*.txt" % (loc, name))
                f = alt[0] if alt else ""
            meta, body = parse_news(f) if f else ({}, "")
            items.append({"id": repo + "/" + name, "repo": repo, "name": name,
                          "title": meta.get("Title", name), "posted": meta.get("Posted", name[:10]),
                          "author": meta.get("Author", ""), "revision": meta.get("Revision", ""),
                          "state": state, "removed": not f, "body": body})
    items.sort(key=lambda i: i["name"], reverse=True)
    emit({"items": items, "unread": sum(1 for i in items if i["state"] == "unread"),
          "read": sum(1 for i in items if i["state"] == "read"),
          "hidden": sum(1 for i in items if i["state"] == "hidden")})


def cmd_news_mark(op, ids):
    by_repo = {}
    for i in ids:
        repo, _, name = i.partition("/")
        by_repo.setdefault(repo, []).append(name)
    if op in ("allread", "purgeall"):
        by_repo = {r: [] for r in news_dirs()}
    for repo, names in by_repo.items():
        unread = news_list_file(repo, "unread")
        rd = news_list_file(repo, "read")
        if op == "read":
            unread = [n for n in unread if n not in names]
            rd += [n for n in names if n not in rd]
        elif op == "unread":
            rd = [n for n in rd if n not in names]
            unread += [n for n in names if n not in unread]
        elif op == "purge":
            rd = [n for n in rd if n not in names]
        elif op == "allread":
            rd += [n for n in unread if n not in rd]
            unread = []
        elif op == "purgeall":
            rd = []
        news_write(repo, "unread", unread)
        news_write(repo, "read", rd)
    emit({"ok": True})


# ---------------------------------------------------------------- build

def oldest_emerge_start():
    """Start epoch of the longest running real (non-pretend) emerge, 0 when none runs."""
    best = 0
    for line in run(["pgrep", "-x", "emerge", "-a"]).splitlines():
        if not line.strip() or "-pvuDN @world" in line or "--pretend" in line or " -p " in line:
            continue
        pid = line.split()[0]
        et = run(["ps", "-o", "etimes=", "-p", pid]).strip()
        if et.isdigit():
            best = max(best, int(et))
    return int(time.time()) - best if best else 0


def emerge_session(log_path):
    """The build in progress: [{i, n, atom, start, end}] and the start of its first package.

    emerge.log carries no pid, and a second emerge (an --unmerge, a sync, one waiting at --ask) writes its own
    "Started emerge on" ... "*** terminating." into the same file while the build runs, so sessions cannot be
    told apart by those markers. The chain of "(i of n)" lines is followed instead: the last package that
    started, then backwards through the lines with the same n and i-1, i-2, ... A chain that started before
    the oldest running emerge belongs to a build that ended (or failed) earlier: it is dropped."""
    try:
        size = os.path.getsize(log_path)
        with open(log_path, "rb") as f:
            f.seek(max(0, size - 3_000_000))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return [], 0
    starts, done = [], {}
    for line in lines:
        m = re.match(r"(\d+):  >>> emerge \((\d+) of (\d+)\) (\S+) to ", line)
        if m:
            starts.append({"i": int(m.group(2)), "n": int(m.group(3)), "atom": m.group(4), "start": int(m.group(1)), "end": 0})
            continue
        m = re.match(r"(\d+):  ::: completed emerge \((\d+) of (\d+)\) (\S+) to ", line)
        if m:
            done[(int(m.group(2)), int(m.group(3)), m.group(4))] = int(m.group(1))
    if not starts:
        return [], 0
    oldest = oldest_emerge_start()
    best = []
    # One chain per total n (concurrent emerges have different totals): from the last package that started
    # with that n back through i-1, i-2, ...; chains whose last package completed with i == n are finished.
    for n in sorted(set(ev["n"] for ev in starts)):
        last = [ev for ev in starts if ev["n"] == n][-1]
        chain, expect = [], last["i"]
        for ev in reversed(starts):
            if ev["n"] == n and ev["i"] == expect:
                ev["end"] = done.get((ev["i"], ev["n"], ev["atom"]), 0)
                chain.append(ev)
                expect -= 1
                if expect == 0:
                    break
        chain.reverse()
        if not chain or (chain[-1]["i"] == n and chain[-1]["end"]):
            continue
        if oldest and chain[-1]["start"] < oldest - 5:
            continue
        if not best or chain[-1]["start"] > best[-1]["start"]:
            best = chain
    return best, best[0]["start"] if best else 0


def pkg_name(atom):
    return re.sub(r"-\d.*$", "", atom)


def cmd_build():
    env = envvars()
    logdir = env.get("PORT_LOGDIR", "")
    running = emerge_running()
    session, sess_start = emerge_session(logdir + "/emerge.log") if logdir else ([], 0)
    now = int(time.time())

    # history from qlop: epoch >>> atom +seconds
    hist = []
    for line in run(["qlop", "-m", "-t", "-M", "-C", "-v"]).splitlines()[-400:]:
        m = re.match(r"(\d+) >>> (\S+): (\d+)$", line)
        if m:
            hist.append({"endEpoch": int(m.group(1)), "atom": m.group(2), "seconds": int(m.group(3))})
    recent = hist[-12:][::-1]
    midnight = int(time.mktime(time.localtime(now)[:3] + (0, 0, 0, 0, 0, -1)))
    today = [h for h in hist if h["endEpoch"] >= midnight]
    today_since = min((h["endEpoch"] - h["seconds"] for h in today), default=0)

    cur = None
    logtail, logpath = [], ""
    if running and session:
        cur = session[-1] if not session[-1]["end"] else None
        # the log of the package being built (a second emerge in another terminal has its own build.log)
        own = env.get("PORTAGE_TMPDIR", "/var/tmp") + "/portage/" + cur["atom"] + "/temp/build.log" if cur else ""
        # a build dir that exists but is not readable (portage-only permissions) means: no log to show,
        # not "show the log of some other build"
        if cur and os.path.isdir(os.path.dirname(os.path.dirname(own))):
            cands = [own] if os.access(own, os.R_OK) else []
        else:
            cands = glob.glob(env.get("PORTAGE_TMPDIR", "/var/tmp") + "/portage/*/*/temp/build.log")
        if not cands and logdir and not (cur and os.path.isdir(os.path.dirname(os.path.dirname(own)))):
            cands = glob.glob(logdir + "/build/*/*.log")
        cands.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        if cands and (cands[0] == own or now - os.path.getmtime(cands[0]) < 600):
            logpath = cands[0]
            try:
                size = os.path.getsize(logpath)
                with open(logpath, "rb") as f:
                    f.seek(max(0, size - 6000))
                    logtail = [ANSI.sub("", l)[:200] for l in f.read().decode("utf-8", "replace").splitlines()[-24:]]
            except OSError:
                pass
    avg = {}
    if cur:
        out = run(["qlop", "-a", "-m", "-M", "-C", pkg_name(cur["atom"])])
        m = re.search(r": (\d+) average for (\d+) merge", out)
        if m:
            avg = {"seconds": int(m.group(1)), "count": int(m.group(2))}
    jobs = ""
    try:
        for line in read("/etc/portage/make.conf").splitlines():
            m = re.match(r"\s*MAKEOPTS=[\"']?(.*?)[\"']?\s*$", line)
            if m:
                jobs = m.group(1)
    except Exception:
        pass
    emerge_jobs = len([l for l in run(["pgrep", "-x", "emerge", "-a"]).splitlines() if "-pvuDN" not in l])
    emit({"running": running, "sessionStart": sess_start, "session": session, "current": cur,
          "logPath": logpath, "logTail": logtail, "average": avg, "makeopts": jobs,
          "emergeProcs": emerge_jobs, "load": os.getloadavg()[0],
          "recent": recent, "todayCount": len(today), "todaySince": today_since, "now": now})


def cmd_build_log(atom):
    if not re.match(r"^[\w+.-]+/[\w+.-]+$", atom):
        emit({"text": ""})
        return
    logdir = envvars().get("PORT_LOGDIR", "")
    files = sorted(glob.glob("%s/build/%s:*.log" % (logdir, glob.escape(atom))), key=os.path.getmtime)
    if not files:
        emit({"text": "No build log found for %s in %s/build (PORT_LOGDIR)." % (atom, logdir)})
        return
    lines = ANSI.sub("", read(files[-1])).splitlines()
    cut = max(0, len(lines) - 3000)
    head = "(%d earlier lines not shown, open the file with o)\n" % cut if cut else ""
    emit({"text": head + "\n".join(lines[cut:]), "path": files[-1]})


# ---------------------------------------------------------------- housekeeping

def parse_size(s):
    m = re.match(r"([\d.]+)\s*([KMGT]?)", s.strip())
    if not m:
        return 0
    mult = {"": 1, "K": 1024, "M": 1024 ** 2, "G": 1024 ** 3, "T": 1024 ** 4}[m.group(2)]
    return int(float(m.group(1)) * mult)


def ver_key(v):
    return [int(x) if x.isdigit() else 0 for x in re.split(r"[.\-_]", v)]


def housekeeping_collect():
    env = envvars()
    # config files waiting for dispatch-conf
    cfg = []
    prot = [p for p in env.get("CONFIG_PROTECT", "/etc").split() if os.path.isdir(p)] or ["/etc"]
    for p in prot:
        out = run(["find", p, "-name", "._cfg????_*", "-not", "-path", "*/proc/*"], timeout=30)
        cfg += [l for l in out.splitlines() if l]
    # depclean
    dep = {"world": 0, "system": 0, "required": 0, "remove": 0, "packages": []}
    out = run_all(["emerge", "-p", "--depclean"], timeout=180)
    for key, pat in (("world", r"Packages in world:\s+(\d+)"), ("system", r"Packages in system:\s+(\d+)"),
                     ("required", r"Required packages:\s+(\d+)"), ("remove", r"Number to remove:\s+(\d+)")):
        m = re.search(pat, out)
        if m:
            dep[key] = int(m.group(1))
    sect = out.split("All selected packages:")[1:] if "All selected packages:" in out else []
    if sect:
        dep["packages"] = [l.strip() for l in sect[0].split("\n\n")[0].splitlines() if l.strip()][:30]
    # distfiles / binpkgs / not in tree
    out = run_all(["eclean-dist", "-p"], timeout=120)
    dist = {"files": 0, "reclaimBytes": 0, "totalBytes": 0}
    m = re.search(r"\[\s*([\d.]+ ?[KMGT]?)\s*\] Total space from (\d+) files", out)
    if m:
        dist["reclaimBytes"], dist["files"] = parse_size(m.group(1)), int(m.group(2))
    dd = env.get("DISTDIR", "/var/cache/distfiles")
    du = run(["du", "-sb", dd], timeout=60).split()
    if du:
        dist["totalBytes"] = int(du[0])
    notree = []
    if "unavailable installed packages" in out:
        tail = out.split("unavailable installed packages")[1]
        notree = [l.strip() for l in tail.splitlines() if re.match(r"\s+\S+/\S+", l)]
    out = run_all(["eclean-pkg", "-p"], timeout=120)
    pk = {"clean": "already clean" in out or "no packages" in out.lower(), "reclaimBytes": 0, "files": 0}
    m = re.search(r"\[\s*([\d.]+ ?[KMGT]?)\s*\] Total space from (\d+) files", out)
    if m:
        pk = {"clean": False, "reclaimBytes": parse_size(m.group(1)), "files": int(m.group(2))}
    # kernels
    running = os.uname().release
    kernels = {}
    for f in glob.glob("/boot/kernel-*") + glob.glob("/boot/initramfs-*") + glob.glob("/boot/vmlinuz-*"):
        m = re.search(r"-(\d[\w.]*-gentoo[\w-]*)", f.split("/")[-1].replace(".img", ""))
        if m:
            kernels[m.group(1)] = kernels.get(m.group(1), 0) + os.path.getsize(f)
    for d in glob.glob("/lib/modules/*"):
        kernels.setdefault(d.split("/")[-1], 0)
    klist = sorted(kernels, key=ver_key, reverse=True)
    latest = klist[0] if klist else ""
    kern = {"running": running, "latest": latest,
            "list": [{"version": k, "bytes": kernels[k], "running": k == running} for k in klist],
            "reboot": bool(latest) and ver_key(latest) > ver_key(running)}
    # build problems: portage leaves the build dir behind when a build fails
    tmp = env.get("PORTAGE_TMPDIR", "/var/tmp") + "/portage"
    failed = []
    for d in sorted(glob.glob(tmp + "/*/*")):
        if os.path.isdir(d + "/temp"):
            lg = d + "/temp/build.log"
            tail = []
            if os.path.exists(lg):
                tail = [l[:180] for l in read(lg).splitlines()[-8:]]
            failed.append({"atom": "/".join(d.split("/")[-2:]), "log": lg, "tail": tail,
                           "epoch": int(os.path.getmtime(d))})
    emit_obj = {"cfgFiles": cfg[:50], "cfgCount": len(cfg), "depclean": dep, "distfiles": dist, "binpkgs": pk,
                "notInTree": notree, "kernels": kern, "failed": failed, "tmpdir": tmp,
                "distdir": dd, "logdir": env.get("PORT_LOGDIR", "")}
    return emit_obj


def cmd_housekeeping(refresh):
    emit(cached("housekeeping", 1800, refresh, housekeeping_collect))


# ---------------------------------------------------------------- statistics

def stats_collect():
    inst = installed_pkgs()
    by_repo, cats, eapi_i = {}, {}, {}
    for cat, _pf, repo, eapi in inst:
        by_repo[repo or "?"] = by_repo.get(repo or "?", 0) + 1
        cats[cat] = cats.get(cat, 0) + 1
        eapi_i["EAPI " + (eapi or "?")] = eapi_i.get("EAPI " + (eapi or "?"), 0) + 1
    tree = {}
    eapi_t = {}
    cats_t = {}
    rl = repos()
    for r in rl:
        tree[r["name"]] = count_ebuilds(r["location"])
        if r["name"] == "gentoo":
            for c in glob.glob(r["location"] + "/*-*/*") + glob.glob(r["location"] + "/virtual/*"):
                if os.path.isdir(c):
                    cat = c.split("/")[-2]
                    cats_t[cat] = cats_t.get(cat, 0) + 1
            out = run(["grep", "-rhoE", "-m1", "--include=*.ebuild", r"^EAPI=[\"']?[0-9]+", r["location"]], timeout=120)
            for line in out.splitlines():
                m = re.search(r"(\d+)$", line)
                if m:
                    eapi_t["EAPI " + m.group(1)] = eapi_t.get("EAPI " + m.group(1), 0) + 1
    slow = []
    for line in run(["qlop", "-a", "-m", "-M", "-C"]).splitlines():
        m = re.match(r"(\S+/\S+): (\d+) average for (\d+) merge", line)
        if m:
            slow.append({"atom": m.group(1), "seconds": int(m.group(2)), "count": int(m.group(3))})
    slow.sort(key=lambda s: -s["seconds"])
    srt = lambda d: sorted(d.items(), key=lambda kv: -kv[1])
    return {"installed": len(inst), "installedByRepo": srt(by_repo), "treeByRepo": srt(tree),
            "treeTotal": sum(tree.values()), "eapiInstalled": srt(eapi_i), "eapiTree": srt(eapi_t),
            "categories": srt(cats)[:8], "categoriesTree": srt(cats_t)[:8], "slowest": slow[:6]}


def cmd_stats(refresh):
    emit(cached("stats", 6 * 3600, refresh, stats_collect))


# ---------------------------------------------------------------- GLSA

def glsa_collect():
    ids = [l.strip() for l in run(["glsa-check", "-t", "all"], timeout=120).splitlines()
           if re.match(r"\d{6}-\d{2}$", l.strip())]
    affected = []
    for gid in ids:
        text = run(["glsa-check", "-d", gid], timeout=60)
        lines = text.splitlines()
        title = ""
        for i, l in enumerate(lines[:4]):
            if l.startswith("GLSA") and i + 1 < len(lines):
                title = lines[i + 1].strip()
        pk = re.findall(r"Affected package:\s+(\S+)", text)
        vuln = re.findall(r"Vulnerable:\s+(.+)", text)
        fixed = re.findall(r"Unaffected:\s+(.+)", text)
        affected.append({"id": gid, "title": title, "packages": pk,
                         "vulnerable": vuln[0].strip() if vuln else "", "fixed": fixed[0].strip() if fixed else ""})
    return {"affected": affected}


def cmd_glsa(refresh):
    emit(cached("glsa", 6 * 3600, refresh, glsa_collect))


def cmd_glsa_text(gid):
    if not re.match(r"^\d{6}-\d{2}$", gid):
        emit({"text": ""})
        return
    emit({"text": run(["glsa-check", "-d", gid], timeout=60)})


# ---------------------------------------------------------------- live ebuilds, flatpak

LIVE = re.compile(r"^(\d+\.)*9{4,}(-r\d+)?$")


def live_upstream():
    """smart-live-rebuild in pretend mode (read only, git ls-remote): { "cat/pn": {...} } plus tool availability."""
    if not run(["sh", "-c", "command -v smart-live-rebuild"]).strip():
        return {"available": False, "pkgs": {}}
    out = run_all(["smart-live-rebuild", "--pretend", "--no-color", "--no-setuid", "--unprivileged-user", "--jobs=6"], timeout=240)
    pkgs, cur = {}, None
    for line in out.splitlines():
        m = re.match(r"^->  \[(\S+?)(?::(\S*))?\] (\S+) \[(.*)\]\s*$", line)
        if m:
            cur = {"url": m.group(3), "ref": m.group(4), "state": "unknown", "installed": "", "upstream": ""}
            pkgs[m.group(1)] = cur
            continue
        if cur is None:
            continue
        m = re.match(r"^--> update from (\w+) to (\w+)", line)
        if m:
            cur.update(state="changed", installed=m.group(1)[:8], upstream=m.group(2)[:8])
            cur = None
            continue
        m = re.match(r"^--> at rev (\w+) \(no changes\)", line)
        if m:
            cur.update(state="current", installed=m.group(1)[:8], upstream=m.group(1)[:8])
            cur = None
            continue
        if line.startswith("--> ") or line.startswith("!!!"):
            cur.update(state="error")
            cur = None
    return {"available": True, "pkgs": pkgs}


def cmd_live(refresh):
    items = []
    for d in glob.glob("/var/db/pkg/*/*"):
        cat, pf = d.split("/")[-2:]
        m = re.match(r"^(.*?)-(\d[^-]*(?:-r\d+)?)$", pf)
        if not m or not LIVE.match(m.group(2)):
            continue
        try:
            built = int(read(d + "/BUILD_TIME").strip() or 0)
        except ValueError:
            built = 0
        items.append({"cat": cat, "name": m.group(1), "version": m.group(2), "repo": read(d + "/repository").strip(),
                      "builtEpoch": built})
    items.sort(key=lambda i: i["builtEpoch"])
    # A live package rebuilt after the last check (smart-live-rebuild, emerge @live-rebuild) makes the cached
    # installed hashes stale: check again instead of waiting for the 30 minute cache to expire.
    try:
        stale = bool(items) and max(i["builtEpoch"] for i in items) > os.path.getmtime(os.path.join(CACHE, "live-upstream.json"))
    except OSError:
        stale = False
    up = cached("live-upstream", 1800, refresh or stale, live_upstream) if items else {"available": True, "pkgs": {}}
    for i in items:
        u = up.get("pkgs", {}).get(i["cat"] + "/" + i["name"], {})
        i.update(state=u.get("state", "unknown"), installed=u.get("installed", ""), upstream=u.get("upstream", ""),
                 url=u.get("url", ""), ref=u.get("ref", ""))
    emit({"items": items, "toolAvailable": up.get("available", False), "checkedEpoch": up.get("checkedEpoch", 0),
          "changed": sum(1 for i in items if i["state"] == "changed")})


def flatpak_collect():
    if not run(["sh", "-c", "command -v flatpak"]).strip():
        return {"available": False, "installed": 0, "updates": []}
    inst = [l for l in run(["flatpak", "list", "--app", "--columns=application"]).splitlines() if l.strip()]
    ups = []
    for line in run(["flatpak", "remote-ls", "--updates", "--columns=application,name,version,installed-size,origin"],
                    timeout=90).splitlines():
        c = line.split("\t")
        if len(c) >= 5 and c[0].strip():
            ups.append({"app": c[0], "name": c[1], "version": c[2], "size": c[3], "origin": c[4],
                        "runtime": c[0] not in inst})
    return {"available": True, "installed": len(inst), "updates": ups}


def cmd_flatpak(refresh):
    # `flatpak update` / install touches these files: the cached list is stale after that
    stale = False
    try:
        cache_t = os.path.getmtime(os.path.join(CACHE, "flatpak.json"))
        for f in ("/var/lib/flatpak/.changed", HOME + "/.local/share/flatpak/.changed"):
            if os.path.exists(f) and os.path.getmtime(f) > cache_t:
                stale = True
    except OSError:
        pass
    emit(cached("flatpak", 1800, refresh or stale, flatpak_collect))


def main():
    argv = sys.argv[1:]
    if len(argv) >= 3 and argv[0] == "--fixture":
        path = os.path.join(argv[1], argv[2] + ".json")
        sys.stdout.write(read(path, "{}") if os.path.exists(path) else "{}")
        return
    if not argv:
        print(__doc__)
        return
    cmd, rest = argv[0], argv[1:]
    refresh = "--refresh" in rest
    rest = [a for a in rest if a != "--refresh"]
    if cmd == "sync":
        cmd_sync()
    elif cmd == "news":
        cmd_news()
    elif cmd == "news-mark" and rest:
        cmd_news_mark(rest[0], rest[1:])
    elif cmd == "build":
        cmd_build()
    elif cmd == "build-log" and rest:
        cmd_build_log(rest[0])
    elif cmd == "housekeeping":
        cmd_housekeeping(refresh)
    elif cmd == "stats":
        cmd_stats(refresh)
    elif cmd == "glsa":
        cmd_glsa(refresh)
    elif cmd == "glsa-text" and rest:
        cmd_glsa_text(rest[0])
    elif cmd == "pause":
        cmd_pause(rest[0] if rest else "toggle")
    elif cmd == "live":
        cmd_live(refresh)
    elif cmd == "flatpak":
        cmd_flatpak(refresh)
    elif cmd == "sync-now":
        cmd_sync_now()
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
