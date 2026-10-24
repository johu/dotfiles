import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: bar

    color: "transparent"
    implicitHeight: Theme.barHeight

    anchors {
        top: true
        left: true
        right: true
    }

    exclusiveZone: implicitHeight

    mask: Region {
        item: fullArea
    }

    Item {
        id: fullArea
        anchors.fill: parent
    }

    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 15
        spacing: 15

        Pill {
            // Matches waybar's #navigation group, where nested children
            // (custom-logo, #workspaces) each add their own padding on top
            // of #navigation's own "0px 10px" — giving an asymmetric
            // 20px/13px inset rather than a flat value on both sides.
            leftPadding: 11
            rightPadding: 9
            spacing: 10
            Logo {}
            Workspaces {}
        }

        Pill {
            visible: activeWindow.text.length > 0

            ActiveWindow {
                id: activeWindow
                Layout.maximumWidth: 400
            }
        }
    }

    Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        Clock {}
    }

    Pill {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 15
        spacing: 14

        Tray {}
        Privacy {}
        NetworkIndicator {}
        Volume {}
        Clipboard {}
        Logout {}
    }
}
