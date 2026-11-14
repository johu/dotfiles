import QtQuick
import QtQuick.Layouts

Text {
    id: root

    property var now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    text: Qt.formatDateTime(now, "ddd, d.MMM HH:mm")
    color: Theme.pink
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    renderType: Text.NativeRendering
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    // Match the Pill's full height so the calendar popup, anchored to the
    // bottom edge, clears the pill.
    Layout.preferredHeight: Theme.moduleHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggle("calendar")
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
