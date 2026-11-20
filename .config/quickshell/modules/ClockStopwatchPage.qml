import QtQuick
import Quickshell
import "ClockParse.js" as P

// Stopwatch page: a work timer, no laps. Space starts / pauses, r saves the session and resets, a name
// says what is being timed, sessions are listed with today / week totals. Keeps running while the view
// is closed (ClockService).
Item {
    id: page

    property var view
    property int idx: 0
    property bool typing: false
    // fast tick (hundredths) only while the page is open and the stopwatch runs
    property double t: Date.now()

    readonly property var sessions: ClockService.sessions
    readonly property var cur: page.idx >= 0 && page.idx < page.sessions.length ? page.sessions[page.idx] : null
    readonly property double elapsed: ClockService.swElapsedAt(page.t)
    readonly property string full: P.stopwatch(page.elapsed)
    readonly property string main: page.full.slice(0, page.full.lastIndexOf("."))
    readonly property string hundredths: page.full.slice(page.full.lastIndexOf("."))
    readonly property string note: ClockService.swRunning ? "running" : (ClockService.swAccumMs > 0 ? "paused" : "")

    readonly property var hints: page.typing ? [[
            { keys: ["↵"], text: "save name" },
            { keys: ["Ctrl", "U"], text: "clear" },
            { keys: ["Esc"], text: "cancel" }
        ]] : [[
            { keys: ["Space"], text: ClockService.swRunning ? "pause" : "start", slot: "pause" },
            { keys: ["r"], text: "save & reset", ghost: page.elapsed < 3000 },
            { keys: ["e"], text: "name" },
            { keys: ["j", "k"], text: "session", ghost: page.sessions.length === 0 },
            { keys: ["y"], text: "copy session", ghost: !page.cur },
            { keys: ["d"], text: "delete session", ghost: !page.cur },
            { keys: ["Esc"], text: "back" }
        ]]

    Timer {
        interval: 40
        running: ClockService.swRunning
        repeat: true
        onTriggered: page.t = Date.now()
    }

    function startOfDay(d) {
        const x = new Date(d);
        x.setHours(0, 0, 0, 0);
        return x.getTime();
    }

    readonly property double today0: page.startOfDay(ClockService.nowMs)
    readonly property double week0: page.today0 - ((new Date(ClockService.nowMs).getDay() + 6) % 7) * 86400000
    readonly property double todayMs: page.sessions.filter(s => s.endMs >= page.today0).reduce((a, s) => a + s.durationMs, 0)
    readonly property double weekMs: page.sessions.filter(s => s.endMs >= page.week0).reduce((a, s) => a + s.durationMs, 0)

    function dayText(ms) {
        const d = new Date(ms);
        const diff = Math.round((page.startOfDay(ClockService.nowMs) - page.startOfDay(d)) / 86400000);
        return (diff === 0 ? "today" : (diff === 1 ? "yesterday" : Qt.formatDateTime(d, "ddd d.M."))) + " " + Qt.formatDateTime(d, "HH:mm");
    }

    function lineOf(s) {
        return (s.name !== "" ? s.name : "Session") + ": " + P.durationText(s.durationMs) + " (" + Qt.formatDateTime(new Date(s.startMs), "HH:mm") + " - " + Qt.formatDateTime(new Date(s.endMs), "HH:mm") + ")";
    }

    function handleEscape() {
        if (page.typing) {
            page.typing = false;
            return true;
        }
        return false;
    }

    function handleKey(event) {
        if (page.typing) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                ClockService.swSetName(input.text.trim());
                page.typing = false;
            } else {
                input.handle(event);
            }
            return true;
        }
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            ClockService.swToggle();
            return true;
        case Qt.Key_R:
            ClockService.swFinish();
            return true;
        case Qt.Key_E:
            input.text = ClockService.swName;
            page.typing = true;
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            page.idx = Math.min(page.sessions.length - 1, page.idx + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.idx = Math.max(0, page.idx - 1);
            return true;
        case Qt.Key_Y:
            if (page.cur)
                Quickshell.execDetached(["wl-copy", page.lineOf(page.cur)]);
            return true;
        case Qt.Key_D:
            if (page.cur) {
                ClockService.removeSession(page.idx);
                page.idx = Math.max(0, Math.min(page.idx, ClockService.sessions.length - 1));
            }
            return true;
        }
        return false;
    }

    // big time
    Row {
        x: (parent.width - width) / 2
        y: 20
        spacing: 6

        GText {
            id: bigText

            width: implicitWidth
            height: 150
            text: page.main
            size: 124
            strong: true
            color: ClockService.swRunning ? Theme.text : view.dim
        }

        GText {
            y: 12
            width: implicitWidth
            height: 150
            verticalAlignment: Text.AlignTop
            text: page.hundredths
            size: 44
            color: view.dim
        }
    }

    GText {
        x: 0
        y: 176
        width: parent.width
        height: 32
        horizontalAlignment: Text.AlignHCenter
        text: ClockService.swRunning ? "running" : (ClockService.swAccumMs > 0 ? "paused" : "idle")
        color: ClockService.swRunning ? Theme.blue : view.dim
        size: Theme.fontSize + 4
    }

    ClockInput {
        id: input

        x: Math.round(parent.width * 0.22)
        y: 226
        width: Math.round(parent.width * 0.56)
        label: "Timing:"
        active: page.typing
        idleText: ClockService.swName
        placeholder: "press e to name it"
    }

    // sessions
    GText {
        x: 0
        y: 316
        width: 400
        height: 34
        text: "Recent sessions"
        color: Theme.blue
        strong: true
        size: Theme.fontSize + 3
    }

    Rectangle {
        x: 0
        y: 352
        width: parent.width
        height: 1
        color: Theme.surface2
    }

    ListView {
        id: sessionList

        x: 0
        y: 362
        width: parent.width
        height: parent.height - 362 - 60
        clip: true
        spacing: 4
        model: page.sessions
        currentIndex: page.idx
        onCurrentIndexChanged: if (page.idx >= 0)
            positionViewAtIndex(page.idx, ListView.Contain)

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            width: sessionList.width
            height: 44

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: row.index === page.idx ? Theme.surface2 : "transparent"
            }

            GText {
                x: 24
                width: parent.width * 0.4
                height: parent.height
                text: row.modelData.name !== "" ? row.modelData.name : "Session"
                strong: row.index === page.idx
                size: Theme.fontSize + 3
            }

            GText {
                x: parent.width * 0.45
                width: parent.width * 0.3
                height: parent.height
                text: page.dayText(row.modelData.startMs) + " – " + Qt.formatDateTime(new Date(row.modelData.endMs), "HH:mm")
                color: view.dim
                size: Theme.fontSize + 2
            }

            GText {
                x: parent.width - 220
                width: 200
                height: parent.height
                horizontalAlignment: Text.AlignRight
                text: P.durationText(row.modelData.durationMs)
                size: Theme.fontSize + 3
            }
        }
    }

    GText {
        visible: page.sessions.length === 0
        x: 0
        y: 380
        width: parent.width
        height: 30
        text: "No saved sessions yet: r saves what you timed"
        color: view.dim
        size: Theme.fontSize + 2
    }

    GText {
        x: 0
        y: parent.height - 44
        width: parent.width
        height: 30
        text: "Today " + P.durationText(page.todayMs) + "  ·  this week " + P.durationText(page.weekMs)
        color: Theme.subtext1
        size: Theme.fontSize + 3
    }
}
