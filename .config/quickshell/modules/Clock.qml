import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var now: new Date()
    // pulse 0..1 while a timer or alarm rings; the bar pill (Bar.qml) uses it for its border and fill
    property real pulse: 0
    readonly property var cp: ClockService.pill
    readonly property bool active: cp.mode !== "none"
    readonly property string timeIcon: cp.mode === "timer" ? "\uf017" : "\uf0f3"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    SequentialAnimation on pulse {
        running: root.cp.mode === "ringing"
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            from: 0
            to: 1
            duration: 600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 1
            to: 0
            duration: 600
            easing.type: Easing.InOutSine
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.moduleHeight
    // Match the Pill's full height so the calendar popup, anchored to the
    // bottom edge, clears the pill.
    Layout.preferredHeight: Theme.moduleHeight

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // countdown / next alarm / ringing name, with the divider that separates it from the date
        Row {
            id: extra

            visible: root.active
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeIcon
                color: root.cp.color
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                renderType: Text.NativeRendering
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.cp.text
                color: root.cp.color
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                renderType: Text.NativeRendering
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: Theme.crust
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(root.now, "ddd, d.MMM HH:mm")
            color: Theme.pink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
            font.bold: true
        }
    }

    // the date opens the calendar, the countdown / alarm part opens the Clock view
    MouseArea {
        x: extra.visible ? extra.width + row.spacing : 0
        width: parent.width - x
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggle("calendar")
    }

    MouseArea {
        visible: root.active
        width: extra.width
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: ClockService.requestOpen()
    }

    PopupBehavior {
        name: "calendar"
        popup: calendarPopup
        openFn: () => calendarPopup.open(root)
    }

    Calendar {
        id: calendarPopup
    }
}
