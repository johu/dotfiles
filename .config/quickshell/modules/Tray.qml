import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 8

    // Tray items that must keep running but should not get a bar icon
    // (matched on the StatusNotifierItem Id).
    readonly property var hiddenIds: ["Xwayland Video Bridge"]
    readonly property var shownItems: SystemTray.items.values.filter(i => hiddenIds.indexOf(i.id) < 0)

    // An empty RowLayout still adds spacing as a layout child of the pill, a
    // phantom gap with no tray icons; hide it.
    visible: shownItems.length > 0

    TrayMenu {
        id: trayMenu
    }

    Repeater {
        model: shownItems

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
