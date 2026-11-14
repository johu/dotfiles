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
    renderType: Text.NativeRendering
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    IdleInhibitor {
        enabled: root.active
        window: inhibitSurface
    }

    // IdleInhibitor needs a real mapped surface. A 0x0 layer surface never maps
    // (Hyprland logged no "inhibit" lines), so use an invisible 1x1 panel.
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
