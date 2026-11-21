#!/usr/bin/env python3
"""Token usage of the AI coding tools, for the launcher's "AI usage" view.

Prints ONE JSON document on stdout:
  {"generatedAt": <epoch s>, "tabs": [<tab>, ...]}
A tab is what the view shows on one provider page:
  {"id", "label", "limits": bool, "today": {...}, "week": {...}, "days": [14 x {"d","tokens","req","cost"}],
   "models": [{"name","tokens","req","cost"}], "projects": [...], "cacheHit": 0..1, "live": [...]}
(tokens = input + output + cache writes; cache reads are only used for the hit rate.)

The transcripts are big (hundreds of MB), so every run only reads what was appended since the last run;
the parsed requests are cached in ~/.local/state/quickshell/aiusage-cache.json. A request seen twice
(streaming writes it more than once) is stored once, the last copy wins.

ADDING A PROVIDER: write a class with `files()`, `parse(path, offset, state)` and `live()` (copy
ClaudeSource, it is ~50 lines) and append an instance to SOURCES. Every record carries its own tab id,
so one source may feed several tabs (PiSource: one tab per pi provider, except claude-bridge, whose
requests are already in the Claude Code transcripts).
"""
import glob
import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone

HOME = os.environ.get("AIUSAGE_HOME") or os.path.expanduser("~")   # AIUSAGE_HOME: test hook, a scratch shell has another $HOME
CACHE = os.environ.get("AIUSAGE_CACHE") or os.path.join(os.environ.get("XDG_STATE_HOME", HOME + "/.local/state"), "quickshell", "aiusage-cache.json")
KEEP_DAYS = int(os.environ.get("AIUSAGE_KEEP_DAYS") or 35)      # records older than this are dropped from the cache (the env vars are for tests)
SHOW_DAYS = 14      # days of the chart
RANK_DAYS = 30      # window of the model / project rankings
VERSION = 2

TAB_LABELS = {"claude": "Claude", "openai-codex": "Codex (pi)", "anthropic": "Anthropic API (pi)"}


def now():
    """AIUSAGE_SHIFT_DAYS moves "today" into the past, to look at old data (tests)."""
    return datetime.now() - timedelta(days=int(os.environ.get("AIUSAGE_SHIFT_DAYS") or 0))


def local_day(ts):
    """ISO string or epoch (s / ms) -> local YYYY-MM-DD."""
    try:
        if isinstance(ts, (int, float)):
            ts = ts / 1000.0 if ts > 1e11 else ts
            return datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d")
    except Exception:
        return None


def project_of(cwd):
    if not cwd:
        return "?"
    if os.path.normpath(cwd) == HOME:
        return "~"
    return os.path.basename(os.path.normpath(cwd)) or "/"


def read_new(path, offset):
    """Complete new lines of `path` after byte `offset` -> (lines, new offset)."""
    try:
        size = os.path.getsize(path)
    except OSError:
        return [], offset
    if size < offset:
        offset = 0
    if size == offset:
        return [], offset
    with open(path, "rb") as fh:
        fh.seek(offset)
        data = fh.read()
    end = data.rfind(b"\n")
    if end < 0:
        return [], offset
    return data[: end + 1].decode("utf-8", "replace").splitlines(), offset + end + 1


def pid_alive(pid, start=None):
    try:
        with open("/proc/%d/stat" % pid) as fh:
            stat = fh.read()
    except OSError:
        return False
    if start is None:
        return True
    return stat.rsplit(")", 1)[1].split()[19] == str(start)


class ClaudeSource:
    """Claude Code transcripts (also the ones written by the Agent SDK, i.e. pi's claude-bridge)."""

    def roots(self):
        env = os.environ.get("CLAUDE_CONFIG_DIR")
        return [env] if env else [HOME + "/.config/claude", HOME + "/.claude"]

    def files(self):
        out = []
        for r in self.roots():
            out += glob.glob(r + "/projects/*/*.jsonl") + glob.glob(r + "/projects/*/*/subagents/*.jsonl")
        return out

    def parse(self, path, offset, state):
        lines, new = read_new(path, offset)
        recs = []
        for line in lines:
            if '"type":"assistant"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            msg = d.get("message") or {}
            u = msg.get("usage")
            day = local_day(d.get("timestamp"))
            if not u or not day or msg.get("model") in (None, "<synthetic>"):
                continue
            key = "c:" + str(d.get("requestId") or msg.get("id") or d.get("uuid"))
            recs.append((key, ["claude", day, msg["model"].replace("[1m]", ""), project_of(d.get("cwd")), d.get("sessionId") or "",
                               u.get("input_tokens") or 0, u.get("output_tokens") or 0,
                               u.get("cache_read_input_tokens") or 0, u.get("cache_creation_input_tokens") or 0, 0.0]))
        return recs, new

    def live(self):
        out = []
        for r in self.roots():
            for f in glob.glob(r + "/sessions/*.json"):
                try:
                    s = json.load(open(f))
                    pid = int(s["pid"])
                except (ValueError, KeyError, OSError):
                    continue
                if not pid_alive(pid, s.get("procStart")):
                    continue
                out.append({"tab": "claude", "name": project_of(s.get("cwd")), "title": s.get("name") or "",
                            "session": s.get("sessionId") or "", "status": "working" if s.get("status") == "busy" else "idle",
                            "since": (s.get("statusUpdatedAt") or s.get("updatedAt") or 0) / 1000.0,
                            "via": "pi" if s.get("entrypoint") == "sdk-ts" else "terminal"})
        return out


class PiSource:
    """pi session files. One tab per pi provider; claude-bridge is skipped (see the module doc)."""

    SKIP = ("claude-bridge",)

    def __init__(self):
        self.root = HOME + "/.local/share/pi/agent/sessions"

    def files(self):
        return glob.glob(self.root + "/*/*.jsonl")

    def parse(self, path, offset, state):
        lines, new = read_new(path, offset)
        recs = []
        for line in lines:
            if '"type":"session"' in line and "cwd" in line and offset == 0:
                try:
                    state["cwd"] = json.loads(line).get("cwd") or ""
                except ValueError:
                    pass
                continue
            if '"usage"' not in line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            msg = d.get("message") or {}
            u = msg.get("usage")
            prov = msg.get("provider")
            if d.get("type") != "message" or msg.get("role") != "assistant" or not u or not prov or prov in self.SKIP:
                continue
            day = local_day(d.get("timestamp") or msg.get("timestamp"))
            if not day or not (u.get("totalTokens") or u.get("input") or u.get("output")):
                continue
            cost = (u.get("cost") or {}).get("total") or 0.0
            recs.append(("p:" + os.path.basename(path) + ":" + str(d.get("id")),
                         [prov, day, msg.get("model") or "?", project_of(state.get("cwd")), os.path.basename(path)[:-6],
                          u.get("input") or 0, u.get("output") or 0, u.get("cacheRead") or 0, u.get("cacheWrite") or 0, cost]))
        return recs, new

    def live(self):
        """Running `pi` processes -> their newest session file; only those whose last request went to a
        provider with its own tab (a claude-bridge session already shows up as a Claude Code process)."""
        out = []
        for p in os.listdir("/proc"):
            if not p.isdigit():
                continue
            try:
                with open("/proc/%s/cmdline" % p, "rb") as fh:
                    argv = fh.read().split(b"\0")
                if os.path.basename(argv[0].decode()) != "pi":
                    continue
                cwd = os.readlink("/proc/%s/cwd" % p)
            except (OSError, IndexError):
                continue
            folder = "--" + cwd.strip("/").replace("/", "-") + "--"
            files = sorted(glob.glob("%s/%s/*.jsonl" % (self.root, folder)), key=os.path.getmtime)
            if not files:
                continue
            prov = last_provider(files[-1])
            if not prov or prov in self.SKIP:
                continue
            age = time.time() - os.path.getmtime(files[-1])
            out.append({"tab": prov, "name": project_of(cwd), "title": "", "session": os.path.basename(files[-1])[:-6],
                        "status": "working" if age < 20 else "idle", "since": os.path.getmtime(files[-1]), "via": "pi"})
        return out


def last_provider(path):
    try:
        with open(path, "rb") as fh:
            fh.seek(max(0, os.path.getsize(path) - 60000))
            tail = fh.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return None
    for line in reversed(tail):
        if '"provider"' in line and '"usage"' in line:
            try:
                return json.loads(line)["message"]["provider"]
            except (ValueError, KeyError):
                continue
    return None


SOURCES = [ClaudeSource(), PiSource()]


def load_cache():
    try:
        with open(CACHE) as fh:
            c = json.load(fh)
        if c.get("version") == VERSION:
            return c
    except (OSError, ValueError):
        pass
    return {"version": VERSION, "files": {}, "recs": {}}


def save_cache(c):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp%d" % os.getpid()
    with open(tmp, "w") as fh:
        json.dump(c, fh, separators=(",", ":"))
    os.replace(tmp, CACHE)


def refresh(cache):
    cutoff = time.time() - (KEEP_DAYS + 1) * 86400
    seen = set()
    for src in SOURCES:
        for path in src.files():
            seen.add(path)
            try:
                st = os.stat(path)
            except OSError:
                continue
            fs = cache["files"].get(path)
            if fs is None:
                if st.st_mtime < cutoff:      # never needed: too old for any window
                    continue
                fs = cache["files"][path] = {"off": 0, "state": {}}
            if fs["off"] >= st.st_size and fs.get("mtime") == st.st_mtime:
                continue
            recs, fs["off"] = src.parse(path, fs["off"], fs["state"])
            fs["mtime"] = st.st_mtime
            for k, v in recs:
                cache["recs"][k] = v
    for path in list(cache["files"]):
        if path not in seen:
            del cache["files"][path]
    oldest = (now() - timedelta(days=KEEP_DAYS)).strftime("%Y-%m-%d")
    for k in [k for k, v in cache["recs"].items() if v[1] < oldest]:
        del cache["recs"][k]


def fmt_tab(tab_id, recs, live):
    now_ = now()
    today = now_.strftime("%Y-%m-%d")
    days = [(now_ - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(SHOW_DAYS - 1, -1, -1)]
    week_from = (now_ - timedelta(days=6)).strftime("%Y-%m-%d")
    rank_from = (now_ - timedelta(days=RANK_DAYS - 1)).strftime("%Y-%m-%d")
    per_day = {d: {"d": d, "tokens": 0, "req": 0, "cost": 0.0} for d in days}
    models, projects = {}, {}
    today_sum = {"tokens": 0, "req": 0, "cost": 0.0}
    week_sum = {"tokens": 0, "req": 0, "cost": 0.0}
    cr = fresh = 0
    for day, model, proj, _sess, tin, tout, tcr, tcw, cost in recs:
        tok = tin + tout + tcw
        if day in per_day:
            e = per_day[day]
            e["tokens"] += tok
            e["req"] += 1
            e["cost"] += cost
        if day == today:
            for k, v in (("tokens", tok), ("req", 1), ("cost", cost)):
                today_sum[k] += v
        if day >= week_from:
            for k, v in (("tokens", tok), ("req", 1), ("cost", cost)):
                week_sum[k] += v
            cr += tcr
            fresh += tin + tcw
        if day >= rank_from:
            for table, name in ((models, model), (projects, proj)):
                e = table.setdefault(name, {"name": name, "tokens": 0, "req": 0, "cost": 0.0})
                e["tokens"] += tok
                e["req"] += 1
                e["cost"] += cost
    rank = lambda t: sorted(t.values(), key=lambda e: -e["tokens"])
    return {"id": tab_id, "label": TAB_LABELS.get(tab_id, tab_id.replace("-", " ").title() + " (pi)"),
            "limits": tab_id == "claude", "today": today_sum, "week": week_sum, "days": [per_day[d] for d in days],
            "models": rank(models), "projects": rank(projects), "cacheHit": (cr / (cr + fresh)) if cr + fresh else -1,
            "live": live}


def main():
    cache = load_cache()
    refresh(cache)
    save_cache(cache)
    by_tab = {}
    for v in cache["recs"].values():
        by_tab.setdefault(v[0], []).append(v[1:])
    live = {}
    for src in SOURCES:
        for s in src.live():
            live.setdefault(s["tab"], []).append(s)
    # context size of a live session = what its last request had to read (insertion order = parse order)
    ctx = {}
    for v in cache["recs"].values():
        ctx[v[4]] = v[5] + v[7] + v[8]
    for lst in live.values():
        for s in lst:
            s["ctx"] = ctx.get(s["session"], 0)
    tabs = []
    for tab_id in sorted(set(by_tab) | set(live), key=lambda t: (t != "claude", t)):
        recs = by_tab.get(tab_id, [])
        if not recs and tab_id not in live:
            continue
        tabs.append(fmt_tab(tab_id, recs, live.get(tab_id, [])))
    print(json.dumps({"generatedAt": time.time(), "tabs": tabs}))


if __name__ == "__main__":
    main()
