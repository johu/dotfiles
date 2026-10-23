import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root

    property real volume: 0
    property bool muted: false

    function show(anchorItem, newVolume, newMuted) {
        volume = newVolume;
        muted = newMuted;
        const win = anchorItem.QsWindow;
        const pos = win.mapFromItem(anchorItem, anchorItem.width / 2, anchorItem.height);
        anchor.window = win.window;
        anchor.rect.x = pos.x - implicitWidth / 2;
        anchor.rect.y = Theme.barHeight + 8;
        visible = true;
        hideTimer.restart();
    }

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"
    implicitWidth: 170
    implicitHeight: 48

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: {
                    if (root.muted)
                        return "\uf026";
                    if (root.volume > 0.66)
                        return "\uf028";
                    if (root.volume > 0.0)
                        return "\uf027";
                    return "\uf026";
                }
                color: Theme.maroon
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize
                font.bold: true
            }

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
                    width: parent.width * (root.muted ? 0 : root.volume)
                    color: Theme.maroon
                }
            }

            Text {
                text: Math.round(root.volume * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
