import QtQuick
import "ClockParse.js" as P

// World page: the local zone first, the others sorted by offset. Each row shows the time, the date,
// the offset to here and a 24 h strip of that zone's day (sun phase per hour: night / sunrise-sunset glow / day,
// current hour boxed).
// n adds a zone by typing a city or zone name (suggestions come from `timedatectl list-timezones`).
Item {
    id: page

    property var view
    // the selection follows the zone, not the row number: the list re-sorts when a new zone's offset arrives
    property string selId: ""
    property bool typing: false
    property int sug: 0
    property string error: ""

    readonly property var zones: ClockService.zoneList
    readonly property int idx: Math.max(0, page.zones.indexOf(page.selId))
    readonly property string cur: page.idx >= 0 && page.idx < page.zones.length ? page.zones[page.idx] : ""
    // next sunrise or sunset at the local position (the weather location when set, else the local zone's city)
    readonly property int localOff: ClockService.offsets[page.zones[0]]?.off ?? 0
    readonly property var localPos: (WeatherData.lat !== 0 || WeatherData.lon !== 0) ? [WeatherData.lon, WeatherData.lat] : P.zonePos(page.zones[0], page.localOff)
    readonly property int minuteKey: Math.floor(ClockService.nowMs / 60000)
    readonly property string note: {
        const k = page.minuteKey;
        const s = P.nextSun(k * 60000, page.localPos[0], page.localPos[1]);
        if (!s)
            return "";
        const d = new Date(s.ms + page.localOff * 60000);
        return (s.rising ? "sunrise " : "sunset ") + P.pad(d.getUTCHours()) + ":" + P.pad(d.getUTCMinutes()) + " \u00b7 in " + P.inText(s.ms - k * 60000);
    }

    readonly property var matches: {
        const q = input.text.trim().toLowerCase().replace(/ /g, "_");
        if (q === "")
            return [];
        // names that start with the query first, then shorter names (usually the better known city)
        const rank = z => (ClockService.zoneLabel(z).toLowerCase().replace(/ /g, "_").indexOf(q) === 0 ? 0 : 1000) + ClockService.zoneLabel(z).length;
        return ClockService.allZones.filter(z => z.toLowerCase().indexOf(q) >= 0 && z !== page.zones[0] && ClockService.zones.indexOf(z) < 0).sort((x, y) => rank(x) - rank(y) || x.localeCompare(y)).slice(0, 6);
    }

    readonly property var hints: page.typing ? [[
            { keys: ["↵"], text: "add zone" },
            { keys: ["↑", "↓"], text: "suggestion" },
            { keys: ["Ctrl", "U"], text: "clear" },
            { keys: ["Esc"], text: "cancel" }
        ]] : [[
            { keys: ["j", "k"], text: "move" },
            { keys: ["n"], text: "add zone" },
            { keys: ["d"], text: "remove", ghost: page.idx === 0 },
            { keys: ["Esc"], text: "back" }
        ]]

    function submit() {
        page.error = "";
        const typed = input.text.trim();
        const pick = page.matches.length > 0 ? page.matches[Math.min(page.sug, page.matches.length - 1)] : typed;
        const err = ClockService.addZone(pick);
        if (err !== "") {
            page.error = err;
            return;
        }
        page.typing = false;
        page.selId = pick;
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
            else if (event.key === Qt.Key_Down)
                page.sug = Math.min(page.matches.length - 1, page.sug + 1);
            else if (event.key === Qt.Key_Up)
                page.sug = Math.max(0, page.sug - 1);
            else if (input.handle(event))
                page.sug = 0;
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.selId = page.zones[Math.min(page.zones.length - 1, page.idx + 1)];
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.selId = page.zones[Math.max(0, page.idx - 1)];
            return true;
        case Qt.Key_N:
            ClockService.loadAllZones();
            input.text = "";
            page.error = "";
            page.sug = 0;
            page.typing = true;
            return true;
        case Qt.Key_D:
            if (page.idx > 0) {
                const keep = page.idx;
                ClockService.removeZone(page.cur);
                page.selId = ClockService.zoneList[Math.min(keep, ClockService.zoneList.length - 1)];
            }
            return true;
        }
        return false;
    }

    ListView {
        id: list

        x: 0
        y: 0
        width: parent.width
        height: parent.height - (page.typing ? 460 : 200)
        clip: true
        spacing: 6
        model: page.zones
        currentIndex: page.idx
        onCurrentIndexChanged: if (page.idx >= 0)
            positionViewAtIndex(page.idx, ListView.Contain)

        delegate: Item {
            id: row

            required property string modelData
            required property int index

            readonly property bool sel: index === page.idx
            readonly property var zi: ClockService.zoneInfo(modelData)

            width: list.width
            height: 72

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: row.sel ? Theme.surface2 : "transparent"
            }

            GText {
                x: 28
                y: 4
                width: 400
                height: 34
                text: ClockService.zoneLabel(row.modelData)
                size: Theme.fontSize + 6
                strong: true
                color: row.sel || row.index === 0 ? Theme.text : Theme.subtext1
            }

            GText {
                x: 28
                y: 38
                width: 400
                height: 28
                text: row.modelData.replace(/_/g, " ") + (row.index === 0 ? "  ·  you are here" : "")
                color: row.index === 0 ? Theme.yellow : view.dim
                size: Theme.fontSize + 1
            }

            GText {
                x: 440
                width: 150
                height: parent.height
                text: row.zi.clock
                size: 36
                strong: true
            }

            GText {
                x: 600
                width: 150
                height: parent.height
                text: row.zi.dateText
                color: Theme.subtext1
                size: Theme.fontSize + 2
            }

            GText {
                x: 760
                width: 230
                height: parent.height
                text: row.index === 0 ? "" : P.offsetText(row.zi.offHours) + (row.zi.dayDiff > 0 ? " · tomorrow" : (row.zi.dayDiff < 0 ? " · yesterday" : ""))
                color: row.zi.dayDiff !== 0 ? Theme.yellow : view.dim
                size: Theme.fontSize + 2
            }

            // the zone's 24 hours by the sun: night (indigo), sunrise / sunset glow (orange), day (yellow); the
            // current hour boxed. A fixed dark plate sits behind it so it looks the same on a selected row.
            Rectangle {
                x: parent.width - 560 - 8
                y: 8
                // blocks span 0 .. 23 * 22 + 18; 8 px of plate on every side (left, top and bottom are 8)
                width: 23 * 22 + 18 + 16
                height: parent.height - 16
                radius: 8
                color: Theme.base
            }

            Item {
                x: parent.width - 560
                y: 0
                width: 24 * 22
                height: parent.height

                Repeater {
                    model: 24

                    Rectangle {
                        required property int index

                        x: index * 22
                        y: 16
                        width: 18
                        height: 40
                        color: row.zi.strip[index] === 2 ? Theme.yellow : (row.zi.strip[index] === 1 ? Theme.maroon : Theme.surface2)
                    }
                }

                Rectangle {
                    x: row.zi.hh * 22 - 2
                    y: 10
                    width: 22
                    height: 52
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.text
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.selId = row.modelData
            }
        }
    }

    // zone suggestions while typing
    Column {
        visible: page.typing
        x: 0
        y: parent.height - 442
        width: parent.width
        spacing: 2

        Repeater {
            model: page.matches

            Rectangle {
                required property string modelData
                required property int index

                width: parent.width
                height: 40
                radius: 10
                color: index === page.sug ? Theme.surface2 : "transparent"

                GText {
                    x: 20
                    width: 360
                    height: parent.height
                    text: ClockService.zoneLabel(modelData)
                    strong: parent.index === page.sug
                }

                GText {
                    x: 400
                    width: parent.width - 420
                    height: parent.height
                    text: modelData + (ClockService.zoneInfo(modelData).known ? "  ·  " + ClockService.zoneInfo(modelData).clock : "")
                    color: view.dim
                }
            }
        }

        GText {
            visible: input.text.trim() !== "" && page.matches.length === 0
            x: 20
            height: 40
            text: ClockService.allZones.length === 0 ? "Loading zones…" : "No time zone matches"
            color: view.dim
        }
    }

    GText {
        visible: page.error !== ""
        x: 0
        y: parent.height - 184
        width: parent.width
        height: 26
        text: page.error
        color: Theme.red
    }

    ClockInput {
        id: input

        x: 0
        y: parent.height - 150
        width: parent.width
        label: "Zone:"
        active: page.typing
        placeholder: "press n and type a city or zone, e.g. tokyo"
        hint: page.typing ? "city or zone name" : ""
    }
}
