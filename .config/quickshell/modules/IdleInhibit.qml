import QtQuick
import Quickshell
import Quickshell.Wayland

Text {
    id: root

    property bool active: false

    text: "\uf0f4"
    color: root.active ? Theme.yellow : Theme.subtext1
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    IdleInhibitor {
        enabled: root.active
        window: inhibitSurface
    }

    // The idle-inhibit protocol requires a real mapped surface requesting
    // the inhibition, not just a D-Bus-style call — this invisible panel
    // exists solely to give IdleInhibitor something to attach to.
    PanelWindow {
        id: inhibitSurface
        implicitWidth: 0
        implicitHeight: 0
        color: "transparent"
        mask: Region {}
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.active = !root.active
    }
}
