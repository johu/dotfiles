import QtQuick
import "ClockParse.js" as P

// Timers page: every timer with its own colour, a big countdown and its state. Typed input creates
// a timer (5m, 90s, 1h30, 25 = minutes, 25/5 = Pomodoro, a name after a space). Timers keep running
// while the view is closed (ClockService).
Item {
    id: page

    property var view
    property int idx: 0
    property bool typing: false
    property string mode: "new"      // "new" | "edit"
    property string error: ""

    readonly property var timers: ClockService.timers
    readonly property var cur: page.idx >= 0 && page.idx < page.timers.length ? page.timers[page.idx] : null
    readonly property int runningCount: page.timers.filter(t => t.state === "running").length
    readonly property string note: page.runningCount > 0 ? page.runningCount + " running" : ""
    readonly property var presets: [5, 10, 15, 25, 45, 60]

    readonly property var hints: page.typing ? [[
            { keys: ["↵"], text: page.mode === "new" ? "start" : "save" },
            { keys: ["Ctrl", "U"], text: "clear" },
            { keys: ["Esc"], text: "cancel" }
        ]] : [[
            { keys: ["j", "k"], text: "move" },
            { keys: ["Space"], text: "start / pause" },
            { keys: ["+"], text: "add 1 min", ghost: !page.cur },
            { keys: ["r"], text: "reset", ghost: !page.cur },
            { keys: ["n"], text: "new" },
            { keys: ["e"], text: "edit", ghost: !page.cur },
            { keys: ["d"], text: "delete", ghost: !page.cur },
            { keys: ["1-6"], text: "preset" },
            { keys: ["s"], text: "skip phase", ghost: !(page.cur && page.cur.pomo) },
            { keys: ["Esc"], text: "back" }
        ]]

    // the text that recreates a timer, for editing
    function inputOf(t) {
        if (t.pomo)
            return t.pomo.focus + "/" + t.pomo.brk + "/" + t.pomo.rounds + (t.name !== "" && t.name !== "Focus" ? " " + t.name : "");
        const total = Math.round(t.ms / 1000), h = Math.floor(total / 3600), m = Math.floor(total % 3600 / 60), s = total % 60;
        return (h ? h + "h" : "") + (m ? m + "m" : "") + (s ? s + "s" : "") + (t.name !== "" ? " " + t.name : "");
    }

    function startTyping(m) {
        page.mode = m;
        page.error = "";
        input.text = m === "edit" && page.cur ? page.inputOf(page.cur) : "";
        page.typing = true;
    }

    function submit() {
        const err = page.mode === "new" ? ClockService.addTimer(input.text) : ClockService.editTimer(page.cur.id, input.text);
        if (err !== "") {
            page.error = err;
            return;
        }
        page.typing = false;
        if (page.mode === "new")
            page.idx = ClockService.timers.length - 1;
    }

    function move(d) {
        if (page.timers.length > 0)
            page.idx = Math.max(0, Math.min(page.timers.length - 1, page.idx + d));
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
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                page.submit();
            else
                input.handle(event);
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.move(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.move(-1);
            return true;
        case Qt.Key_G:
            page.idx = (event.modifiers & Qt.ShiftModifier) ? Math.max(0, page.timers.length - 1) : 0;
            return true;
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (page.cur)
                ClockService.toggleTimer(page.cur.id);
            return true;
        case Qt.Key_Plus:
        case Qt.Key_Equal:
            if (page.cur)
                ClockService.addMinute(page.cur.id);
            return true;
        case Qt.Key_R:
            if (page.cur)
                ClockService.resetTimer(page.cur.id);
            return true;
        case Qt.Key_N:
            page.startTyping("new");
            return true;
        case Qt.Key_E:
            if (page.cur)
                page.startTyping("edit");
            return true;
        case Qt.Key_D:
            if (page.cur) {
                ClockService.removeTimer(page.cur.id);
                page.idx = Math.max(0, Math.min(page.idx, ClockService.timers.length - 1));
            }
            return true;
        case Qt.Key_S:
            if (page.cur && page.cur.pomo)
                ClockService.skipPhase(page.cur.id);
            return true;
        }
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
            ClockService.addTimer(page.presets[event.key - Qt.Key_1] + "m");
            page.idx = ClockService.timers.length - 1;
            return true;
        }
        return false;
    }

    Component.onCompleted: {
        if (page.view.pending === "newTimer") {
            page.view.pending = "";
            page.startTyping("new");
        }
    }

    function subText(t) {
        if (t.pomo)
            return t.pomo.focus + " min focus / " + t.pomo.brk + " min break · round " + t.pomo.round + " of " + t.pomo.rounds;
        return P.durationText(t.ms) + (t.repeat ? " · repeats" : "");
    }

    function stateWord(t) {
        if (t.state === "running" && t.pomo)
            return t.pomo.phase === "focus" ? "focus" : (t.pomo.phase === "long" ? "long break" : "break");
        return t.state;
    }

    ListView {
        id: list

        x: 0
        y: 0
        width: parent.width
        height: parent.height - 220
        clip: true
        spacing: 6
        model: page.timers
        currentIndex: page.idx
        onCurrentIndexChanged: if (page.idx >= 0)
            positionViewAtIndex(page.idx, ListView.Contain)

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool sel: index === page.idx
            readonly property color c: ClockService.timerColor(modelData)
            readonly property real remain: ClockService.leftMs(modelData)
            readonly property bool live: modelData.state === "running" || modelData.state === "ringing"

            width: list.width
            height: 88

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: row.sel ? Theme.surface2 : "transparent"
            }

            ClockRing {
                x: 22
                y: 14
                width: 60
                height: 60
                lineWidth: 8
                color: row.c
                track: row.sel ? Theme.base : Theme.surface2
                frac: row.modelData.ms > 0 ? (row.modelData.state === "ready" ? 1 : row.remain / row.modelData.ms) : 0
            }

            // play: the glyph, nudged so its visual centre (not its box) sits in the ring's centre
            GentooIcon {
                x: 40
                y: 32
                size: 24
                visible: row.modelData.state === "ready"
                kind: "active"
                tint: row.c
                nudgeX: 2
                nudgeY: -1
            }

            // pause: two drawn bars, exactly centred in the ring (ring centre = 52, 44)
            Row {
                x: 52 - 7
                y: 44 - 8
                spacing: 4
                visible: row.modelData.state === "paused"

                Repeater {
                    model: 2

                    Rectangle {
                        width: 5
                        height: 16
                        radius: 1.5
                        color: row.c
                    }
                }
            }

            GText {
                x: 104
                y: 8
                width: parent.width - 104 - 380
                height: 36
                text: row.modelData.name !== "" ? row.modelData.name : P.durationText(row.modelData.ms)
                size: Theme.fontSize + 7
                strong: true
                color: row.modelData.state === "ready" ? Theme.subtext1 : Theme.text
            }

            GText {
                x: 104
                y: 44
                width: parent.width - 104 - 380
                height: 30
                text: page.subText(row.modelData)
                color: view.dim
                size: Theme.fontSize + 2
            }

            // Pomodoro rounds: done = timer colour, current = text colour, upcoming = dark
            Row {
                visible: !!row.modelData.pomo
                x: parent.width - 700
                y: 34
                spacing: 8

                Repeater {
                    model: row.modelData.pomo ? row.modelData.pomo.rounds : 0

                    Rectangle {
                        required property int index

                        width: 16
                        height: 16
                        radius: 8
                        color: index < row.modelData.pomo.round - 1 ? row.c : (index === row.modelData.pomo.round - 1 ? Theme.text : (row.sel ? Theme.base : Theme.surface2))
                    }
                }
            }

            GText {
                x: parent.width - 360
                width: 230
                height: parent.height
                horizontalAlignment: Text.AlignRight
                text: P.countdown(row.remain)
                size: 42
                strong: true
                color: row.live ? row.c : view.dim
            }

            GText {
                x: parent.width - 120
                width: 100
                height: parent.height
                horizontalAlignment: Text.AlignRight
                text: page.stateWord(row.modelData)
                color: row.live ? row.c : view.dim
                size: Theme.fontSize + 2
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.idx = row.index
                onDoubleClicked: {
                    page.idx = row.index;
                    ClockService.toggleTimer(row.modelData.id);
                }
            }
        }
    }

    GText {
        visible: page.timers.length === 0
        x: 0
        y: 60
        width: parent.width
        height: 40
        horizontalAlignment: Text.AlignHCenter
        text: "No timers yet"
        size: Theme.fontSize + 8
        strong: true
    }

    GText {
        visible: page.timers.length === 0
        x: 0
        y: 104
        width: parent.width
        height: 30
        horizontalAlignment: Text.AlignHCenter
        text: "Press n and type 5m, 90s, 1h30, 25 or 25/5, or press 1-6 for a preset"
        color: view.dim
        size: Theme.fontSize + 2
    }

    GText {
        visible: page.error !== ""
        x: 0
        y: parent.height - 214
        width: parent.width
        height: 26
        text: page.error
        color: Theme.red
    }

    ClockInput {
        id: input

        x: 0
        y: parent.height - 186
        width: parent.width
        label: page.mode === "edit" ? "Edit timer:" : "New timer:"
        active: page.typing
        placeholder: "press n"
        hint: "5m   90s   1h30   25   ·   25/5 = focus cycle   ·   a name after a space"
    }

    GText {
        x: 0
        y: parent.height - 116
        width: 200
        height: 26
        text: "PRESETS"
        color: view.dim
    }

    Row {
        x: 0
        y: parent.height - 84
        spacing: 10

        Repeater {
            model: page.presets

            Rectangle {
                required property int modelData
                required property int index

                width: presetText.implicitWidth + 32
                height: 40
                radius: 20
                color: Theme.base
                border.color: Theme.surface2

                GText {
                    id: presetText

                    anchors.centerIn: parent
                    width: implicitWidth
                    text: (parent.index + 1) + "  " + (modelData >= 60 ? modelData / 60 + " h" : modelData + " min")
                    size: Theme.fontSize + 1
                }
            }
        }
    }
}
