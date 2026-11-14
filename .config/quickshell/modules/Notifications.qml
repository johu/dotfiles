pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Native notification daemon (replaces swaync); owns DND state and history.
// See docs/ideas/native-notifications.md.
Singleton {
    id: root

    // Newest first. Plain-data snapshots: the live Notification is destroyed on
    // close (see liveById).
    property var notifications: []
    readonly property var popups: root.notifications.filter(n => n.popup)
    readonly property var history: root.notifications.filter(n => n.closed)

    // Popups beyond this wait in a FIFO queue (promoteQueued()). Critical
    // notifications bypass the cap.
    property int maxVisiblePopups: 3

    property bool dnd: false
    // Set while setDndSilently() assigns dnd, so the dashboard tile doesn't
    // also toast.
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

    // Debug: `qs ipc call notifmock set 5` fakes the unread badge count
    // (`set 12` shows "9+", `set 0` clears it). DND hides the badge.
    IpcHandler {
        target: "notifmock"
        function set(count: int): void {
            root.unreadCount = count;
        }
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
        return notif.urgency === NotificationUrgency.Low ? 8000 : 12000;
    }

    function escapeHtml(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
    }

    // Spec-compliant apps send an already-escaped body with only b/i/u tags;
    // escaping again would show literal "&lt;". Trust the body if no stray '<'
    // remains and every '&' starts an entity. Otherwise escape everything and
    // restore the whitelist.
    function looksLikeSafeMarkup(body) {
        const stripped = body.replace(/<\/?(?:b|i|u)>/gi, "");
        if (/</.test(stripped))
            return false;
        if (/&(?!amp;|lt;|gt;|quot;|#39;|apos;|#\d+;|#x[0-9a-f]+;)/i.test(stripped))
            return false;
        return true;
    }

    // Wrap bare URLs in <a href> so StyledText can render and open them.
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

    // notify-send -i paths are relative to $HOME, but Quickshell resolves them
    // against the cwd and fails to load them.
    function resolveImagePath(path) {
        return path.startsWith("/") ? path : root.homeDir + "/" + path;
    }

    // A path-like appIcon (e.g. hyprshot's screenshot) becomes the big preview.
    // Quickshell mirrors it into `image` as image://icon/<path>, so unwrap
    // that too. Provider URLs die with the live notification, so only file://
    // paths qualify.
    function previewImageFor(notif) {
        if (root.isImagePath(notif.appIcon))
            return "file://" + root.resolveImagePath(notif.appIcon);
        const wrapped = (notif.image || "").match(/^image:\/\/icon\/(.+)$/);
        if (wrapped && root.isImagePath(wrapped[1]))
            return "file://" + root.resolveImagePath(wrapped[1]);
        return "";
    }

    // Small header icon. notify-send -i fills `image` instead of appIcon, so
    // fall back to it. Skip image://qsimage/..., which doesn't outlive the
    // live notification.
    function iconSourceFor(notif) {
        // A cached avatar wins over the generic app icon.
        if (notif.cachedImage)
            return notif.cachedImage;
        if (notif.appIcon)
            return "image://icon/" + notif.appIcon;
        if (!notif.image || notif.image.startsWith("image://qsimage/"))
            return "";
        // A path-like `image` is already the big preview; as an icon it would
        // render a missing-icon checkerboard.
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
            cachedImage: "",
            popup: false,
            queued: false,
            closed: false,
            expiresAt: 0,
            durationMs: 0
        };
    }

    // image://qsimage/... dies with the live Notification. Rasterize it to a
    // file while alive so avatars survive into history.
    function cacheLiveImage(key, source) {
        imageCache.cache(key, source, root.imageCacheDir, path => {
            if (path)
                root.applyCachedImage(key, path);
        });
    }

    function applyCachedImage(key, path) {
        const fileUrl = "file://" + path;
        root.notifications = root.notifications.map(e => {
            if (e.key !== key)
                return e;
            const updated = Object.assign({}, e, {
                        cachedImage: fileUrl
                    });
            updated.iconSource = root.iconSourceFor(updated);
            return updated;
        });
        const entry = root.notifications.find(e => e.key === key);
        if (entry && entry.closed)
            root.persistHistory();
    }

    function relativeTime(ms) {
        if (!ms)
            return "";
        const diffSec = Math.max(0, Math.floor((Date.now() - ms) / 1000));
        if (diffSec < 60)
            return "now";
        const diffMin = Math.floor(diffSec / 60);
        if (diffMin < 60)
            return diffMin + "m";
        const diffHour = Math.floor(diffMin / 60);
        if (diffHour < 24)
            return diffHour + "h";
        const diffDay = Math.floor(diffHour / 24);
        return diffDay + "d";
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
            // Hidden, but still counts down to history; the cap/queue only applies to
            // visible popups.
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

        if (notif.image.startsWith("image://qsimage/"))
            root.cacheLiveImage(key, notif.image);
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

    // Promote the oldest queued notification when a popup slot frees up.
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
        const entry = root.notifications.find(e => e.key === key);
        if (entry && entry.cachedImage)
            imageCache.deleteCachedMany([entry.cachedImage]);
        root.notifications = root.notifications.filter(e => e.key !== key);
        root.persistHistory();
    }

    function clearHistory() {
        const removedImages = root.notifications.filter(e => e.closed && e.cachedImage).map(e => e.cachedImage);
        if (removedImages.length > 0)
            imageCache.deleteCachedMany(removedImages);
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
                    cachedImage: e.cachedImage,
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
    readonly property string imageCacheDir: Quickshell.env("HOME") + "/.cache/quickshell/notif-images"

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir, root.imageCacheDir]
    }

    NotifImageCache {
        id: imageCache
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
