.pragma library

// Number formatting for the launcher's system view.

function bytes(n, digits) {
    if (n === null || n === undefined || isNaN(n))
        return "–";
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let v = Math.abs(n), i = 0;
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    const d = digits !== undefined ? digits : (i === 0 || v >= 100 ? 0 : (v >= 10 ? 1 : 2));
    return (n < 0 ? "-" : "") + v.toFixed(d) + " " + units[i];
}

function rate(n) {
    return bytes(n) + "/s";
}

function pct(v, d) {
    return (v === null || v === undefined || isNaN(v)) ? "–" : v.toFixed(d === undefined ? 0 : d) + " %";
}

function temp(v) {
    return (v === null || v === undefined || isNaN(v)) ? "–" : Math.round(v) + " °C";
}

function watts(v) {
    return (v === null || v === undefined || isNaN(v)) ? "–" : v.toFixed(v >= 100 ? 0 : 1) + " W";
}

function ghz(mhz) {
    return (mhz === null || mhz === undefined) ? "–" : (mhz / 1000).toFixed(2) + " GHz";
}

function duration(sec) {
    const t = Math.max(0, Math.floor(sec));
    const d = Math.floor(t / 86400), h = Math.floor(t % 86400 / 3600), m = Math.floor(t % 3600 / 60), s = t % 60;
    const p = n => String(n).padStart(2, "0");
    return d > 0 ? d + "d " + p(h) + ":" + p(m) : p(h) + ":" + p(m) + ":" + p(s);
}

function remaining(sec) {
    if (sec === null || sec === undefined)
        return "–";
    const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60);
    return h > 0 ? h + " h " + m + " min" : m + " min";
}

// Round a maximum up to 1, 2, 5 x 10^n so graph axes get readable labels.
function niceMax(v) {
    if (!(v > 0))
        return 1;
    const e = Math.pow(10, Math.floor(Math.log10(v)));
    const m = v / e;
    return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10) * e;
}

// Axis label for a graph value of the given unit ("%", "rate", "°C", "W").
function axis(v, unit) {
    switch (unit) {
    case "rate":
        return rate(v);
    case "°C":
        return Math.round(v) + "°";
    case "W":
        return Math.round(v) + " W";
    }
    return Math.round(v) + " %";
}
