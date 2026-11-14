.pragma library

// Launcher calculator (omacast row 13): arithmetic, %, a few functions and
// unit conversions. Hand-written tokenizer + recursive-descent parser;
// user text is never passed to eval/Function.
//
// evaluate(text) -> null when the text is not clearly a calculation, else
// { expr, text, copy } where `text` is shown and `copy` goes to the clipboard.

var FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    ln: Math.log, log: Math.log10, sin: Math.sin, cos: Math.cos, tan: Math.tan
};
var CONSTS = { pi: Math.PI, e: Math.E };

// category -> { unit: factor to the category's base unit }
var UNITS = {
    length: { m: 1, km: 1000, dm: 0.1, cm: 0.01, mm: 0.001, um: 1e-6, nm: 1e-9, mi: 1609.344, ft: 0.3048, inch: 0.0254, yd: 0.9144, nmi: 1852 },
    mass: { kg: 1, g: 0.001, mg: 1e-6, ug: 1e-9, lb: 0.45359237, oz: 0.028349523125, t: 1000, st: 6.35029318 },
    volume: { l: 1, ml: 0.001, cl: 0.01, dl: 0.1, hl: 100, m3: 1000, cm3: 0.001, mm3: 1e-6, gal: 3.785411784, qt: 0.946352946, pt: 0.473176473, cup: 0.2365882365, floz: 0.0295735295625, tbsp: 0.01478676478125, tsp: 0.00492892159375 },
    time: { s: 1, ms: 0.001, min: 60, h: 3600, d: 86400, wk: 604800 },
    data: { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
    area: { mm2: 1e-6, cm2: 1e-4, m2: 1, km2: 1e6, ha: 1e4 },
    pressure: { pa: 1, hpa: 100, kpa: 1000, mpa: 1e6, mbar: 100, bar: 1e5 },
    energy: { j: 1, kj: 1000, cal: 4.184, kcal: 4184, wh: 3600, kwh: 3.6e6 },
    power: { w: 1, kw: 1000, gw: 1e9 },
    frequency: { hz: 1, khz: 1e3, mhz: 1e6, ghz: 1e9 },
    speed: { "m/s": 1, "km/h": 1 / 3.6, mph: 0.44704, kn: 1852 / 3600 },
    temp: { c: 1, f: 1, k: 1 }
};

var ALIASES = {
    meter: "m", meters: "m", metre: "m", metres: "m", kilometer: "km", kilometers: "km", kilometre: "km", kilometres: "km",
    centimeter: "cm", centimeters: "cm", millimeter: "mm", millimeters: "mm", mile: "mi", miles: "mi",
    foot: "ft", feet: "ft", inches: "inch", yard: "yd", yards: "yd",
    kilogram: "kg", kilograms: "kg", gram: "g", grams: "g", pound: "lb", pounds: "lb", lbs: "lb", ounce: "oz", ounces: "oz",
    liter: "l", liters: "l", litre: "l", litres: "l", milliliter: "ml", milliliters: "ml", gallon: "gal", gallons: "gal",
    second: "s", seconds: "s", sec: "s", secs: "s", minute: "min", minutes: "min", mins: "min",
    hour: "h", hours: "h", hr: "h", hrs: "h", day: "d", days: "d", week: "wk", weeks: "wk",
    byte: "b", bytes: "b", kilobyte: "kb", kilobytes: "kb", megabyte: "mb", megabytes: "mb", gigabyte: "gb", gigabytes: "gb", terabyte: "tb", terabytes: "tb",
    kmh: "km/h", kph: "km/h", knot: "kn", knots: "kn",
    celsius: "c", fahrenheit: "f", kelvin: "k",
    // metric
    decimeter: "dm", decimeters: "dm", micron: "um", microns: "um", micrometer: "um", micrometers: "um", nanometer: "nm", nanometers: "nm",
    milligram: "mg", milligrams: "mg", microgram: "ug", micrograms: "ug", mcg: "ug", tonne: "t", tonnes: "t",
    centiliter: "cl", centiliters: "cl", deciliter: "dl", deciliters: "dl", hectoliter: "hl", hectoliters: "hl", cc: "cm3",
    sqm: "m2", sqkm: "km2", sqcm: "cm2", sqmm: "mm2", hectare: "ha", hectares: "ha",
    pascal: "pa", pascals: "pa", hectopascal: "hpa", hectopascals: "hpa", kilopascal: "kpa", kilopascals: "kpa", megapascal: "mpa", megapascals: "mpa", millibar: "mbar", millibars: "mbar",
    joule: "j", joules: "j", kilojoule: "kj", kilojoules: "kj", calorie: "cal", calories: "cal", kilocalorie: "kcal", kilocalories: "kcal",
    watthour: "wh", watthours: "wh", kilowatthour: "kwh", kilowatthours: "kwh",
    watt: "w", watts: "w", kilowatt: "kw", kilowatts: "kw", gigawatt: "gw", gigawatts: "gw",
    hertz: "hz", kilohertz: "khz", megahertz: "mhz", gigahertz: "ghz"
};

// Display labels where the lowercase key reads badly.
var LABELS = {
    inch: "in", b: "B", kb: "kB", mb: "MB", gb: "GB", tb: "TB", kib: "KiB", mib: "MiB", gib: "GiB", tib: "TiB",
    wk: "wk", c: "°C", f: "°F", k: "K",
    um: "µm", ug: "µg", mm2: "mm²", cm2: "cm²", m2: "m²", km2: "km²", m3: "m³", cm3: "cm³", mm3: "mm³",
    pa: "Pa", hpa: "hPa", kpa: "kPa", mpa: "MPa", j: "J", kj: "kJ", wh: "Wh", kwh: "kWh",
    w: "W", kw: "kW", gw: "GW", hz: "Hz", khz: "kHz", mhz: "MHz", ghz: "GHz"
};

function findUnit(name) {
    var u = name.replace(/°/g, "");
    if (ALIASES[u])
        u = ALIASES[u];
    for (var pass = 0; pass < 2; pass++) {
        for (var cat in UNITS) {
            if (Object.prototype.hasOwnProperty.call(UNITS[cat], u))
                return { cat: cat, unit: u };
        }
        if (pass === 0 && u.length > 1 && u.charAt(u.length - 1) === "s")
            u = u.slice(0, -1);
        else
            break;
    }
    return null;
}

function toCelsius(v, u) {
    return u === "f" ? (v - 32) * 5 / 9 : (u === "k" ? v - 273.15 : v);
}

function fromCelsius(v, u) {
    return u === "f" ? v * 9 / 5 + 32 : (u === "k" ? v + 273.15 : v);
}

function convert(v, from, to) {
    if (from.cat !== to.cat)
        return null;
    if (from.cat === "temp")
        return fromCelsius(toCelsius(v, from.unit), to.unit);
    return v * UNITS[from.cat][from.unit] / UNITS[to.cat][to.unit];
}

function fmt(v) {
    if (v === 0)
        return "0";
    var a = Math.abs(v);
    if (a >= 1e15 || a < 1e-6)
        return Number(v.toPrecision(10)).toExponential().replace("e+", "e");
    return Number(v.toPrecision(10)).toString();
}

function tokenize(s) {
    var tokens = [];
    var i = 0;
    while (i < s.length) {
        var c = s.charAt(i);
        if (c === " ") {
            i++;
            continue;
        }
        var rest = s.slice(i);
        var m = rest.match(/^(\d+(\.\d+)?|\.\d+)(e[+-]?\d+)?/);
        if (m) {
            tokens.push({ t: "num", v: parseFloat(m[0]) });
            i += m[0].length;
            continue;
        }
        m = rest.match(/^[a-z]+/);
        if (m) {
            tokens.push({ t: "word", v: m[0] });
            i += m[0].length;
            continue;
        }
        if ("+-*/^%(),".indexOf(c) >= 0) {
            tokens.push({ t: "op", v: c });
            i++;
            continue;
        }
        return null;
    }
    return tokens;
}

// Returns { v, ops } or null. `ops` counts operators/functions/percents so
// a bare number or constant is not treated as a calculation.
function parseExpr(tokens) {
    var pos = 0;
    var ops = 0;
    function fail() {
        throw new Error("parse");
    }
    function peek() {
        return tokens[pos];
    }
    function isOp(ch) {
        var t = tokens[pos];
        return t && t.t === "op" && t.v === ch;
    }

    function expr() {
        var left = term();
        while (isOp("+") || isOp("-")) {
            var op = tokens[pos++].v;
            var r = term();
            // "200 + 10%" means 10% of 200.
            var rv = r.pct ? left.v * r.v : r.v;
            left = { v: op === "+" ? left.v + rv : left.v - rv, pct: false };
            ops++;
        }
        return left;
    }

    function term() {
        var left = unary();
        for (;;) {
            if (isOp("*") || isOp("/")) {
                var op = tokens[pos++].v;
                var r = unary();
                if (op === "/" && r.v === 0)
                    fail();
                left = { v: op === "*" ? left.v * r.v : left.v / r.v, pct: false };
                ops++;
            } else if (peek() && peek().t === "word" && peek().v === "of") {
                pos++;
                var r2 = unary();
                if (!left.pct)
                    fail();
                left = { v: left.v * r2.v, pct: false };
                ops++;
            } else {
                return left;
            }
        }
    }

    function unary() {
        if (isOp("-")) {
            pos++;
            var u = unary();
            return { v: -u.v, pct: u.pct };
        }
        if (isOp("+")) {
            pos++;
            return unary();
        }
        return power();
    }

    function power() {
        var base = postfix();
        if (isOp("^")) {
            pos++;
            var ex = unary();
            ops++;
            return { v: Math.pow(base.v, ex.v), pct: false };
        }
        return base;
    }

    function postfix() {
        var p = primary();
        if (isOp("%")) {
            pos++;
            ops++;
            return { v: p.v / 100, pct: true };
        }
        return p;
    }

    function primary() {
        var t = tokens[pos];
        if (!t)
            fail();
        if (t.t === "num") {
            pos++;
            return { v: t.v, pct: false };
        }
        if (t.t === "op" && t.v === "(") {
            pos++;
            var inner = expr();
            if (!isOp(")"))
                fail();
            pos++;
            return { v: inner.v, pct: false };
        }
        if (t.t === "word") {
            if (Object.prototype.hasOwnProperty.call(FUNCS, t.v)) {
                pos++;
                if (!isOp("("))
                    fail();
                pos++;
                var arg = expr();
                if (!isOp(")"))
                    fail();
                pos++;
                ops++;
                return { v: FUNCS[t.v](arg.v), pct: false };
            }
            if (Object.prototype.hasOwnProperty.call(CONSTS, t.v)) {
                pos++;
                return { v: CONSTS[t.v], pct: false };
            }
        }
        fail();
    }

    try {
        var res = expr();
        if (pos !== tokens.length || !isFinite(res.v))
            return null;
        return { v: res.v, ops: ops };
    } catch (e) {
        return null;
    }
}

function calc(s) {
    var tokens = tokenize(s);
    if (!tokens || tokens.length === 0)
        return null;
    return parseExpr(tokens);
}

function evaluate(input) {
    if (!input || input.length > 120)
        return null;
    var s = input.trim().toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/[µμ]/g, "u").replace(/²/g, "2").replace(/³/g, "3").replace(/\s+/g, " ");
    // Decimal comma (only when there is no dot): 1,5 + 2 -> 1.5 + 2
    if (s.indexOf(".") < 0)
        s = s.replace(/(\d),(\d)/g, "$1.$2");
    if (!/[\d]/.test(s))
        return null;
    // Dates like 2024-11-14 are not subtractions.
    if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(s))
        return null;

    // Unit conversion: "<expr> <unit> in|to|as <unit>"
    var cv = s.match(/^(.+?)\s+(?:in|to|as)\s+([a-z°\/][a-z0-9°\/]*)$/);
    if (cv) {
        var left = cv[1].match(/^(.*[\d)])\s*([a-z°\/][a-z0-9°\/]*)$/);
        if (!left)
            return null;
        var from = findUnit(left[2]);
        var to = findUnit(cv[2]);
        var r = calc(left[1]);
        if (!from || !to || !r)
            return null;
        var out = convert(r.v, from, to);
        if (out === null || !isFinite(out))
            return null;
        var label = LABELS[to.unit] || to.unit;
        var text = fmt(out) + " " + label;
        return { expr: input.trim(), text: text, copy: text };
    }

    var res = calc(s);
    if (!res || res.ops === 0)
        return null;
    var t = fmt(res.v);
    return { expr: input.trim(), text: t, copy: t };
}
