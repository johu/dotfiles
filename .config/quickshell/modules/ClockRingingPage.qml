import QtQuick
import "ClockParse.js" as P

// Ringing screen: shown instead of any page while a timer or an alarm rings. Enter dismisses; a timer
// can get one more minute (+) or restart (r), an alarm can snooze (s). Do Not Disturb never mutes this.
Item {
    id: page

    property var view

    readonly property var r: ClockService.ringing.length > 0 ? ClockService.ringing[0] : null
    readonly property bool isTimer: r !== null && r.kind === "timer"
    readonly property var timer: isTimer ? ClockService.timerById(r.id) : null
    readonly property color c: isTimer ? (timer ? ClockService.timerColor(timer) : Theme.teal) : Theme.mauve
    readonly property string note: ClockService.ringing.length > 1 ? "1 of " + ClockService.ringing.length + " ringing" : ""

    readonly property var hints: page.isTimer ? [[
                { keys: ["↵"], text: "dismiss", slot: "dismiss" },
                { keys: ["+"], text: "add 1 min" },
                { keys: ["r"], text: "restart" },
                { keys: ["q"], text: "close" }
            ]] : [[
                { keys: ["↵"], text: "dismiss", slot: "dismiss" },
                { keys: ["s"], text: "snooze 5 min" },
                { keys: ["q"], text: "close" }
            ]]

    function handleKey(event) {
        if (!page.r)
            return false;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            ClockService.dismiss(page.r.key);
            return true;
        case Qt.Key_Plus:
        case Qt.Key_Equal:
            if (page.isTimer)
                ClockService.addMinute(page.r.id);
            return true;
        case Qt.Key_R:
            if (page.isTimer) {
                const id = page.r.id;
                ClockService.resetTimer(id);
                ClockService.toggleTimer(id);
            }
            return true;
        case Qt.Key_S:
            if (!page.isTimer)
                ClockService.snoozeRing(page.r.key);
            return true;
        }
        return false;
    }

    function mmss(s) {
        return Math.floor(s / 60) + ":" + P.pad(s % 60);
    }

    // seconds since the ring started, updated by the service tick
    readonly property int ringSeconds: page.r ? Math.max(0, Math.floor((ClockService.nowMs - page.r.since) / 1000)) : 0

    Rectangle {
        id: box

        anchors.centerIn: parent
        width: Math.min(parent.width - 200, 860)
        height: 450
        radius: 24
        color: Theme.base
        border.width: 3
        border.color: page.c

        ClockRing {
            id: ring

            x: (parent.width - width) / 2
            y: 36
            width: 150
            height: 150
            lineWidth: 8
            color: page.c
            frac: 1
            track: page.c

            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite

                NumberAnimation {
                    from: 1
                    to: 0.35
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.35
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }

        GText {
            x: ring.x
            y: ring.y
            width: ring.width
            height: ring.height
            horizontalAlignment: Text.AlignHCenter
            text: page.isTimer ? "\uf253" : "\uf0f3"
            color: page.c
            size: page.isTimer ? 68 : 56
        }

        GText {
            x: 30
            y: 206
            width: parent.width - 60
            height: 56
            horizontalAlignment: Text.AlignHCenter
            text: page.r ? page.r.name : ""
            size: 42
            strong: true
        }

        GText {
            x: 30
            y: 268
            width: parent.width - 60
            height: 34
            horizontalAlignment: Text.AlignHCenter
            text: page.r ? page.r.sub : ""
            color: Theme.subtext1
            size: Theme.fontSize + 6
        }

        GText {
            x: 30
            y: 330
            width: parent.width - 60
            height: 30
            horizontalAlignment: Text.AlignHCenter
            // timer: how long it has been waiting; alarm: how long until it counts as missed (5 min cap)
            text: page.isTimer ? page.mmss(page.ringSeconds) + " ago" : "missed in " + page.mmss(Math.max(0, 300 - page.ringSeconds))
            color: page.c
            size: Theme.fontSize + 3
        }
    }
}
