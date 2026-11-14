import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// Always-expanded dashboard media card (see docs/ideas/media-player-popup.md),
// rendered whenever a player is active (gated by the Loader in Dashboard).
// Layout mirrors MediaHoverPopup.qml; transport controls use custom SVGs
// (assets/icons/media-*.svg).
//
// Resolves its own player instead of embedding Media{}: a Media{} child in
// a ColumnLayout takes part in the layout, and it would spawn a second
// cava just to read text. Skips Media.qml's title guards; a one-frame blip
// is less jarring in a visible card.
ColumnLayout {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property int coverSize: 160

    spacing: 10

    function formatDuration(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + String(s).padStart(2, "0");
    }

    function formatRemaining(position, length) {
        return "-" + root.formatDuration(Math.max(0, length - position));
    }

    // Position only notifies on seeks/track changes, so poll it (as
    // MediaHoverPopup.qml).
    Timer {
        running: root.player !== null && root.player.isPlaying
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    CoverArt {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: root.coverSize
        implicitHeight: root.coverSize
        artUrl: root.player ? root.player.trackArtUrl : ""
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 2

        Text {
            Layout.preferredWidth: root.coverSize
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.player ? root.player.trackTitle : "Nothing playing"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            Layout.preferredWidth: root.coverSize
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: root.player ? root.player.trackArtist : ""
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.small(-2)
            font.weight: Theme.smallWeight
            renderType: Text.NativeRendering
            elide: Text.ElideRight
        }
    }

    RowLayout {
        Layout.preferredWidth: root.coverSize
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

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                enabled: root.player && root.player.canSeek
                onPressed: mouse => root.player.position = (mouse.x / width) * root.player.length
                onPositionChanged: mouse => {
                    if (pressed)
                        root.player.position = Math.max(0, Math.min(1, mouse.x / width)) * root.player.length;
                }
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

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 2
        spacing: 26

        Image {
            source: Quickshell.shellPath("assets/icons/media-previous.svg")
            width: 18
            height: 18
            sourceSize: Qt.size(width, height)
            opacity: root.player && root.player.canGoPrevious ? 1 : 0.35
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                enabled: root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
        }

        Rectangle {
            implicitWidth: 44
            implicitHeight: 44
            radius: width / 2
            color: Theme.green

            Image {
                anchors.centerIn: parent
                source: root.player && root.player.isPlaying ? Quickshell.shellPath("assets/icons/media-pause.svg") : Quickshell.shellPath("assets/icons/media-play.svg")
                width: 20
                height: 20
                sourceSize: Qt.size(width, height)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.player && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
        }

        Image {
            source: Quickshell.shellPath("assets/icons/media-next.svg")
            width: 18
            height: 18
            sourceSize: Qt.size(width, height)
            opacity: root.player && root.player.canGoNext ? 1 : 0.35
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                enabled: root.player && root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }
}
