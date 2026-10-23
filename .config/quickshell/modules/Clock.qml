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
    color: Theme.green
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    // Match the Pill's full height, not just the text's own glyph height,
    // so the calendar popup (anchored to this item's bottom edge) clears
    // the whole pill instead of overlapping it.
    Layout.preferredHeight: Theme.moduleHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (calendarPopup.visible)
                calendarPopup.visible = false;
            else
                calendarPopup.open(root);
        }
    }

    Calendar {
        id: calendarPopup
    }
}
