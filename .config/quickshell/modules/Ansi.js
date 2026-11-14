.pragma library

// ANSI SGR colour output (from `bat --color=always --theme=ansi`) to the
// small HTML subset that Qt's RichText understands. Only colour and bold
// are kept; every other escape sequence is dropped.

var BASE = ["#414868", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6"];
var BRIGHT = ["#565f89", "#ff7a93", "#b9f27c", "#ff9e64", "#7da6ff", "#bb9af7", "#0db9d7", "#c0caf5"];

function hex(r, g, b) {
    function h(v) {
        var s = Math.max(0, Math.min(255, v | 0)).toString(16);
        return s.length < 2 ? "0" + s : s;
    }
    return "#" + h(r) + h(g) + h(b);
}

function color256(n) {
    if (n < 8)
        return BASE[n];
    if (n < 16)
        return BRIGHT[n - 8];
    if (n < 232) {
        var k = n - 16;
        var level = function (v) {
            return v ? 55 + v * 40 : 0;
        };
        return hex(level(Math.floor(k / 36)), level(Math.floor(k / 6) % 6), level(k % 6));
    }
    var g = 8 + (n - 232) * 10;
    return hex(g, g, g);
}

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function toHtml(input) {
    var text = input.replace(/\x1b\[[0-9;?]*[A-Za-ln-z]/g, "");
    var out = [];
    var re = /\x1b\[([0-9;]*)m/g;
    var last = 0;
    var fg = null;
    var bold = false;
    var m;

    function emit(chunk) {
        if (!chunk)
            return;
        chunk = esc(chunk);
        if (fg || bold)
            out.push('<span style="' + (fg ? "color:" + fg + ";" : "") + (bold ? "font-weight:bold;" : "") + '">' + chunk + "</span>");
        else
            out.push(chunk);
    }

    while ((m = re.exec(text)) !== null) {
        emit(text.slice(last, m.index));
        last = re.lastIndex;
        var codes = m[1] === "" ? [0] : m[1].split(";").map(Number);
        for (var i = 0; i < codes.length; i++) {
            var c = codes[i];
            if (c === 0) {
                fg = null;
                bold = false;
            } else if (c === 1) {
                bold = true;
            } else if (c === 22) {
                bold = false;
            } else if (c === 39) {
                fg = null;
            } else if (c >= 30 && c <= 37) {
                fg = BASE[c - 30];
            } else if (c >= 90 && c <= 97) {
                fg = BRIGHT[c - 90];
            } else if (c === 38) {
                if (codes[i + 1] === 5) {
                    fg = color256(codes[i + 2]);
                    i += 2;
                } else if (codes[i + 1] === 2) {
                    fg = hex(codes[i + 2], codes[i + 3], codes[i + 4]);
                    i += 4;
                }
            }
        }
    }
    emit(text.slice(last));
    return "<pre style=\"margin:0\">" + out.join("") + "</pre>";
}
