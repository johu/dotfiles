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

    function snapshot(notif, key) {
        return {
            key: key,
            appName: notif.appName || "",
            appIcon: notif.appIcon || "",
            summary: notif.summary || "",
            body: notif.body || "",
            urgency: notif.urgency,
            image: notif.image || "",
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
                    urgency: e.urgency,
                    image: e.image,
                    time: e.time,
                    actions: e.actions
                }));
    }

    function restoreFromAdapter() {
        root.dnd = adapter.dnd;
        root.notifications = (adapter.history || []).map(h => Object.assign({}, h, {
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
