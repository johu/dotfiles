import QtQuick
import QtQuick.Layouts
import Quickshell

// Hover tooltip for the cava pill (Media.qml): cover art, title/artist and
// a read-only progress bar. A glance, not a control surface (that's
// MediaExpandCard).
PopupWindow {
    id: root

    property var player: null
    property string displayTitle: ""
    property string displayArtist: ""

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width / 2, 0);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x - card.implicitWidth / 2;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + String(s).padStart(2, "0");
    }

    function formatRemaining(position, length) {
        return "-" + root.formatDuration(Math.max(0, length - position));
    }

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"

    implicitWidth: card.implicitWidth + 2
    implicitHeight: card.implicitHeight + 2

    // Position doesn't tick between MPRIS events; poll while open and playing
    // (as MediaExpandCard).
    Timer {
        running: root.visible && !!root.player && root.player.isPlaying
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.surface1
        implicitWidth: layout.implicitWidth + 28
        implicitHeight: layout.implicitHeight + 24

        ColumnLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 10

            CoverArt {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 180
                implicitHeight: 180
                artUrl: root.player ? root.player.trackArtUrl : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.preferredWidth: 180
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.displayTitle || "Nothing playing"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-1)
                    renderType: Text.NativeRendering
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.preferredWidth: 180
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    text: root.displayArtist
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-3)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.preferredWidth: 180
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.formatDuration(root.player ? root.player.position : 0)
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-4)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    id: seekTrack
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    height: 4
                    radius: 2
                    color: Theme.surface2

                    readonly property real ratio: (root.player && root.player.length > 0) ? Math.min(1, root.player.position / root.player.length) : 0

                    Rectangle {
                        width: parent.width * seekTrack.ratio
                        height: parent.height
                        radius: parent.radius
                        color: Theme.blue
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.formatRemaining(root.player ? root.player.position : 0, root.player ? root.player.length : 0)
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-4)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
