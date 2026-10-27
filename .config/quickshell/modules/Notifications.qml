pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Native org.freedesktop.Notifications daemon, replacing swaync. Owns DND
// state and notification history directly instead of polling an external
// process (see docs/ideas/native-notifications.md).
Singleton {
    id: root

    // Newest first. Each entry is a plain-data snapshot, not the live
    // Notification object (which is destroyed once closed) - see
    // liveById below for the object needed to invoke actions/dismiss
    // while a notification is still tracked by the server.
    property var notifications: []
    readonly property var popups: root.notifications.filter(n => n.popup)
    readonly property var history: root.notifications.filter(n => n.closed)

    // New arrivals beyond this many simultaneously visible popups wait in
    // a FIFO queue (promoteQueued()) instead of stacking the popup column
    // past the bottom of the screen. Critical notifications bypass the cap
    // entirely, same as they bypass DND/fullscreen suppression.
    property int maxVisiblePopups: 3

    property bool dnd: false
    // Set by setDndSilently() for the duration of its own assignment, so
    // the Dashboard tile (which already shows the toggled state visually)
    // doesn't also pop a redundant toast - the bar bell's right-click
    // still assigns `dnd` directly and keeps the toast.
    property bool suppressDndToast: false
    onDndChanged: {
        adapter.dnd = root.dnd;
        if (root.initialized && !root.suppressDndToast)
            ToastManager.show(root.dnd ? "DND on" : "DND off", root.dnd ? "\uf1f7" : "\uf0a2");
    }

    function setDndSilently(value) {
        root.suppressDndToast = true;
        root.dnd = value;
        root.suppressDndToast = false;
    }

    property int unreadCount: 0
    function markSeen() {
        root.unreadCount = 0;
    }

    property bool initialized: false
    property var liveById: ({})
    property int seq: 0

    function hasFullscreen() {
        for (const monitor of Hyprland.monitors.values) {
            if (monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject?.fullscreen > 1))
                return true;
        }
        return false;
    }

    function expiryMsFor(notif) {
        if (notif.urgency === NotificationUrgency.Critical)
            return 0;
        if (notif.expireTimeout === 0)
            return 0;
        if (notif.expireTimeout > 0)
            return Math.min(notif.expireTimeout * 1000, 30000);
        return notif.urgency === NotificationUrgency.Low ? 5000 : 8000;
    }

    function escapeHtml(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
    }

    // A spec-compliant app (bodyMarkupSupported) sends its body pre-escaped,
    // using only a small set of real tags (we allow b/i/u, same whitelist
    // swaync uses) - e.g. Discord already escapes literal '<'/'&' in
    // message text, hyprshot wraps its path in <i>. Escaping the body
    // again on our end would double-escape those and show literal
    // "&lt;"/"&amp;" text. So: if the only angle brackets left after
    // stripping our whitelisted tags are none, and every '&' starts a
    // real entity, trust the body as already-safe markup. Otherwise an
    // app sent raw unescaped text (a bare '<'/'&' that would break
    // Text.StyledText parsing) and we fall back to escaping everything,
    // then restoring just the whitelist - same defensive two-path
    // strategy swaync's set_body() uses (try raw parse, escape+whitelist
    // on failure), just decided up front since QML gives no parse-error
    // signal to catch.
    function looksLikeSafeMarkup(body) {
        const stripped = body.replace(/<\/?(?:b|i|u)>/gi, "");
        if (/</.test(stripped))
            return false;
        if (/&(?!amp;|lt;|gt;|quot;|#39;|apos;|#\d+;|#x[0-9a-f]+;)/i.test(stripped))
            return false;
        return true;
    }

    // Bare URLs get wrapped in an <a href> so the StyledText body in
    // NotificationCard/NotificationHistory can render and open them.
    function linkify(body) {
        if (!body)
            return "";
        let safe = body;
        if (!root.looksLikeSafeMarkup(body)) {
            safe = root.escapeHtml(body).replace(/&lt;(\/?(?:b|i|u))&gt;/gi, "<$1>");
        }
        return safe.replace(/(https?:\/\/[^\s<>"']+)/gi, match => `<a href="${match}">${match}</a>`);
    }

    readonly property string homeDir: Quickshell.env("HOME")

    function isImagePath(path) {
        return /\.(png|jpe?g|gif|webp|bmp)$/i.test(path || "");
    }

    // hyprshot (and anything else using notify-send -i <path>) passes a
    // path relative to $HOME, not the shell's cwd - QPixmap(path), which
    // Quickshell's image providers fall back to, resolves relative paths
    // against the process's own cwd and silently fails to load it.
    function resolveImagePath(path) {
        return path.startsWith("/") ? path : root.homeDir + "/" + path;
    }

    // notify-send -i accepts an arbitrary file path, not just a themed icon
    // name - hyprshot uses it to pass the screenshot it just took. Treat an
    // appIcon that looks like a path to an image file as a preview image
    // rather than just a small status icon. Quickshell itself also mirrors
    // a path-like appIcon into `image` as "image://icon/<path>" - that
    // carries the same unresolved-relative-path problem, so unwrap it too.
    // Only ever resolves to a file:// path, never a provider URL
    // (image://qsimage/..., image://icon/<theme-name>) - those back onto
    // the live Notification object's own pixel buffer/theme lookup and
    // silently fail to decode once the notification closes and only this
    // persisted snapshot remains, leaving a blank reserved-height gap
    // where the preview Rectangle sits. A real screenshot on disk doesn't
    // have that problem, so only file-path-looking sources get the big
    // preview; everything else still gets the small header icon via
    // ResolvedIcon.
    function previewImageFor(notif) {
        if (root.isImagePath(notif.appIcon))
            return "file://" + root.resolveImagePath(notif.appIcon);
        const wrapped = (notif.image || "").match(/^image:\/\/icon\/(.+)$/);
        if (wrapped && root.isImagePath(wrapped[1]))
            return "file://" + root.resolveImagePath(wrapped[1]);
        return "";
    }

    // The small header/list icon. appIcon (the real app_icon D-Bus
    // parameter) is the normal case - Discord sets it to "discord", etc.
    // But notify-send's own -i/--icon flag populates the "icon" hint
    // instead (landing in `image`, not `appIcon`) - hyprshot and this
    // Firefox download example both go through that path, so without this
    // fallback they'd show no icon at all. A themed-icon-name `image` is
    // safe to keep indefinitely (icon-theme lookups don't go stale), but
    // skip image://qsimage/... - like previewImageFor, that's the live
    // notification's own embedded pixel buffer and won't resolve once the
    // notification closes into history.
    function iconSourceFor(notif) {
        if (notif.appIcon)
            return "image://icon/" + notif.appIcon;
        if (!notif.image || notif.image.startsWith("image://qsimage/"))
            return "";
        // A path-like `image` value (e.g. hyprshot's screenshot path, via
        // notify-send -i) is already shown as the big preview image via
        // previewImageFor() - showing it again as a tiny icon just renders
        // Quickshell's checkerboard "missing icon" placeholder, since
        // image://icon/ never reports a load failure for an unresolved
        // relative path (it only works for real file:// URIs or themed
        // icon names). Skip the icon entirely in that case.
        const wrapped = notif.image.match(/^image:\/\/icon\/(.+)$/);
        if (wrapped && root.isImagePath(wrapped[1]))
            return "";
        return notif.image;
    }

    function snapshot(notif, key) {
        return {
            key: key,
            appName: notif.appName || "",
            appIcon: notif.appIcon || "",
            summary: notif.summary || "",
            body: notif.body || "",
            richBody: root.linkify(notif.body || ""),
            urgency: notif.urgency,
            image: notif.image || "",
            iconSource: root.iconSourceFor(notif),
            previewImage: root.previewImageFor(notif),
            resident: notif.resident,
            time: Date.now(),
            actions: (notif.actions || []).map(a => ({
                        identifier: a.identifier,
                        text: a.text
                    })),
            popup: false,
            queued: false,
            closed: false,
            expiresAt: 0,
            durationMs: 0
        };
    }

    function handleNotification(notif) {
        notif.tracked = true;

        const key = ++root.seq;
        const entry = snapshot(notif, key);
        root.liveById[key] = notif;

        const critical = notif.urgency === NotificationUrgency.Critical;
        const suppressed = !critical && (root.dnd || root.hasFullscreen());
        const visibleCount = root.notifications.filter(n => n.popup).length;
        entry.durationMs = root.expiryMsFor(notif);

        if (suppressed) {
            // Not shown, but still counts down toward history on its own -
            // the cap/queue below only applies to notifications that would
            // otherwise be visible right now.
            entry.expiresAt = entry.durationMs > 0 ? Date.now() + entry.durationMs : 0;
        } else if (!critical && visibleCount >= root.maxVisiblePopups) {
            entry.queued = true;
        } else {
            entry.popup = true;
            entry.expiresAt = entry.durationMs > 0 ? Date.now() + entry.durationMs : 0;
        }

        root.notifications = [entry, ...root.notifications];
        root.unreadCount++;

        notif.closed.connect(reason => root.onNotifClosed(key));
    }

    function onNotifClosed(key) {
        delete root.liveById[key];
        root.notifications = root.notifications.map(e => e.key === key ? Object.assign({}, e, {
                    popup: false,
                    queued: false,
                    closed: true
                }) : e);
        root.persistHistory();
        root.promoteQueued();
    }

    // Promotes the oldest still-queued notification into a visible popup
    // slot once one frees up (called after any popup closes).
    function promoteQueued() {
        const visible = root.notifications.filter(n => n.popup).length;
        if (visible >= root.maxVisiblePopups)
            return;
        const queued = root.notifications.filter(n => n.queued && !n.closed);
        if (queued.length === 0)
            return;
        const next = queued.reduce((a, b) => a.key < b.key ? a : b);
        const now = Date.now();
        root.notifications = root.notifications.map(e => e.key === next.key ? Object.assign({}, e, {
                    popup: true,
                    queued: false,
                    expiresAt: e.durationMs > 0 ? now + e.durationMs : 0
                }) : e);
    }

    function checkExpiry() {
        const now = Date.now();
        for (const e of root.notifications) {
            if (!e.closed && e.expiresAt > 0 && now >= e.expiresAt) {
                const n = root.liveById[e.key];
                if (n)
                    n.expire();
            }
        }
    }

    function invokeAction(key, identifier) {
        const n = root.liveById[key];
        if (!n)
            return;
        const action = (n.actions || []).find(a => a.identifier === identifier);
        if (action)
            action.invoke();
    }

    function dismissPopup(key) {
        const n = root.liveById[key];
        if (n)
            n.dismiss();
    }

    function removeHistory(key) {
        const n = root.liveById[key];
        if (n)
            n.dismiss();
        root.notifications = root.notifications.filter(e => e.key !== key);
        root.persistHistory();
    }

    function clearHistory() {
        root.notifications = root.notifications.filter(e => !e.closed);
        root.persistHistory();
    }

    function persistHistory() {
        adapter.history = root.history.slice(0, 100).map(e => ({
                    key: e.key,
                    appName: e.appName,
                    appIcon: e.appIcon,
                    summary: e.summary,
                    body: e.body,
                    richBody: e.richBody,
                    urgency: e.urgency,
                    image: e.image,
                    iconSource: e.iconSource,
                    previewImage: e.previewImage,
                    time: e.time,
                    actions: e.actions
                }));
    }

    function restoreFromAdapter() {
        root.dnd = adapter.dnd;
        root.notifications = (adapter.history || []).map(h => Object.assign({}, h, {
                    richBody: root.linkify(h.body || ""),
                    iconSource: root.iconSourceFor(h),
                    previewImage: root.previewImageFor(h),
                    popup: false,
                    queued: false,
                    closed: true,
                    expiresAt: 0,
                    durationMs: 0
                }));
        root.seq = root.notifications.reduce((max, e) => Math.max(max, e.key), 0);
        root.initialized = true;
    }

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
    }

    FileView {
        id: stateFile
        path: root.stateDir + "/notifications.json"
        printErrors: false
        onLoaded: root.restoreFromAdapter()
        onLoadFailed: root.restoreFromAdapter()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property var history: []
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.notifications.some(e => !e.closed && e.expiresAt > 0)
        onTriggered: root.checkExpiry()
    }

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notif => root.handleNotification(notif)
    }
}
