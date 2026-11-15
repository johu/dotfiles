#!/usr/bin/env python3
"""Fetch synced lyrics from LRCLIB for the launcher's media view.

usage: lyrics.py ARTIST TITLE ALBUM DURATION_SECONDS [--refresh]

Prints one JSON object on stdout:
  {"status": "ok", "synced": true,  "lines": [{"t": 37.66, "s": "..."}], "source": "cache|lrclib"}
  {"status": "ok", "synced": false, "lines": [{"s": "..."}], ...}
  {"status": "instrumental"} | {"status": "none"} | {"status": "error", "message": "..."}

Results are cached in ~/.cache/quickshell/lyrics/ ("none" for 3 days, errors
never), so reopening the view never hits the network for a known track.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
UA = "quickshell-launcher-lyrics"
CACHE = os.path.expanduser("~/.cache/quickshell/lyrics")
NONE_TTL = 3 * 24 * 3600
STAMP = re.compile(r"\[(\d+):(\d+(?:[.:]\d+)?)\]")


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.flush()


def http(path, params):
    url = API + path + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read().decode("utf-8"))


def parse(entry):
    """LRCLIB record -> result dict (synced preferred), or None."""
    if entry.get("instrumental"):
        return {"status": "instrumental"}
    synced = entry.get("syncedLyrics") or ""
    lines = []
    for raw in synced.splitlines():
        stamps = list(STAMP.finditer(raw))
        if not stamps:
            continue
        text = raw[stamps[-1].end():].strip()
        for m in stamps:
            sec = m.group(2).replace(":", ".")
            lines.append({"t": round(int(m.group(1)) * 60 + float(sec), 2), "s": text})
    if lines:
        lines.sort(key=lambda x: x["t"])
        return {"status": "ok", "synced": True, "lines": lines}
    plain = entry.get("plainLyrics") or ""
    rows = [{"s": ln.rstrip()} for ln in plain.splitlines()]
    if any(r["s"] for r in rows):
        return {"status": "ok", "synced": False, "lines": rows}
    return None


def first_artist(artist):
    return re.split(r"\s*(?:,|&|;| feat\.? | ft\.? | x )\s*", artist, maxsplit=1)[0]


def lookup(artist, title, album, duration):
    tries = [dict(artist_name=artist, track_name=title, album_name=album, duration=duration)]
    lead = first_artist(artist)
    if lead and lead != artist:
        tries.append(dict(artist_name=lead, track_name=title, album_name=album, duration=duration))
    for params in tries:
        # LRCLIB wants all four fields; leave out the ones the player did not report.
        params = {k: v for k, v in params.items() if v}
        try:
            res = parse(http("/get", params))
            if res:
                return res
        except urllib.error.HTTPError as e:
            if e.code != 404:
                raise
    # Fuzzy fallback: search, prefer synced results with the closest duration.
    hits = http("/search", {"track_name": title, "artist_name": lead or artist})
    if not hits:
        hits = http("/search", {"q": f"{artist} {title}"})
    ranked = sorted(
        (h for h in hits if duration <= 0 or abs((h.get("duration") or 0) - duration) <= 5),
        key=lambda h: (not h.get("syncedLyrics"), abs((h.get("duration") or 0) - duration)),
    )
    for h in ranked:
        res = parse(h)
        if res:
            return res
    return {"status": "none"}


def main():
    args = [a for a in sys.argv[1:] if a != "--refresh"]
    refresh = "--refresh" in sys.argv
    if len(args) < 4:
        out({"status": "error", "message": "usage: lyrics.py ARTIST TITLE ALBUM DURATION"})
        return
    artist, title, album = args[0].strip(), args[1].strip(), args[2].strip()
    try:
        duration = int(round(float(args[3])))
    except ValueError:
        duration = 0
    key = hashlib.sha1(f"{artist}|{title}|{album}|{duration}".lower().encode()).hexdigest()
    path = os.path.join(CACHE, key + ".json")
    if not refresh and os.path.exists(path):
        try:
            cached = json.load(open(path))
            if cached.get("status") != "none" or time.time() - os.path.getmtime(path) < NONE_TTL:
                cached["source"] = "cache"
                out(cached)
                return
        except (OSError, ValueError):
            pass
    try:
        res = lookup(artist, title, album, duration)
    except (urllib.error.URLError, OSError, ValueError, TimeoutError) as e:
        out({"status": "error", "message": str(e)[:120]})
        return
    try:
        os.makedirs(CACHE, exist_ok=True)
        json.dump(res, open(path, "w"), ensure_ascii=False)
    except OSError:
        pass
    res["source"] = "lrclib"
    out(res)


main()
