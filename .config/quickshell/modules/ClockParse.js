.pragma library

// Pure helpers of the Clock view (no QML, testable with node): timer input parsing,
// alarm scheduling, text formatting. Weekdays are 1 (Monday) .. 7 (Sunday).

var DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// "5m", "90s", "1h30", "1h30m15s", "25" (minutes), "25/5" (Pomodoro), "25/5/3" (3 rounds);
// anything after the first space is the name. Returns { ok, ms, name, pomo } (pomo: null | { focus, brk, longBrk, rounds }).
function parseTimer(text) {
    const t = (text || "").trim();
    if (t === "")
        return { ok: false };
    const sp = t.search(/\s/);
    const head = sp < 0 ? t : t.slice(0, sp);
    const name = sp < 0 ? "" : t.slice(sp + 1).trim();
    let m = head.match(/^(\d+)\/(\d+)(?:\/(\d+))?$/);
    if (m) {
        const focus = parseInt(m[1]), brk = parseInt(m[2]), rounds = m[3] ? parseInt(m[3]) : 4;
        if (focus < 1 || brk < 1 || rounds < 1 || focus > 600 || brk > 600 || rounds > 20)
            return { ok: false };
        return { ok: true, ms: focus * 60000, name: name !== "" ? name : "Focus", pomo: { focus: focus, brk: brk, longBrk: 15, rounds: rounds } };
    }
    // three shapes: "25" (minutes), "1h30" (hours + bare minutes), "1h30m15s" / "90s" / "5m" (explicit units)
    let ms = -1;
    if (/^\d+$/.test(head)) {
        ms = parseInt(head) * 60000;
    } else if ((m = head.match(/^(\d+)h(\d{1,2})$/i))) {
        ms = (parseInt(m[1]) * 60 + parseInt(m[2])) * 60000;
    } else if ((m = head.match(/^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/i)) && (m[1] !== undefined || m[2] !== undefined || m[3] !== undefined)) {
        ms = (parseInt(m[1] || "0") * 3600 + parseInt(m[2] || "0") * 60 + parseInt(m[3] || "0")) * 1000;
    }
    if (ms < 0)
        return { ok: false };
    if (ms <= 0 || ms > 100 * 3600 * 1000)
        return { ok: false };
    return { ok: true, ms: ms, name: name, pomo: null };
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

// countdown text: 01:54, 1:12:05 (rounded up, so a running timer never shows 00:00 early)
function countdown(ms) {
    const total = Math.max(0, Math.ceil(ms / 1000));
    const h = Math.floor(total / 3600), m = Math.floor(total % 3600 / 60), s = total % 60;
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s);
}

// stopwatch text: 00:00.00 / 1:12:48.37 (hundredths)
function stopwatch(ms) {
    const total = Math.max(0, Math.floor(ms / 10));
    const cs = total % 100, s = Math.floor(total / 100) % 60, m = Math.floor(total / 6000) % 60, h = Math.floor(total / 360000);
    return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s) + "." + pad(cs);
}

// "1 h 12 min", "26 min", "45 s"
function durationText(ms) {
    const s = Math.round(ms / 1000);
    if (s < 60)
        return s + " s";
    const m = Math.round(s / 60);
    if (m < 60)
        return m + " min";
    const h = Math.floor(m / 60), r = m % 60;
    return h + " h" + (r > 0 ? " " + r + " min" : "");
}

// "11 h 18 min", "7 days", "2 min"
function inText(ms) {
    const m = Math.max(0, Math.round(ms / 60000));
    if (m < 1)
        return "less than a minute";
    if (m < 60)
        return m + " min";
    const h = Math.floor(m / 60);
    if (h < 48)
        return h + " h" + (m % 60 > 0 ? " " + (m % 60) + " min" : "");
    return Math.round(h / 24) + " days";
}

// Next time (ms) the alarm fires after fromMs, or -1 for none. a = { time: "07:00", days: [1..7] | [], date: "" | "2026-11-26" }.
// No days and no date = the next time that clock time comes round (then the alarm turns itself off).
function nextAlarm(a, fromMs) {
    const p = (a.time || "").split(":");
    const hh = parseInt(p[0]), mm = parseInt(p[1]);
    if (isNaN(hh) || isNaN(mm))
        return -1;
    const from = new Date(fromMs);
    if (!a.days || a.days.length === 0) {
        if (!a.date) {
            const d = new Date(from.getFullYear(), from.getMonth(), from.getDate(), hh, mm, 0, 0);
            if (d.getTime() <= fromMs)
                d.setDate(d.getDate() + 1);
            return d.getTime();
        }
        const q = a.date.split("-").map(Number);
        const d = new Date(q[0], q[1] - 1, q[2], hh, mm, 0, 0);
        return d.getTime() > fromMs ? d.getTime() : -1;
    }
    for (let i = 0; i < 8; i++) {
        const d = new Date(from.getFullYear(), from.getMonth(), from.getDate() + i, hh, mm, 0, 0);
        const wd = (d.getDay() + 6) % 7 + 1;
        if (a.days.indexOf(wd) >= 0 && d.getTime() > fromMs)
            return d.getTime();
    }
    return -1;
}

// "tomorrow 07:00", "Saturday 08:30", "in 7 days", "today 18:30"
function whenText(ms, nowMs) {
    if (ms < 0)
        return "";
    const d = new Date(ms), n = new Date(nowMs);
    const day0 = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
    const diff = Math.round((day0(d) - day0(n)) / 86400000);
    const clock = pad(d.getHours()) + ":" + pad(d.getMinutes());
    if (diff === 0)
        return "today " + clock;
    if (diff === 1)
        return "tomorrow " + clock;
    if (diff < 7)
        return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][d.getDay()] + " " + clock;
    return "in " + diff + " days";
}

function daysText(days) {
    if (!days || days.length === 0)
        return "";
    if (days.length === 7)
        return "every day";
    return days.map(d => DAY_NAMES[d - 1]).join(" ");
}

// "07:30", "7.30", "730", "7" -> "07:30" (or "" when invalid)
function parseClock(text) {
    const t = (text || "").trim();
    let m = t.match(/^(\d{1,2})[:.](\d{2})$/);
    if (!m)
        m = t.match(/^(\d{1,2})(\d{2})$/);
    if (!m && /^\d{1,2}$/.test(t))
        m = [t, t, "00"];
    if (!m)
        return "";
    const hh = parseInt(m[1]), mm = parseInt(m[2]);
    return hh > 23 || mm > 59 ? "" : pad(hh) + ":" + pad(mm);
}

// "mon tue fri", "weekdays", "weekend", "daily" / "" -> [1..7] days; null when unreadable. "" = once.
function parseDays(text) {
    const t = (text || "").trim().toLowerCase();
    if (t === "" || t === "once")
        return [];
    if (t === "daily" || t === "every day" || t === "all")
        return [1, 2, 3, 4, 5, 6, 7];
    if (t === "weekdays")
        return [1, 2, 3, 4, 5];
    if (t === "weekend")
        return [6, 7];
    const out = [];
    for (const w of t.split(/[\s,]+/)) {
        const i = DAY_NAMES.map(x => x.toLowerCase()).indexOf(w.slice(0, 3));
        if (i < 0)
            return null;
        if (out.indexOf(i + 1) < 0)
            out.push(i + 1);
    }
    return out.sort();
}

// ISO 8601 week number of a Date (local)
function isoWeek(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    const y0 = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d - y0) / 86400000 + 1) / 7);
}

// [longitude, latitude] of common zones, for the markers of the day / night map (a zone not listed has no marker)
var ZONE_POS = {
    "Europe/Berlin": [13.4, 52.5], "Europe/Lisbon": [-9.1, 38.7], "Europe/London": [-0.1, 51.5], "Europe/Paris": [2.4, 48.9],
    "Europe/Madrid": [-3.7, 40.4], "Europe/Rome": [12.5, 41.9], "Europe/Vienna": [16.4, 48.2], "Europe/Zurich": [8.5, 47.4],
    "Europe/Amsterdam": [4.9, 52.4], "Europe/Stockholm": [18.1, 59.3], "Europe/Warsaw": [21.0, 52.2], "Europe/Athens": [23.7, 38.0],
    "Europe/Istanbul": [29.0, 41.0], "Europe/Moscow": [37.6, 55.8], "Europe/Kyiv": [30.5, 50.5], "Atlantic/Reykjavik": [-21.9, 64.1],
    "Africa/Cairo": [31.2, 30.0], "Africa/Lagos": [3.4, 6.5], "Africa/Nairobi": [36.8, -1.3], "Africa/Johannesburg": [28.0, -26.2],
    "Asia/Dubai": [55.3, 25.2], "Asia/Kolkata": [77.2, 28.6], "Asia/Bangkok": [100.5, 13.8], "Asia/Singapore": [103.8, 1.4],
    "Asia/Shanghai": [121.5, 31.2], "Asia/Hong_Kong": [114.2, 22.3], "Asia/Seoul": [127.0, 37.6], "Asia/Tokyo": [139.7, 35.7],
    "Australia/Sydney": [151.2, -33.9], "Australia/Perth": [115.9, -32.0], "Pacific/Auckland": [174.8, -36.9], "Pacific/Honolulu": [-157.9, 21.3],
    "America/Anchorage": [-149.9, 61.2], "America/Los_Angeles": [-118.2, 34.1], "America/Denver": [-105.0, 39.7], "America/Chicago": [-87.6, 41.9],
    "America/New_York": [-74.0, 40.7], "America/Toronto": [-79.4, 43.7], "America/Mexico_City": [-99.1, 19.4], "America/Bogota": [-74.1, 4.7],
    "America/Lima": [-77.0, -12.0], "America/Sao_Paulo": [-46.6, -23.5], "America/Argentina/Buenos_Aires": [-58.4, -34.6], "America/Santiago": [-70.7, -33.4]
};

// true when the point (lon, lat in degrees) is lit by the sun at utcMs; lit levels: 2 = day, 1 = twilight, 0 = night
function sunLevel(utcMs, lon, lat) {
    const d = new Date(utcMs);
    const start = Date.UTC(d.getUTCFullYear(), 0, 0);
    const n = Math.floor((utcMs - start) / 86400000);
    const dec = -23.44 * Math.cos(2 * Math.PI / 365 * (n + 10)) * Math.PI / 180;
    const hrs = d.getUTCHours() + d.getUTCMinutes() / 60;
    const sublon = -(hrs - 12) * 15;
    const H = (lon - sublon) * Math.PI / 180, la = lat * Math.PI / 180;
    const el = Math.sin(la) * Math.sin(dec) + Math.cos(la) * Math.cos(dec) * Math.cos(H);
    return el > 0.15 ? 2 : (el > 0 ? 1 : 0);
}

// "UTC+1" / "UTC-5:30" from minutes
function utcText(offMin) {
    const a = Math.abs(offMin);
    return "UTC" + (offMin < 0 ? "-" : "+") + Math.floor(a / 60) + (a % 60 ? ":" + pad(a % 60) : "");
}

// "+8 h" / "-1 h" / "+5.5 h"
function offsetText(h) {
    return (h > 0 ? "+" : "") + (Math.round(h * 10) / 10) + " h";
}

// ---------------------------------------------------------------- sun (world page strip, sunrise / sunset text)
// Sun elevation in degrees at (lon, lat in degrees) and utcMs: NOAA's general solar position formulas, a minute or two accurate.
function sunElevation(utcMs, lon, lat) {
    const d = new Date(utcMs);
    const start = Date.UTC(d.getUTCFullYear(), 0, 1);
    const doy = Math.floor((utcMs - start) / 86400000);
    const utcH = d.getUTCHours() + d.getUTCMinutes() / 60 + d.getUTCSeconds() / 3600;
    const g = 2 * Math.PI / 365 * (doy + (utcH - 12) / 24);
    const eqt = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
    const dec = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
    const tst = utcH * 60 + eqt + 4 * lon;                 // true solar time in minutes
    const ha = (tst / 4 - 180) * Math.PI / 180;
    const la = lat * Math.PI / 180;
    const cz = Math.sin(la) * Math.sin(dec) + Math.cos(la) * Math.cos(dec) * Math.cos(ha);
    return 90 - Math.acos(Math.max(-1, Math.min(1, cz))) * 180 / Math.PI;
}

// [lon, lat] of a zone: the listed city, else a guess from its UTC offset (mid latitude), good enough for the day strip
function zonePos(zone, offMin) {
    return ZONE_POS[zone] ?? [offMin / 4, 40];
}

// Phases of the 24 hour blocks of the zone's current local day (sampled at each block's middle):
// 2 = day (sun 6 degrees or more above the horizon), 1 = sunrise / sunset glow (between -6 and 6), 0 = night.
function dayStrip(nowMs, offMin, lon, lat) {
    const midnight = Math.floor((nowMs + offMin * 60000) / 86400000) * 86400000 - offMin * 60000;
    const out = [];
    for (let h = 0; h < 24; h++) {
        const el = sunElevation(midnight + (h + 0.5) * 3600000, lon, lat);
        out.push(el >= 6 ? 2 : (el >= -6 ? 1 : 0));
    }
    return out;
}

// The next sunrise or sunset after nowMs (sun crossing -0.833 degrees): { rising, ms } or null (polar day / night)
function nextSun(nowMs, lon, lat) {
    const lim = -0.833, step = 600000;
    const up = sunElevation(nowMs, lon, lat) > lim;
    for (let t = nowMs; t < nowMs + 40 * 3600000; t += step) {
        if ((sunElevation(t + step, lon, lat) > lim) !== up) {
            let a = t;
            for (let m = 0; m < 10 && (sunElevation(a + 60000, lon, lat) > lim) === up; m++)
                a += 60000;
            return { rising: !up, ms: a + 60000 };
        }
    }
    return null;
}
