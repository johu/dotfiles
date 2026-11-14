import QtQuick
import QtQuick.Layouts

// Calendar view of the launcher: month grid (ISO weeks, Monday first) on
// the left, the selected day's agenda with full event details on the right.
// Contract with Launcher.qml: `hints` for the footer row, handleKey(event)
// for every key press while the view is open, closeRequested() to close the
// whole launcher (after opening a link).
Item {
    id: view

    // Set by the launcher: follows its zoom-dependent text rendering.
    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    // Day cell edge and week-number column width.
    readonly property int cell: 66
    readonly property int weekCol: 44

    readonly property var loc: Qt.locale("en_GB")
    readonly property var weekdays: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    property var today: view.startOfDay(new Date())
    property var selectedDate: view.today
    property int eventIndex: 0

    readonly property var dayEvents: CalendarEvents.eventsOn(view.selectedDate)
    readonly property var selectedEvent: view.dayEvents[view.eventIndex] ?? null
    readonly property string selectedLink: view.selectedEvent ? view.linkOf(view.selectedEvent) : ""

    // First day shown: the Monday on or before the 1st of the shown month.
    readonly property var gridStart: {
        const first = new Date(view.selectedDate.getFullYear(), view.selectedDate.getMonth(), 1);
        return new Date(first.getFullYear(), first.getMonth(), 1 - ((first.getDay() + 6) % 7));
    }

    readonly property var hints: [[
            { keys: ["h", "l"], text: "day" },
            { keys: ["j", "k"], text: "week" },
            { keys: ["Ctrl-u", "Ctrl-d"], text: "month" },
            { keys: ["t"], text: "today" },
            { keys: ["Ctrl-n", "Ctrl-p"], text: "event" }
        ].concat(view.selectedLink !== "" ? [{ keys: ["o"], text: "open link" }] : []).concat([{ keys: ["q"], text: "back" }])]

    onSelectedDateChanged: view.eventIndex = 0

    function startOfDay(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    function moveDays(n) {
        const d = view.selectedDate;
        view.selectedDate = new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
    }

    function moveMonths(n) {
        const d = view.selectedDate;
        const last = new Date(d.getFullYear(), d.getMonth() + n + 1, 0).getDate();
        view.selectedDate = new Date(d.getFullYear(), d.getMonth() + n, Math.min(d.getDate(), last));
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    function firstUrl(text) {
        const m = (text || "").match(/https?:\/\/[^\s<>"]+/);
        return m ? m[0] : "";
    }

    function linkOf(ev) {
        return ev.url || view.firstUrl(ev.description) || view.firstUrl(ev.location);
    }

    // "10:00 - 11:30", "10:00", or "All day" (with the last day for spans).
    function timeLabel(ev) {
        if (ev.dtstart.hhmm)
            return ev.dtstart.hhmm + (ev.endHhmm && ev.endHhmm !== ev.dtstart.hhmm ? " – " + ev.endHhmm : "");
        if (ev.dtend && ev.dtend.getTime() - ev.dtstart.date.getTime() > 86400000 * 1.5) {
            const last = new Date(ev.dtend.getFullYear(), ev.dtend.getMonth(), ev.dtend.getDate() - 1);
            return "All day, until " + view.loc.toString(last, "d MMM");
        }
        return "All day";
    }

    // Vim-style keys; arrows, PgUp/PgDn and Home work as aliases.
    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            view.moveDays(-1);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            view.moveDays(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.moveDays(-7);
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            view.moveDays(7);
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.moveMonths(-1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.moveMonths(1);
            return true;
        case Qt.Key_PageUp:
            view.moveMonths(-1);
            return true;
        case Qt.Key_PageDown:
            view.moveMonths(1);
            return true;
        case Qt.Key_N:
            if (ctrl)
                view.eventIndex = Math.min(view.eventIndex + 1, view.dayEvents.length - 1);
            return true;
        case Qt.Key_P:
            if (ctrl)
                view.eventIndex = Math.max(view.eventIndex - 1, 0);
            return true;
        case Qt.Key_Tab:
            view.eventIndex = Math.min(view.eventIndex + 1, view.dayEvents.length - 1);
            return true;
        case Qt.Key_Backtab:
            view.eventIndex = Math.max(view.eventIndex - 1, 0);
            return true;
        case Qt.Key_T:
        case Qt.Key_Home:
            view.selectedDate = view.today;
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        case Qt.Key_O:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (view.selectedLink !== "") {
                Apps.openUrl(view.selectedLink);
                view.closeRequested();
            }
            return true;
        }
        return false;
    }

    // Fixed geometry: every pane is positioned explicitly, so nothing shifts
    // with the month, the date text or the number of events.
    readonly property int leftWidth: view.weekCol + 7 * view.cell
    readonly property int gridTop: 100

    Item {
        id: left

        width: view.leftWidth
        height: parent.height

        Text {
            x: 0
            y: 0
            width: parent.width
            height: 52
            verticalAlignment: Text.AlignVCenter
            text: view.loc.toString(view.selectedDate, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 12
            font.bold: true
            renderType: view.textRender
        }

        Row {
            x: 0
            y: 60
            spacing: 0

            Item {
                width: view.weekCol
                height: 28
            }

            Repeater {
                model: view.weekdays

                Text {
                    required property string modelData
                    required property int index

                    width: view.cell
                    height: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Theme.green : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    renderType: view.textRender
                }
            }
        }

        Column {
            id: weeks

            x: 0
            y: view.gridTop
            Repeater {
                model: 6

                Row {
                    id: weekRow

                    required property int index
                    readonly property var rowStart: new Date(view.gridStart.getFullYear(), view.gridStart.getMonth(), view.gridStart.getDate() + weekRow.index * 7)

                    spacing: 0

                    Text {
                        width: view.weekCol
                        height: view.cell
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: view.isoWeek(new Date(weekRow.rowStart.getFullYear(), weekRow.rowStart.getMonth(), weekRow.rowStart.getDate() + 3))
                        color: Theme.subtext1
                        opacity: 0.6
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        renderType: view.textRender
                    }

                    Repeater {
                        model: 7

                        Rectangle {
                            id: cell

                            required property int index

                            readonly property var date: new Date(weekRow.rowStart.getFullYear(), weekRow.rowStart.getMonth(), weekRow.rowStart.getDate() + cell.index)
                            readonly property bool inMonth: cell.date.getMonth() === view.selectedDate.getMonth()
                            readonly property bool isToday: CalendarEvents.sameDay(cell.date, view.today)
                            readonly property bool isSelected: CalendarEvents.sameDay(cell.date, view.selectedDate)
                            readonly property int count: CalendarEvents.eventsOn(cell.date).length

                            width: view.cell
                            height: view.cell
                            radius: 14
                            color: cell.isSelected ? Theme.surface2 : "transparent"
                            border.width: cell.isToday ? 2 : 0
                            border.color: Theme.blue
                            opacity: cell.inMonth ? 1 : 0.35

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -4
                                text: cell.date.getDate()
                                color: cell.isToday ? Theme.blue : (cell.index >= 5 ? Theme.green : Theme.text)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 5
                                font.bold: cell.isToday || cell.isSelected
                                renderType: view.textRender
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 7
                                spacing: 3

                                Repeater {
                                    model: Math.min(cell.count, 3)

                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: Theme.yellow
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: view.selectedDate = cell.date
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        x: view.leftWidth + 20
        width: 1
        height: parent.height
        color: Theme.surface2
    }

    Item {
        id: right

        anchors.left: parent.left
        anchors.leftMargin: view.leftWidth + 40
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Text {
            x: 0
            y: 0
            width: parent.width
            height: 52
            verticalAlignment: Text.AlignVCenter
            text: view.loc.toString(view.selectedDate, "dddd, d MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 9
            font.bold: true
            elide: Text.ElideRight
            renderType: view.textRender
        }

        Text {
            x: 0
            y: 54
            width: parent.width
            height: 24
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: {
                if (!CalendarEvents.loaded)
                    return "Calendar not loaded yet (secrets.json icalUrls)";
                const n = view.dayEvents.length;
                const rel = CalendarEvents.sameDay(view.selectedDate, view.today) ? "Today · " : "";
                return rel + "Week " + view.isoWeek(view.selectedDate) + " · " + (n === 0 ? "no events" : (n === 1 ? "1 event" : n + " events"));
            }
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }

                ListView {
                    id: agenda

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 84
                    anchors.bottom: parent.bottom
                    clip: true
                    spacing: 8
                    model: view.dayEvents
                    currentIndex: view.eventIndex
                    onCurrentIndexChanged: agenda.positionViewAtIndex(agenda.currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: card

                        required property var modelData
                        required property int index

                        readonly property string link: view.linkOf(card.modelData)
                        readonly property string description: (card.modelData.description || "").replace(/https?:\/\/\S+/g, "").trim()

                        width: agenda.width
                        height: body.implicitHeight + 24
                        radius: 12
                        color: card.index === view.eventIndex ? Theme.surface2 : "transparent"
                        border.width: 1
                        border.color: card.index === view.eventIndex ? Theme.blue : Theme.surface2

                        ColumnLayout {
                            id: body

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: view.timeLabel(card.modelData)
                                color: Theme.yellow
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                renderType: view.textRender
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary || "(no title)"
                                wrapMode: Text.Wrap
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 5
                                font.bold: true
                                renderType: view.textRender
                            }

                            Text {
                                visible: !!card.modelData.location
                                Layout.fillWidth: true
                                text: "  " + (card.modelData.location || "")
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                renderType: view.textRender
                            }

                            Text {
                                visible: card.description !== ""
                                Layout.fillWidth: true
                                text: card.description
                                wrapMode: Text.Wrap
                                maximumLineCount: card.index === view.eventIndex ? 8 : 2
                                elide: Text.ElideRight
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                renderType: view.textRender
                            }

                            Text {
                                visible: card.link !== ""
                                Layout.fillWidth: true
                                text: "  " + card.link
                                elide: Text.ElideMiddle
                                color: Theme.blue
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                renderType: view.textRender
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: view.eventIndex = card.index
                        }
                    }
                }
    }
}
