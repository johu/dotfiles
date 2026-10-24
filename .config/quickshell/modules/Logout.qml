import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Text {
    id: root

    text: "\uf011"
    color: Theme.lavender
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter
    Layout.preferredHeight: Theme.moduleHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: launcher.running = true
    }

    Process {
        id: launcher
        command: ["wlogout"]
    }
}
