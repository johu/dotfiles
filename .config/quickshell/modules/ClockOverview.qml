import QtQuick
import "ClockParse.js" as P

// Overview page of the Clock view: Now, a day / night map with the world clock, and cards for
// Timers, Alarms and Stopwatch. hjkl select a card, Enter opens its page. Same flow as the Gentoo view.
Item {
    id: page

    property var view

    readonly property int gap: 22
    readonly property int topH: Math.round((height - gap) * 0.5)
    readonly property int nowW: Math.round(width * 0.31)
    readonly property int cardW: Math.floor((width - 2 * gap) / 3)
    readonly property var pageNames: ["world", "timers", "alarms", "stopwatch"]
    readonly property string note: ""

    readonly property var hints: [[
            { keys: ["h", "j", "k", "l"], text: "card" },
            { keys: ["↵"], text: "open" },
            { keys: ["n"], text: "new timer" },
            { keys: ["a"], text: "new alarm" },
            { keys: ["Space"], text: ClockService.swRunning ? "stop stopwatch" : "start stopwatch", slot: "start stopwatch" },
            { keys: ["q"], text: "close" }
        ]]

    // selectable cards: 0 World (top right), 1 Timers, 2 Alarms, 3 Stopwatch (bottom row)
    function move(dr, dc) {
        const s = view.sel;
        if (s === 0) {
            if (dr > 0)
                view.sel = 2;
            return;
        }
        if (dr < 0) {
            view.sel = 0;
            return;
        }
        view.sel = 1 + Math.max(0, Math.min(2, (s - 1) + dc));
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            page.move(0, -1);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            page.move(0, 1);
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            page.move(1, 0);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.move(-1, 0);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            view.openPage(page.pageNames[view.sel]);
            return true;
        case Qt.Key_N:
            view.pending = "newTimer";
            view.openPage("timers");
            return true;
        case Qt.Key_A:
            view.pending = "newAlarm";
            view.openPage("alarms");
            return true;
        case Qt.Key_Space:
            ClockService.swToggle();
            return true;
        }
        return false;
    }

    readonly property var now: new Date(ClockService.nowMs)
    readonly property var loc: ClockService.offsets[ClockService.zoneList[0]]
    readonly property string zoneLine: ClockService.zoneLabel(ClockService.zoneList[0]) + (loc ? " · " + loc.abbr + " (" + P.utcText(loc.off) + ")" : "") + " · week " + P.isoWeek(now)
    readonly property var na: ClockService.nextAlarmInfo
    readonly property var alarmsSorted: ClockService.alarms.filter(a => a.enabled).slice().sort((a, b) => a.nextMs - b.nextMs).slice(0, 3)
    readonly property int running: ClockService.timers.filter(t => t.state === "running").length
    readonly property int paused: ClockService.timers.filter(t => t.state === "paused").length

    // ================= Now =================
    GentooCard {
        x: 0
        y: 0
        width: page.nowW
        height: page.topH
        title: "Now"
        accent: Theme.pink

        GText {
            x: 24
            y: 52
            width: parent.width - 48
            height: 120
            text: Qt.formatDateTime(page.now, "HH:mm")
            size: 96
            strong: true
            color: Theme.text
        }

        GText {
            x: 24
            y: 176
            width: parent.width - 48
            height: 36
            text: Qt.formatDateTime(page.now, "dddd, d MMMM yyyy")
            size: Theme.fontSize + 6
            color: Theme.subtext1
        }

        GText {
            x: 24
            y: 214
            width: parent.width - 48
            height: 26
            text: page.zoneLine
            color: view.dim
        }

        Rectangle {
            x: 24
            y: 254
            width: parent.width - 48
            height: 1
            color: Theme.surface2
        }

        GText {
            x: 24
            y: 268
            width: 28
            height: 30
            text: "\uf0f3"
            color: page.na ? Theme.mauve : view.dim
            size: Theme.fontSize + 4
        }

        GText {
            x: 56
            y: 268
            width: parent.width - 80
            height: 30
            text: page.na ? page.na.alarm.time + "  " + (page.na.alarm.label !== "" ? page.na.alarm.label : "Alarm") : "No alarm set"
            strong: !!page.na
            size: Theme.fontSize + 3
        }

        GText {
            x: 56
            y: 298
            width: parent.width - 80
            height: 26
            text: page.na ? P.whenText(page.na.ms, ClockService.nowMs).replace(/ \d\d:\d\d$/, "") + ", in " + P.inText(page.na.ms - ClockService.nowMs) : ""
            color: view.dim
        }
    }

    // ================= World map =================
    GentooCard {
        x: page.nowW + page.gap
        y: 0
        width: page.width - page.nowW - page.gap
        height: page.topH
        title: "World"
        accent: Theme.blue
        selected: view.sel === 0

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 0
            onDoubleClicked: view.openPage("world")
        }

        readonly property int cols: 60
        readonly property int rows: 22
        readonly property real stepX: (width - 48) / cols
        readonly property real stepY: (height - 78) / rows

        Canvas {
            id: map

            x: 24
            y: 54
            width: parent.width - 48
            height: parent.height - 78
            // repainted once a minute: the terminator moves 0.25 degrees per minute
            property int minute: Math.floor(ClockService.nowMs / 60000)
            onMinuteChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const sx = width / 60, sy = height / 22;
                const colors = ["#2d3350", "#5f6896", "#8a93bd"];
                const r = Math.max(2, Math.min(sx, sy) * 0.34);
                for (let ci = 0; ci < 60; ci++) {
                    const lon = -180 + ci * 6;
                    for (let ri = 0; ri < 22; ri++) {
                        const lat = 72 - ri * 6;
                        ctx.fillStyle = colors[P.sunLevel(ClockService.nowMs, lon, lat)];
                        ctx.beginPath();
                        ctx.arc(ci * sx + sx / 2, ri * sy + sy / 2, r, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            }
        }

        Repeater {
            model: ClockService.zoneList

            Item {
                id: city

                required property string modelData
                required property int index

                readonly property var pos: P.ZONE_POS[modelData]
                readonly property var zi: ClockService.zoneInfo(modelData)
                readonly property real px: pos ? map.x + (pos[0] + 180) / 6 * (map.width / 60) + (map.width / 60) / 2 : 0
                readonly property real py: pos ? map.y + (72 - pos[1]) / 6 * (map.height / 22) + (map.height / 22) / 2 : 0

                visible: !!pos && zi.known
                x: px
                y: py

                Rectangle {
                    x: -6
                    y: -6
                    width: 12
                    height: 12
                    radius: 6
                    color: city.index === 0 ? Theme.yellow : Theme.text
                    border.width: 2
                    border.color: Theme.base
                }

                Rectangle {
                    readonly property bool labelLeft: !!city.pos && city.pos[0] > 100

                    x: labelLeft ? -width - 10 : 10
                    y: -12
                    width: label.implicitWidth + 12
                    height: 26
                    radius: 6
                    color: Theme.base

                    GText {
                        id: label

                        x: 6
                        width: implicitWidth
                        height: parent.height
                        text: ClockService.zoneLabel(city.modelData) + " " + city.zi.clock
                        color: city.index === 0 ? Theme.yellow : Theme.text
                        strong: city.index === 0
                    }
                }
            }
        }
    }

    // ================= bottom row =================
    GentooCard {
        x: 0
        y: page.topH + page.gap
        width: page.cardW
        height: page.height - page.topH - page.gap
        title: "Timers"
        accent: Theme.green
        selected: view.sel === 1

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 1
            onDoubleClicked: view.openPage("timers")
        }

        Repeater {
            model: ClockService.timers.slice(0, 3)

            Item {
                id: tr

                required property var modelData
                required property int index

                readonly property color c: ClockService.timerColor(modelData)
                readonly property real remain: ClockService.leftMs(modelData)

                x: 24
                y: 56 + index * 62
                width: parent.width - 48
                height: 56

                ClockRing {
                    width: 44
                    height: 44
                    y: 6
                    lineWidth: 6
                    color: tr.c
                    frac: tr.modelData.ms > 0 ? tr.remain / tr.modelData.ms : 0
                }

                // pause: two drawn bars, exactly centred in the 44 px ring (centre 22, 28)
                Row {
                    x: 22 - 6
                    y: 28 - 7
                    spacing: 4
                    visible: tr.modelData.state === "paused"

                    Repeater {
                        model: 2

                        Rectangle {
                            width: 4
                            height: 14
                            radius: 1.5
                            color: tr.c
                        }
                    }
                }

                GText {
                    x: 60
                    width: parent.width - 60 - 130
                    height: parent.height
                    text: tr.modelData.name !== "" ? tr.modelData.name : P.durationText(tr.modelData.ms) + " timer"
                    strong: true
                    size: Theme.fontSize + 4
                }

                GText {
                    x: parent.width - 130
                    width: 130
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    text: P.countdown(tr.remain)
                    color: tr.modelData.state === "running" || tr.modelData.state === "ringing" ? tr.c : view.dim
                    size: 30
                    strong: true
                }
            }
        }

        GText {
            visible: ClockService.timers.length === 0
            x: 24
            y: 70
            width: parent.width - 48
            height: 30
            text: "No timers"
            color: view.dim
            size: Theme.fontSize + 4
        }

        GText {
            x: 24
            y: parent.height - 44
            width: parent.width - 48
            height: 28
            text: ClockService.timers.length === 0 ? "" : page.running + " running" + (page.paused > 0 ? " · " + page.paused + " paused" : "")
            color: view.dim
        }
    }

    GentooCard {
        x: page.cardW + page.gap
        y: page.topH + page.gap
        width: page.cardW
        height: page.height - page.topH - page.gap
        title: "Alarms"
        accent: Theme.mauve
        selected: view.sel === 2

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 2
            onDoubleClicked: view.openPage("alarms")
        }

        Repeater {
            model: page.alarmsSorted

            Item {
                id: ar

                required property var modelData
                required property int index

                x: 24
                y: 56 + index * 62
                width: parent.width - 48
                height: 56

                GText {
                    width: 150
                    height: parent.height
                    text: ar.modelData.time
                    size: 32
                    strong: true
                }

                GText {
                    x: 160
                    y: 2
                    width: parent.width - 160 - 60
                    height: 28
                    text: ar.modelData.label !== "" ? ar.modelData.label : "Alarm"
                    strong: true
                    size: Theme.fontSize + 3
                    color: Theme.subtext1
                }

                GText {
                    x: 160
                    y: 28
                    width: parent.width - 160 - 60
                    height: 24
                    text: P.whenText(ar.modelData.snoozeMs > 0 ? ar.modelData.snoozeMs : ar.modelData.nextMs, ClockService.nowMs).replace(/ \d\d:\d\d$/, "")
                    color: view.dim
                }

                ClockSwitch {
                    x: parent.width - width
                    y: 16
                    on: true
                }
            }
        }

        GText {
            visible: page.alarmsSorted.length === 0
            x: 24
            y: 70
            width: parent.width - 48
            height: 30
            text: "No alarms set"
            color: view.dim
            size: Theme.fontSize + 4
        }

        GText {
            x: 24
            y: parent.height - 44
            width: parent.width - 48
            height: 28
            text: ClockService.alarms.length === 0 ? "" : ClockService.alarms.filter(a => a.enabled).length + " on"
            color: view.dim
        }
    }

    GentooCard {
        x: 2 * (page.cardW + page.gap)
        y: page.topH + page.gap
        width: page.width - x
        height: page.height - page.topH - page.gap
        title: "Stopwatch"
        accent: Theme.blue
        selected: view.sel === 3

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 3
            onDoubleClicked: view.openPage("stopwatch")
        }

        GText {
            x: 24
            y: 52
            width: parent.width - 48
            height: 70
            text: P.stopwatch(ClockService.swElapsed())
            size: 48
            strong: true
            color: ClockService.swRunning ? Theme.text : view.dim
        }

        GText {
            x: 24
            y: 126
            width: parent.width - 48
            height: 26
            text: ClockService.swRunning ? (ClockService.swName !== "" ? ClockService.swName : "running") : (ClockService.swAccumMs > 0 ? "paused" : "idle")
            color: ClockService.swRunning ? Theme.blue : view.dim
        }

        GText {
            visible: ClockService.sessions.length > 0
            x: 24
            y: 178
            width: parent.width - 48
            height: 26
            text: "Last sessions"
            color: view.dim
        }

        Repeater {
            model: ClockService.sessions.slice(0, 2)

            Item {
                required property var modelData
                required property int index

                x: 24
                y: 208 + index * 30
                width: parent.width - 48
                height: 28

                GText {
                    width: parent.width - 150
                    height: parent.height
                    text: modelData.name !== "" ? modelData.name : "Session"
                    color: Theme.subtext1
                    size: Theme.fontSize + 2
                }

                GText {
                    x: parent.width - 150
                    width: 150
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    text: P.durationText(modelData.durationMs)
                    size: Theme.fontSize + 2
                }
            }
        }
    }
}
