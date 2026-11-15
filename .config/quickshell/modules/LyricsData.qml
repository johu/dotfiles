pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics for the track shown in the launcher's media view. request() looks a
// track up (disk cache first, then LRCLIB, see scripts/lyrics.py) and exposes
// the result; asking again for the same track is free. Nothing is fetched
// unless a view asks, so the shell makes no network calls while the media
// view is closed.
Singleton {
    id: root

    // "idle" | "loading" | "ok" | "instrumental" | "none" | "error"
    property string status: "idle"
    property bool synced: false
    // synced: [{ t: seconds, s: text }], unsynced: [{ s: text }]
    property var lines: []
    property string message: ""
    property string key: ""

    property string _pendingKey: ""
    property var _pending: null

    function lineAt(position) {
        // Index of the last line that started at or before `position`
        // (-1 before the first line); binary search, called a few times a second.
        const l = root.lines;
        if (!root.synced || l.length === 0)
            return -1;
        let lo = 0, hi = l.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (l[mid].t <= position) {
                ans = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return ans;
    }

    function request(artist, title, album, duration, force) {
        const k = [artist, title, album, Math.round(duration)].join("|");
        if (!title) {
            root.reset("");
            return;
        }
        if (!force && k === root.key && root.status !== "error")
            return;
        root.key = k;
        root.status = "loading";
        root.lines = [];
        root.synced = false;
        root.message = "";
        const args = [artist, title, album, String(Math.round(duration))];
        if (force)
            args.push("--refresh");
        // One process at a time; a newer request replaces the queued one and
        // runs when the current lookup ends.
        root._pending = { key: k, args: args };
        if (!proc.running)
            root.startPending();
    }

    function startPending() {
        if (!root._pending)
            return;
        root._pendingKey = root._pending.key;
        proc.command = ["python3", "-I", Quickshell.shellPath("scripts/lyrics.py")].concat(root._pending.args);
        root._pending = null;
        proc.running = true;
    }

    function reset(k) {
        root.key = k;
        root.status = "idle";
        root.lines = [];
        root.synced = false;
        root.message = "";
        root._pending = null;
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                // Ignore the answer when another track was requested meanwhile.
                if (root._pendingKey === root.key) {
                    try {
                        const d = JSON.parse(this.text);
                        root.status = d.status;
                        root.synced = d.synced === true;
                        root.lines = d.lines ?? [];
                        root.message = d.message ?? "";
                    } catch (e) {
                        root.status = "error";
                        root.message = "Unreadable answer from the lyrics script";
                    }
                }
                root.startPending();
            }
        }
    }
}
