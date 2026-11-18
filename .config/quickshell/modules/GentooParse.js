.pragma library

// Parsers and formatters for the Gentoo launcher view.

// "dev-qt/qtmultimedia-6.11.3:6/6.11.3::gentoo" -> { cat, name, version, slot, repo }
function splitAtom(token) {
    let repo = "";
    const ri = token.indexOf("::");
    if (ri >= 0) {
        repo = token.slice(ri + 2);
        token = token.slice(0, ri);
    }
    let slot = "";
    const si = token.indexOf(":");
    if (si >= 0) {
        slot = token.slice(si + 1);
        token = token.slice(0, si);
    }
    const m = token.match(/^(.*?)-(\d[^-]*(?:-r\d+)?)$/);
    const full = m ? m[1] : token;
    const version = m ? m[2] : "";
    const ci = full.indexOf("/");
    return { cat: ci >= 0 ? full.slice(0, ci) : "", name: ci >= 0 ? full.slice(ci + 1) : full, version: version, slot: slot, repo: repo };
}

function whyText(flags, old) {
    const f = flags.replace(/\s/g, "");
    if (f.indexOf("B") >= 0)
        return "blocker";
    if (f.indexOf("N") >= 0)
        return f.indexOf("S") >= 0 ? "new slot" : "new package";
    if (f.indexOf("UD") >= 0)
        return "downgrade" + (old ? " from " + old : "");
    if (f.indexOf("U") >= 0)
        return "update" + (old ? " from " + old : "");
    if (f.indexOf("r") >= 0)
        return "rebuild (subslot change)";
    if (f.indexOf("R") >= 0)
        return "rebuild";
    return "";
}

// Parses the output of `emerge -pvuDN @world`.
function parsePretend(text) {
    const res = { pending: [], total: 0, rebuilds: 0, newVersions: 0, downloadText: "", resolveSeconds: 0, conflicts: [], conflictRaw: "", hasConflict: false, parsed: false };
    if (!text)
        return res;
    res.parsed = true;
    const lines = text.split("\n");
    let conflictStart = -1;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        let m = line.match(/^\[(ebuild|binary)\s+([A-Za-z ]*?)\s*\]\s+(\S+)(?:\s+\[([^\]]+)\])?/);
        if (m) {
            const a = splitAtom(m[3]);
            const use = line.match(/\s(USE=".*?")/);
            const flags = m[2];
            res.pending.push({
                key: m[3], cat: a.cat, name: a.name, version: a.version, slot: a.slot, repo: a.repo,
                flags: flags, old: m[4] || "", use: use ? use[1] : "", why: whyText(flags, m[4] || ""),
                rebuild: flags.indexOf("R") >= 0 && flags.indexOf("N") < 0 && flags.indexOf("U") < 0,
                isNew: flags.indexOf("N") >= 0, isUpdate: flags.indexOf("U") >= 0,
                subslot: flags.indexOf("r") >= 0
            });
            continue;
        }
        m = line.match(/^Total:\s*(\d+) packages?.*?Size of downloads:\s*(.+?)\s*$/);
        if (m) {
            res.total = parseInt(m[1], 10);
            res.downloadText = m[2];
            continue;
        }
        m = line.match(/^Dependency resolution took ([\d.]+) s/);
        if (m)
            res.resolveSeconds = parseFloat(m[1]);
        if (conflictStart < 0 && /skipped due to a dependency conflict/.test(line))
            conflictStart = i;
    }
    res.rebuilds = res.pending.filter(p => p.rebuild || p.subslot).length;
    res.newVersions = res.pending.filter(p => p.isUpdate || p.isNew).length;
    if (res.total === 0)
        res.total = res.pending.length;

    // Conflicts: either a "skipped" block after a successful list, or the "!!!" failure.
    let start = conflictStart;
    if (start < 0) {
        for (let i = 0; i < lines.length; i++) {
            if (/^!!!/.test(lines[i]) || /^The following .*(?:conflict|blocked|masked)/i.test(lines[i])) {
                start = i;
                break;
            }
        }
    }
    if (start >= 0) {
        res.hasConflict = true;
        const body = lines.slice(start);
        res.conflictRaw = body.join("\n").replace(/\n{3,}/g, "\n\n").trim();
        let cur = null;
        for (let i = 1; i < body.length; i++) {
            const l = body[i];
            if (/^\S+\/\S+$/.test(l.trim()) && l[0] !== " " && (body[i + 1] ?? "").trim() === "") {
                cur = { pkg: l.trim(), candidate: "", requiredBy: [], text: [] };
                res.conflicts.push(cur);
                continue;
            }
            if (!cur)
                continue;
            cur.text.push(l);
            const c = l.match(/^\s*\((\S+?), ebuild scheduled for merge\)/);
            if (c && !cur.candidate)
                cur.candidate = c[1];
            const r = l.match(/required by \((\S+?)(?:,| )/);
            if (r) {
                const a = splitAtom(r[1]);
                const nm = a.cat ? a.cat + "/" + a.name : r[1];
                if (cur.requiredBy.indexOf(a.name) < 0)
                    cur.requiredBy.push(a.name);
            }
        }
        res.conflicts = res.conflicts.filter(c => c.candidate !== "" || c.requiredBy.length > 0);
    }
    return res;
}

function ageText(epoch, nowMs) {
    if (!epoch)
        return "never";
    const s = Math.max(0, Math.floor(nowMs / 1000) - epoch);
    if (s < 60)
        return "just now";
    if (s < 3600)
        return Math.floor(s / 60) + " min ago";
    if (s < 86400)
        return Math.floor(s / 3600) + " h ago";
    const d = Math.floor(s / 86400);
    if (d < 60)
        return d + (d === 1 ? " day ago" : " days ago");
    return Math.floor(d / 30) + " months ago";
}

function twoDigits(n) {
    return (n < 10 ? "0" : "") + n;
}

function clock(epoch) {
    const d = new Date(epoch * 1000);
    return twoDigits(d.getHours()) + ":" + twoDigits(d.getMinutes());
}

// "today 12:57" / "yesterday 12:57" / "16 Nov 12:57"
function whenText(epoch, nowMs) {
    if (!epoch)
        return "never";
    const d = new Date(epoch * 1000);
    const now = new Date(nowMs);
    const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const dayMs = 86400000;
    const t = d.getTime();
    if (t >= midnight)
        return "today " + clock(epoch);
    if (t >= midnight - dayMs)
        return "yesterday " + clock(epoch);
    const mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()];
    return d.getDate() + " " + mon + " " + clock(epoch);
}

function durationText(sec) {
    sec = Math.max(0, Math.round(sec));
    if (sec < 60)
        return sec + " s";
    if (sec < 3600) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return m + " min" + (s >= 5 && sec < 600 ? " " + s + " s" : "");
    }
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    return h + " h" + (m > 0 ? " " + m + " min" : "");
}

// 4'12" style used by the build lists
function minSec(sec) {
    sec = Math.round(sec);
    if (sec < 60)
        return sec + "″";
    return Math.floor(sec / 60) + "′" + twoDigits(sec % 60) + "″";
}

function bytesText(b) {
    if (b >= 1024 * 1024 * 1024)
        return (b / 1024 / 1024 / 1024).toFixed(b >= 10 * 1024 * 1024 * 1024 ? 0 : 1) + " GB";
    if (b >= 1024 * 1024)
        return (b / 1024 / 1024).toFixed(b >= 100 * 1024 * 1024 ? 0 : 1) + " MB";
    if (b >= 1024)
        return Math.round(b / 1024) + " KB";
    return b + " B";
}

function countText(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

function kText(n) {
    return n >= 10000 ? (n / 1000).toFixed(1) + "k" : String(n);
}

// A heading in a news item: a short line between blank lines without a final period.
function newsLines(body) {
    const lines = (body || "").split("\n");
    const out = [];
    for (let i = 0; i < lines.length; i++) {
        const l = lines[i];
        const prevBlank = i === 0 || lines[i - 1].trim() === "";
        const nextBlank = i === lines.length - 1 || lines[i + 1].trim() === "";
        const heading = l.trim() !== "" && prevBlank && nextBlank && l.length < 60 && !/[.:;,]$/.test(l.trim()) && l.indexOf("  ") !== 0 && i > 0;
        out.push({ text: l, heading: heading });
    }
    return out;
}

// Kernels to remove. Keep: the two newest patch releases of the newest minor series (7.3.x),
// the newest kernel of each of the two minor series before it (7.2.x, 7.1.x) and the running
// one. With a 7.4.x installed, the 7.1.x kernel becomes a removal candidate.
function kernelRemovals(list, running) {
    const minor = v => v.split(".").slice(0, 2).join(".");
    const sorted = list.map(k => k.version);
    const minors = [];
    for (const v of sorted)
        if (minors.indexOf(minor(v)) < 0)
            minors.push(minor(v));
    const keep = {};
    for (const [i, m] of minors.slice(0, 3).entries()) {
        const ofMinor = sorted.filter(v => minor(v) === m);
        for (const v of ofMinor.slice(0, i === 0 ? 2 : 1))
            keep[v] = true;
    }
    return sorted.filter(v => !keep[v] && v !== running);
}

// 3434 s -> "57 min 14 s", 7938 -> "2 h 12 min"
function longDuration(sec) {
    sec = Math.round(sec);
    if (sec < 60)
        return sec + " s";
    if (sec < 3600)
        return Math.floor(sec / 60) + " min " + (sec % 60) + " s";
    return Math.floor(sec / 3600) + " h " + Math.floor((sec % 3600) / 60) + " min";
}

function pct(n, total) {
    return total > 0 ? (100 * n / total).toFixed(2) + "%" : "0.00%";
}
