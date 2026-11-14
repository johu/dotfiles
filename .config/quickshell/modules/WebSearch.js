.pragma library

// Web search providers for the launcher fallback row (omacast row 14).
// One line per provider: `prefix` is typed before the query ("yt cats"),
// `url` takes the percent-encoded query at %s.
var PROVIDERS = [
    { id: "ddg", name: "DuckDuckGo", prefix: "ddg", url: "https://duckduckgo.com/?q=%s" },
    { id: "google", name: "Google", prefix: "g", url: "https://www.google.com/search?q=%s" },
    { id: "chatgpt", name: "ChatGPT", prefix: "gpt", url: "https://chatgpt.com/?q=%s" },
    { id: "amazon", name: "Amazon", prefix: "a", url: "https://www.amazon.de/s?k=%s" },
    { id: "youtube", name: "YouTube", prefix: "yt", url: "https://www.youtube.com/results?search_query=%s" },
    { id: "wikipedia", name: "Wikipedia", prefix: "w", url: "https://en.wikipedia.org/w/index.php?search=%s" },
    { id: "github", name: "GitHub", prefix: "gh", url: "https://github.com/search?q=%s" }
];

var DEFAULT_ID = "ddg";

function byId(id) {
    for (var i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].id === id)
            return PROVIDERS[i];
    }
    return PROVIDERS[0];
}

function defaultProvider() {
    return byId(DEFAULT_ID);
}

// All providers with `firstId` first, the rest in list order.
function ordered(firstId) {
    var first = byId(firstId);
    return [first].concat(PROVIDERS.filter(function (p) {
        return p.id !== first.id;
    }));
}

// "yt cats" -> { provider, text: "cats" }; null when there is no known
// prefix followed by a space and some text.
function parsePrefix(query) {
    var m = query.match(/^(\S+)\s+(.+)$/);
    if (!m)
        return null;
    var prefix = m[1].toLowerCase();
    for (var i = 0; i < PROVIDERS.length; i++) {
        if (PROVIDERS[i].prefix === prefix)
            return { provider: PROVIDERS[i], text: m[2].trim() };
    }
    return null;
}

function url(provider, text) {
    return provider.url.split("%s").join(encodeURIComponent(text));
}
