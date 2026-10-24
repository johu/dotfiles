import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root

    property int percent: 0
    property string status: "Unknown"

    function open(anchorItem) {
        const win = anchorItem.QsWindow;
        const pos = win.mapFromItem(anchorItem, anchorItem.width / 2, anchorItem.height);
        anchor.window = win.window;
        anchor.rect.x = pos.x - implicitWidth / 2;
        anchor.rect.y = Theme.barHeight + 8;
        visible = true;
    }

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"
    implicitWidth: 170
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: root.status === "Charging" ? "\uf0e7" : "\uf240"
                color: root.status === "Charging" ? Theme.green : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Theme.surface2

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 3
                        width: parent.width * (root.percent / 100)
                        color: root.percent <= 20 ? Theme.yellow : Theme.green
                    }
                }

                Text {
                    text: root.status
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            Text {
                text: root.percent + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
