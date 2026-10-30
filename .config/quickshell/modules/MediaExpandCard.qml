import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Always-expanded dashboard media card (see docs/ideas/media-player-popup.md).
// No collapsed state, no reserved/growDelay/fadeIn/fadeOut machinery
// needed like AudioMixerRow/SystemResourcesRow/WeatherRow - just renders
// whenever a player is active (the enclosing Loader in Dashboard.qml
// gates that). Layout mirrors MediaHoverPopup.qml (large centered cover
// art on top, title/artist/progress below) so the bar tooltip and
// dashboard card read as the same feature. Transport controls use custom
// SVG icons (assets/icons/media-*.svg) in a Spotify-style layout - a
// large filled circular play/pause button flanked by plain prev/next
// glyphs - instead of nerd-font Text icons.
//
// Resolves its own player directly instead of embedding a Media{} logic
// instance (as netLogic/btLogic etc. do in Dashboard.qml) for two reasons:
// a Media{} child inside a ColumnLayout participates in the layout itself
// (Layout only excludes children via visible:false in some Qt versions,
// not reliably - confirmed broken here), and Media.qml now always spawns
// its own cava subprocess while a player is active, which would run a
// second redundant cava process just to read text properties. Skips the
// Spotify-blip/Firefox-stale-title guards Media.qml has for the compact
// pill - a one-frame title blip is far less jarring in an already-visible
// card than it was in the pill, same tradeoff MediaHoverPopup.qml makes.
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

    // Same position-polling workaround as MediaHoverPopup.qml - position only
    // notifies on nonlinear changes (seek/track change), not continuously.
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
            font.pixelSize: Theme.fontSize - 2
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
            font.pixelSize: Theme.fontSize - 4
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
            font.pixelSize: Theme.fontSize - 4
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 2
        spacing: 26

        Image {
            source: "file:///home/johu/.config/quickshell/assets/icons/media-previous.svg"
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
            color: Theme.mauve

            Image {
                anchors.centerIn: parent
                source: root.player && root.player.isPlaying ? "file:///home/johu/.config/quickshell/assets/icons/media-pause.svg" : "file:///home/johu/.config/quickshell/assets/icons/media-play.svg"
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
            source: "file:///home/johu/.config/quickshell/assets/icons/media-next.svg"
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
