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
        // waybar's #system margin is asymmetric (7px top/3px bottom, not
        // centered); padding is bumped past waybar's raw 10px since our
        // glyphs sit closer to this pill's stadium-radius end caps.
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.rightMargin: 15
        height: 32
        horizontalPadding: 14
        spacing: 14

        Tray {}
        Privacy {}
        NetworkIndicator {}
        Battery {}
        Volume {}
        Clipboard {}
        Notifications {}
        Logout {}
    }
}
