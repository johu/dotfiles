import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 8

    // An empty RowLayout is still a layout child of the bar Pill, so its
    // spacing would add a phantom gap on the left of the pill whenever no
    // app has registered a tray icon. Hidden layout children are skipped.
    visible: SystemTray.items.values.length > 0

    TrayMenu {
        id: trayMenu
    }

    Repeater {
        model: SystemTray.items.values

        delegate: Rectangle {
            id: trayIcon
            required property var modelData

            implicitWidth: 24
            implicitHeight: 24
            radius: Theme.radius
            color: mouse.pressed ? Theme.crust : (hover.hovered ? Theme.surface2 : "transparent")

            ResolvedIcon {
                anchors.centerIn: parent
                iconSource: trayIcon.modelData.icon
                size: Theme.iconFontSize
            }

            HoverHandler {
                id: hover
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayIcon.modelData.activate();
                    } else if (trayIcon.modelData.hasMenu) {
                        trayMenu.toggle(trayIcon, trayIcon.modelData.menu);
                    } else {
                        trayIcon.modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
