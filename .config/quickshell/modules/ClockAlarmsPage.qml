import QtQuick
import "ClockParse.js" as P

// Alarms page: time, label, weekday chips, next ring and an on / off switch. n / e walk through three
// prompts (time, weekdays, label). Alarms ring while the view is closed (ClockService); snooze and
// dismiss happen on the ringing screen.
Item {
    id: page

    property var view
    property int idx: 0
    property bool typing: false
    property bool editing: false
    property int stage: 0            // 0 time, 1 weekdays, 2 label
    property string tmpTime: ""
    property string tmpDays: ""
    property string error: ""

    readonly property var list: ClockService.alarms.slice().sort((a, b) => a.time.localeCompare(b.time))
    readonly property var cur: page.idx >= 0 && page.idx < page.list.length ? page.list[page.idx] : null
    readonly property int onCount: page.list.filter(a => a.enabled).length
    readonly property string note: ClockService.nextAlarmInfo ? "next alarm in " + P.inText(ClockService.nextAlarmInfo.ms - ClockService.nowMs) : ""
    readonly property var dayNames: P.DAY_NAMES
    readonly property string soundName: ClockService.soundFile.split("/").pop().replace(/\.[a-z0-9]+$/, "")

    readonly property var prompts: [
        { label: "Time:", placeholder: "7:30", hint: "e.g. 7:30, 07.30 or 0730" },
        { label: "Days:", placeholder: "once", hint: "mon tue fri   ·   weekdays   ·   weekend   ·   daily   ·   empty = once" },
        { label: "Label:", placeholder: "optional", hint: "shown when it rings" }
    ]

    readonly property var hints: page.typing ? [[
            { keys: ["↵"], text: page.stage < 2 ? "next" : (page.editing ? "save" : "add alarm") },
            { keys: ["Ctrl", "U"], text: "clear" },
            { keys: ["Esc"], text: "cancel" }
        ]] : [[
            { keys: ["j", "k"], text: "move" },
            { keys: ["Space"], text: "on / off", ghost: !page.cur },
            { keys: ["n"], text: "new" },
            { keys: ["e"], text: "edit", ghost: !page.cur },
            { keys: ["d"], text: "delete", ghost: !page.cur },
            { keys: ["Esc"], text: "back" }
        ]]

    function daysInput(a) {
        return a.days.length === 7 ? "daily" : (a.days.length === 0 ? "" : P.daysText(a.days).toLowerCase());
    }

    function startTyping(edit) {
        page.editing = edit && page.cur !== null;
        page.stage = 0;
        page.error = "";
        page.tmpTime = "";
        page.tmpDays = "";
        input.text = page.editing ? page.cur.time : "";
        page.typing = true;
    }

    function submit() {
        page.error = "";
        if (page.stage === 0) {
            const t = P.parseClock(input.text);
            if (t === "") {
                page.error = "Not a time: try 7:30 or 0730";
                return;
            }
            page.tmpTime = t;
            page.stage = 1;
            input.text = page.editing ? page.daysInput(page.cur) : "";
        } else if (page.stage === 1) {
            if (P.parseDays(input.text) === null) {
                page.error = "Not weekdays: try mon tue, weekdays, weekend or daily";
                return;
            }
            page.tmpDays = input.text;
            page.stage = 2;
            input.text = page.editing ? page.cur.label : "";
        } else {
            const err = page.editing ? ClockService.editAlarm(page.cur.id, page.tmpTime, page.tmpDays, input.text) : ClockService.addAlarm(page.tmpTime, page.tmpDays, input.text, "");
            if (err !== "") {
                page.error = err;
                return;
            }
            page.typing = false;
        }
    }

    function move(d) {
        if (page.list.length > 0)
            page.idx = Math.max(0, Math.min(page.list.length - 1, page.idx + d));
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
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (page.cur)
                ClockService.toggleAlarm(page.cur.id);
            return true;
        case Qt.Key_N:
            page.startTyping(false);
            return true;
        case Qt.Key_E:
            if (page.cur)
                page.startTyping(true);
            return true;
        case Qt.Key_D:
            if (page.cur) {
                ClockService.removeAlarm(page.cur.id);
                page.idx = Math.max(0, Math.min(page.idx, ClockService.alarms.length - 1));
            }
            return true;
        }
        return false;
    }

    Component.onCompleted: {
        if (page.view.pending === "newAlarm") {
            page.view.pending = "";
            page.startTyping(false);
        }
    }

    function nextText(a) {
        if (a.snoozeMs > 0)
            return "snoozed until " + Qt.formatDateTime(new Date(a.snoozeMs), "HH:mm");
        if (!a.enabled)
            return "off";
        return P.whenText(a.nextMs, ClockService.nowMs);
    }

    ListView {
        id: listView

        x: 0
        y: 0
        width: parent.width
        height: parent.height - 190
        clip: true
        spacing: 6
        model: page.list
        currentIndex: page.idx
        onCurrentIndexChanged: if (page.idx >= 0)
            positionViewAtIndex(page.idx, ListView.Contain)

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool sel: index === page.idx
            readonly property bool on: modelData.enabled

            width: listView.width
            height: 96

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: row.sel ? Theme.surface2 : "transparent"
            }

            GText {
                x: 28
                width: 230
                height: parent.height
                text: row.modelData.time
                size: 46
                strong: true
                color: row.on ? Theme.text : (row.sel ? view.dim : GentooStyle.faint)
            }

            GText {
                x: 280
                y: 6
                width: parent.width - 280 - 360
                height: 36
                text: row.modelData.label !== "" ? row.modelData.label : "Alarm"
                size: Theme.fontSize + 7
                strong: true
                color: row.on ? Theme.text : (row.sel ? view.dim : GentooStyle.faint)
            }

            Row {
                x: 280
                y: 50
                spacing: 8
                opacity: row.on ? 1 : 0.5

                Repeater {
                    model: 7

                    Rectangle {
                        required property int index

                        readonly property bool act: row.modelData.days.indexOf(index + 1) >= 0

                        width: 56
                        height: 32
                        radius: 8
                        color: act ? (row.on ? Theme.blue : "transparent") : Theme.base
                        border.color: act && !row.on ? GentooStyle.faint : Theme.surface2

                        GText {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: page.dayNames[index]
                            color: parent.act ? (row.on ? Theme.base : Theme.text) : view.dim
                            size: Theme.fontSize + 1
                        }
                    }
                }

                GText {
                    visible: row.modelData.days.length === 0
                    width: 200
                    height: 32
                    text: row.modelData.date !== "" ? row.modelData.date + " (once)" : "once"
                    color: Theme.yellow
                    size: Theme.fontSize + 2
                }
            }

            GText {
                x: parent.width - 420
                width: 270
                height: parent.height
                horizontalAlignment: Text.AlignRight
                text: page.nextText(row.modelData)
                color: row.on ? Theme.subtext1 : GentooStyle.faint
                size: Theme.fontSize + 2
            }

            ClockSwitch {
                x: parent.width - 100
                y: 36
                on: row.on
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.idx = row.index
                onDoubleClicked: {
                    page.idx = row.index;
                    ClockService.toggleAlarm(row.modelData.id);
                }
            }
        }
    }

    GText {
        visible: page.list.length === 0
        x: 0
        y: 60
        width: parent.width
        height: 40
        horizontalAlignment: Text.AlignHCenter
        text: "No alarms yet"
        size: Theme.fontSize + 8
        strong: true
    }

    GText {
        visible: page.list.length === 0
        x: 0
        y: 104
        width: parent.width
        height: 30
        horizontalAlignment: Text.AlignHCenter
        text: "Press n to add one: time, weekdays, label"
        color: view.dim
        size: Theme.fontSize + 2
    }

    GText {
        x: 0
        y: parent.height - 184
        width: parent.width
        height: 26
        text: page.error !== "" ? page.error : "Sound: " + page.soundName + " (placeholder)   ·   snooze 5 min   ·   rings until dismissed (max 5 min)"
        color: page.error !== "" ? Theme.red : view.dim
    }

    ClockInput {
        id: input

        x: 0
        y: parent.height - 150
        width: parent.width
        label: page.typing ? page.prompts[page.stage].label : "Alarm:"
        active: page.typing
        placeholder: page.typing ? page.prompts[page.stage].placeholder : "press n to add an alarm"
        hint: page.typing ? page.prompts[page.stage].hint : ""
    }
}
