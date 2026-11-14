.pragma library

// URL and filesystem path detection for the launcher (omacast row 15).
// Detection is strict on purpose: "notes.md" or "7zip" must stay app searches.

var TLDS = ["com", "org", "net", "io", "dev", "de", "eu", "app", "ai", "uk", "gov", "edu", "info", "tv", "xyz", "ch", "fr", "nl", "ca"];

// { kind: "url", url, text } or null.
function classifyUrl(q) {
    if (/^(https?|ftp):\/\/\S+$/i.test(q))
        return { kind: "url", url: q, text: q };
    if (/^www\.[a-z0-9-]+(\.[a-z0-9-]+)+([:\/?#]\S*)?$/i.test(q))
        return { kind: "url", url: "https://" + q, text: q };
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?([\/?#]\S*)?$/i.test(q))
        return { kind: "url", url: "http://" + q, text: q };
    var m = q.match(/^([a-z0-9-]+\.)+([a-z]{2,})(:\d+)?([\/?#]\S*)?$/i);
    if (m && TLDS.indexOf(m[2].toLowerCase()) >= 0)
        return { kind: "url", url: "https://" + q, text: q };
    return null;
}

function isPathLike(q) {
    return q === "~" || q.indexOf("~/") === 0 || q.charAt(0) === "/";
}

function expand(q, home) {
    if (q === "~")
        return home;
    if (q.indexOf("~/") === 0)
        return home + q.slice(1);
    return q;
}

function display(path, home) {
    if (home && (path === home || path.indexOf(home + "/") === 0))
        return "~" + path.slice(home.length);
    return path;
}
