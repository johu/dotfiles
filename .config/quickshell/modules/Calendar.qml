import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

PopupWindow {
    id: root

    property int monthOffset: 0
    property var selectedDate: new Date()

    // anchor.item's edges/gravity/margins auto-positioning doesn't land
    // correctly here, and a declarative mapFromItem binding errors at
    // startup (item has no window yet). Compute the popup's exact
    // top-left corner imperatively in open() instead, once the item is
    // actually on screen — same pattern as the tray menu's position fix.
    anchor.adjustment: PopupAdjustment.Slide

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width / 2, 0);
        root.anchor.window = win.window;
        // Center on calendarCard's width, not the whole (fixed, wider-than-
        // needed-for-just-the-grid) window, so the grid stays put under the
        // clock regardless of whether the details panel is expanded.
        root.anchor.rect.x = pos.x - calendarCard.implicitWidth / 2;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.visible = true;
    }

    // grabFocus auto-dismisses the popup on Hyprland far too eagerly
    // (closes almost immediately after opening); toggle visibility via
    // the clock's own click handler instead.
    grabFocus: false
    color: "transparent"

    // Fixed, generous size independent of the cards' actual content size.
    // Driving the window's real implicit size from the details panel's
    // animation made Hyprland's xdg-popup live-resize/reposition visibly
    // shake (compositor support for reactive repositioning is incomplete).
    // Keeping the window static and animating the cards inside it avoids
    // that entirely.
    implicitWidth: 480
    implicitHeight: 300

    readonly property var shownDate: {
        const now = new Date();
        return new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
    }

    onVisibleChanged: {
        if (!visible) {
            monthOffset = 0;
            selectedDate = new Date();
        }
    }

    Rectangle {
        id: calendarCard
        anchors.top: parent.top
        anchors.left: parent.left
        implicitWidth: calendarLayout.implicitWidth + 24
        implicitHeight: calendarLayout.implicitHeight + 24
        radius: Theme.radius
        color: Theme.surface1

        ColumnLayout {
            id: calendarLayout
            anchors.centerIn: parent
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Item {
                    implicitWidth: 24
                    implicitHeight: 24

                    Text {
                        anchors.centerIn: parent
                        text: "\uf104"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconFontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset -= 1
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    // MonthGrid.title ignores its own `locale` property and
                    // always formats using the system locale, so build the
                    // title ourselves instead to stay in English.
                    text: grid.locale.standaloneMonthName(grid.month, Locale.LongFormat) + " " + grid.year
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Item {
                    implicitWidth: 24
                    implicitHeight: 24

                    Text {
                        anchors.centerIn: parent
                        text: "\uf105"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconFontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset += 1
                    }
                }
            }

            DayOfWeekRow {
                id: daysRow
                Layout.fillWidth: true
                locale: Qt.locale("en_GB")

                delegate: Text {
                    required property var model

                    horizontalAlignment: Text.AlignHCenter
                    text: model.shortName
                    color: (model.day === 0 || model.day === 6) ? Theme.green : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
            }

            MonthGrid {
                id: grid
                month: root.shownDate.getMonth()
                year: root.shownDate.getFullYear()
                locale: Qt.locale("en_GB")
                Layout.fillWidth: true
                spacing: 2

                delegate: Rectangle {
                    id: dayCell
                    required property var model

                    readonly property bool selected: CalendarEvents.sameDay(dayCell.model.date, root.selectedDate)

                    implicitWidth: 32
                    implicitHeight: 32
                    radius: width / 2
                    color: model.today ? Theme.blue : "transparent"
                    border.color: selected && !model.today ? Theme.blue : "transparent"
                    border.width: 1
                    opacity: model.month === grid.month ? 1 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.model.day
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: {
                            if (dayCell.model.today)
                                return Theme.base;
                            const dow = dayCell.model.date.getDay();
                            return (dow === 0 || dow === 6) ? Theme.green : Theme.text;
                        }
                    }

                    Rectangle {
                        visible: CalendarEvents.hasEventsOn(dayCell.model.date)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 4
                        height: 4
                        radius: 2
                        color: dayCell.model.today ? Theme.base : Theme.yellow
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDate = dayCell.model.date
                    }
                }
            }
        }
    }

    Item {
        id: detailsWrapper
        anchors.top: parent.top
        anchors.left: calendarCard.right

        readonly property var dayEvents: CalendarEvents.eventsOn(root.selectedDate)

        implicitWidth: detailsCard.implicitWidth + 8
        implicitHeight: calendarCard.implicitHeight

        Rectangle {
            id: detailsCard
            anchors.top: parent.top
            anchors.right: parent.right
            implicitWidth: 200
            implicitHeight: calendarCard.implicitHeight
            radius: Theme.radius
            color: Theme.surface1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Pinned above the selected-date section so it stays visible
                // regardless of which day is picked - weather doesn't belong
                // to a specific day the way the event list does.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Image {
                        source: "file://" + WeatherData.imageForCode(WeatherData.currentCode, WeatherData.currentIsDay)
                        width: 18
                        height: 18
                        sourceSize.width: 18
                        sourceSize.height: 18
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        Layout.fillWidth: true
                        text: WeatherData.loaded ? (WeatherData.currentTemp + "\u00b0C, " + WeatherData.descriptionForCode(WeatherData.currentCode)) : "Loading\u2026"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surface2
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.locale("en_GB").toString(root.selectedDate, "dddd, d MMMM")
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Repeater {
                    model: detailsWrapper.dayEvents

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.yellow
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (modelData.dtstart.hhmm ? modelData.dtstart.hhmm + "  " : "") + modelData.summary
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    visible: detailsWrapper.dayEvents.length === 0
                    Layout.fillWidth: true
                    text: "No events"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.italic: true
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
