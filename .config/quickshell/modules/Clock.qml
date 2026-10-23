import QtQuick

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
}
