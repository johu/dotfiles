.pragma library

// "27.9 M" / "961 k" / "812"
function tok(n) {
    if (n >= 1e6)
        return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + " M";
    if (n >= 1e3)
        return Math.round(n / 1e3) + " k";
    return String(Math.round(n));
}

function cost(n) {
    return "$" + (n >= 100 ? Math.round(n) : n.toFixed(2));
}

// seconds ago -> "now" | "12 min" | "3 h" | "2 d"
function ago(sec) {
    if (sec < 45)
        return "now";
    if (sec < 3600)
        return Math.max(1, Math.round(sec / 60)) + " min";
    if (sec < 86400)
        return Math.round(sec / 3600) + " h";
    return Math.round(sec / 86400) + " d";
}

// ISO time of a limit reset -> "in 2 h 14 min" (same day) | "Fri 08:00"
function resetsIn(iso) {
    if (!iso)
        return "";
    const t = new Date(iso);
    if (isNaN(t.getTime()))
        return "";
    const ms = Math.max(0, t.getTime() - Date.now());
    const min = Math.round(ms / 60000);
    if (min < 60)
        return "in " + min + " min";
    if (min < 24 * 60)
        return "in " + Math.floor(min / 60) + " h " + (min % 60) + " min";
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const pad = v => (v < 10 ? "0" : "") + v;
    return days[t.getDay()] + " " + pad(t.getHours()) + ":" + pad(t.getMinutes());
}

// short day label of "YYYY-MM-DD" -> "Nov 8"
function dayLabel(iso) {
    const m = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const p = iso.split("-");
    return m[parseInt(p[1]) - 1] + " " + parseInt(p[2]);
}
