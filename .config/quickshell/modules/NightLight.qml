import QtQuick
import Quickshell
import Quickshell.Io

Text {
    id: root

    // hyprsunset runs its own sunset/sunrise schedule from
    // hyprsunset.conf; this toggle is a manual override layered on top via
    // its control socket, not a replacement scheduler. Since the socket
    // has no state-readback, `active` is kept in sync with that schedule
    // by re-deriving it from the parsed profile times rather than trusting
    // stale click state once a scheduled transition has passed.
    property bool active: false
    property bool present: false
    property bool gameModeActive: false
    property string pendingCommand: ""
    property var profiles: []
    // Epoch-minute deadline of the next scheduled transition after the
    // last manual click; -1 means "no override in flight, follow schedule".
    property real overrideUntil: -1

    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.hyprsunset.sock"

    function sendCommand(cmd) {
        pendingCommand = cmd;
        sock.connected = true;
    }

    // `present` otherwise only updates as a side effect of a connection
    // attempt (startup or a click), and the socket is disconnected right
    // after each send rather than held open - so it never notices
    // hyprsunset going away or coming back on its own. Pinging the socket
    // with no pendingCommand (connect, let onConnectionStateChanged mark
    // `present` true and disconnect without writing anything) keeps
    // `present` live without re-sending gamma/temperature each poll.
    function checkPresence() {
        sock.connected = true;
    }

    function minutesOfDay(date) {
        return date.getHours() * 60 + date.getMinutes();
    }

    // Active state the schedule itself would currently be enforcing,
    // derived from the most recent profile time at or before `nowMinutes`
    // (wrapping to the last profile of the previous day before the first
    // profile of today has fired yet).
    function scheduleActiveAt(nowMinutes) {
        if (profiles.length === 0)
            return false;
        let current = profiles[profiles.length - 1];
        for (const p of profiles) {
            if (p.minutes <= nowMinutes)
                current = p;
        }
        return current.active;
    }

    function nextTransitionEpochAfter(nowDate) {
        if (profiles.length === 0)
            return -1;
        const nowMinutes = minutesOfDay(nowDate);
        let delta = -1;
        for (const p of profiles) {
            if (p.minutes > nowMinutes) {
                delta = p.minutes - nowMinutes;
                break;
            }
        }
        if (delta < 0)
            delta = profiles[0].minutes + 1440 - nowMinutes;
        return Math.floor(nowDate.getTime() / 60000) + delta;
    }

    function resync() {
        if (gameModeActive) {
            if (active) {
                active = false;
                sendCommand("identity");
            }
            return;
        }
        const now = new Date();
        const nowEpoch = Math.floor(now.getTime() / 60000);
        if (overrideUntil >= 0 && nowEpoch < overrideUntil)
            return;
        overrideUntil = -1;
        active = scheduleActiveAt(minutesOfDay(now));
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.resync()
    }

    // Game mode (SUPER + F2, see hypr/keybinds.lua) touches/removes this
    // file; night light must never run while it's gaming, so poll for it
    // rather than relying on any push notification hyprsunset can't give us.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: gameModeCheck.running = true
    }

    Process {
        id: gameModeCheck
        command: ["sh", "-c", "test -f ~/.cache/gamemode && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nowActive = this.text.trim() === "1";
                if (nowActive === root.gameModeActive)
                    return;
                root.gameModeActive = nowActive;
                root.resync();
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.checkPresence()
    }

    Socket {
        id: sock
        path: root.socketPath
        onConnectionStateChanged: {
            if (connected) {
                root.present = true;
                if (root.pendingCommand.length > 0) {
                    write(root.pendingCommand + "\n");
                    flush();
                    pendingCommand = "";
                }
                connected = false;
            }
        }
        onError: root.present = false
    }

    Process {
        id: confReader
        command: ["sh", "-c", "cat ~/.config/hypr/hyprsunset.conf 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = [];
                const blockRe = /profile\s*\{([^}]*)\}/g;
                let match;
                while ((match = blockRe.exec(this.text)) !== null) {
                    const block = match[1];
                    const timeMatch = block.match(/time\s*=\s*(\d+):(\d+)/);
                    if (!timeMatch)
                        continue;
                    parsed.push({
                        minutes: parseInt(timeMatch[1], 10) * 60 + parseInt(timeMatch[2], 10),
                        active: /temperature\s*=/.test(block)
                    });
                }
                parsed.sort((a, b) => a.minutes - b.minutes);
                root.profiles = parsed;
                root.resync();
            }
        }
    }

    Component.onCompleted: {
        sendCommand("gamma 100");
        confReader.running = true;
    }

    text: root.active ? "\uf186" : "\uf185"
    color: root.present ? (root.active ? Theme.yellow : Theme.subtext1) : Theme.crust
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.gameModeActive)
                return;
            root.active = !root.active;
            root.overrideUntil = root.nextTransitionEpochAfter(new Date());
            root.sendCommand(root.active ? "temperature 4500" : "identity");
        }
    }
}
