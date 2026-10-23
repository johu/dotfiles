import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 8

    Repeater {
        model: SystemTray.items.values

        delegate: Rectangle {
            id: trayIcon
            required property var modelData

            implicitWidth: 24
            implicitHeight: 24
            radius: Theme.radius
            color: mouse.pressed ? Theme.crust : (hover.hovered ? Theme.surface2 : "transparent")

            // Quickshell's built-in image://icon/ provider looks for icon
            // files flat in the theme path, ignoring the hicolor/<size>/status/
            // layout some apps actually use there. Resolve it ourselves.
            readonly property var themedIcon: trayIcon.modelData.icon.match(/^image:\/\/icon\/([^?]+)\?path=(.+)$/)
            property string resolvedIconPath: ""

            Process {
                running: trayIcon.themedIcon !== null
                command: trayIcon.themedIcon ? ["find", trayIcon.themedIcon[2], "-name", trayIcon.themedIcon[1] + ".*"] : []
                stdout: StdioCollector {
                    onStreamFinished: {
                        const match = this.text.split("\n").find(line => line.length > 0);
                        if (match)
                            trayIcon.resolvedIconPath = match;
                    }
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.iconFontSize
                source: trayIcon.resolvedIconPath ? "file://" + trayIcon.resolvedIconPath : trayIcon.modelData.icon
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
                        const pos = trayIcon.mapToItem(null, mouse.x, mouse.y);
                        trayIcon.modelData.display(QsWindow.window, pos.x, pos.y);
                    } else {
                        trayIcon.modelData.secondaryActivate();
                    }
                }
            }
        }
    }
}
