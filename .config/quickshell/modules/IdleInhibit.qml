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
    // exists solely to give IdleInhibitor something to attach to. A truly
    // 0x0 layer surface apparently never actually gets mapped/committed at
    // all (confirmed: Hyprland's log had zero "inhibit" lines, meaning the
    // protocol object was never even registered, not just rejected) - 1x1
    // is small enough to stay invisible while still being a real surface.
    PanelWindow {
        id: inhibitSurface
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.active = !root.active
    }
}
