.pragma library

// Match positions for highlighting file results. `fzf --filter` only prints
// the matching lines, so the positions are recomputed here: same query
// syntax (space = AND, 'exact, ^prefix, suffix$; !negated terms are
// skipped), greedy and compact rather than fzf's optimal alignment.

function sub(hay, n, from) {
    var j = 0;
    var end = -1;
    var i;
    for (i = from; i < hay.length && j < n.length; i++) {
        if (hay.charAt(i) === n.charAt(j)) {
            j++;
            end = i;
        }
    }
    if (j < n.length)
        return null;
    var pos = [];
    j = n.length - 1;
    for (i = end; i >= from && j >= 0; i--) {
        if (hay.charAt(i) === n.charAt(j)) {
            pos.push(i);
            j--;
        }
    }
    return pos;
}

function matchToken(tok, path) {
    var exact = false;
    var prefix = false;
    var suffix = false;
    if (tok.charAt(0) === "'") {
        exact = true;
        tok = tok.slice(1);
    }
    if (tok.charAt(0) === "^") {
        prefix = true;
        tok = tok.slice(1);
    }
    if (tok.charAt(tok.length - 1) === "$") {
        suffix = true;
        tok = tok.slice(0, -1);
    }
    if (!tok)
        return [];
    // Smart case, like fzf.
    var cs = tok !== tok.toLowerCase();
    var hay = cs ? path : path.toLowerCase();
    var n = cs ? tok : tok.toLowerCase();
    var start = -1;
    if (prefix)
        start = hay.indexOf(n) === 0 ? 0 : -1;
    else if (suffix)
        start = hay.length >= n.length && hay.slice(hay.length - n.length) === n ? hay.length - n.length : -1;
    else if (exact)
        start = hay.lastIndexOf(n);
    if (prefix || suffix || exact) {
        if (start < 0)
            return [];
        var out = [];
        for (var k = 0; k < n.length; k++)
            out.push(start + k);
        return out;
    }
    var base = hay.lastIndexOf("/") + 1;
    return sub(hay, n, base) || sub(hay, n, 0) || [];
}

// Set of highlighted indices into `path`.
function positions(query, path) {
    var set = {};
    var toks = query.split(/\s+/);
    for (var i = 0; i < toks.length; i++) {
        var t = toks[i];
        if (!t || t === "|" || t.charAt(0) === "!")
            continue;
        var p = matchToken(t, path);
        for (var j = 0; j < p.length; j++)
            set[p[j]] = true;
    }
    return set;
}

function esc(c) {
    return c === "&" ? "&amp;" : (c === "<" ? "&lt;" : (c === ">" ? "&gt;" : c));
}

// StyledText for `text`; char i is highlighted when set[i + delta].
function html(text, set, delta, color) {
    var out = "";
    var open = false;
    for (var i = 0; i < text.length; i++) {
        var on = set[i + delta] === true;
        if (on && !open) {
            out += '<font color="' + color + '"><b>';
            open = true;
        } else if (!on && open) {
            out += "</b></font>";
            open = false;
        }
        out += esc(text.charAt(i));
    }
    if (open)
        out += "</b></font>";
    return out;
}
