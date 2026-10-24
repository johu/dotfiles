import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    property string lastActivePlayerId: ""

    readonly property var players: Mpris.players.values
    // When multiple players are simultaneously playing, prefer whichever
    // one most recently and deliberately started (lastActivePlayerId,
    // updated in Bar.qml's Instantiator) over an arbitrary array-order
    // pick — otherwise the control target can silently flip between
    // sources on every click, pausing/skipping whichever one happens to
    // win the tie-break instead of the one you actually meant to control.
    readonly property var player: players.find(p => p.dbusName === root.lastActivePlayerId && p.playbackState !== MprisPlaybackState.Stopped) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    // Spotify's MPRIS client occasionally emits a PropertiesChanged delta
    // with an empty xesam:title around pause/resume, which Quickshell's
    // MprisPlayer applies as-is, wiping the cached trackTitle until the
    // next real update (often not until the next track change). Keep our
    // own last-known-good title per player so that blank blip doesn't drop
    // the title from the pill; it only updates again once a genuinely new
    // non-empty title arrives, or the player itself changes.
    property string _lastGoodTitle: ""
    property string _lastGoodTitleKey: ""

    readonly property string rawTitle: root.player ? root.player.trackTitle : ""

    onRawTitleChanged: {
        const key = root.player ? root.player.dbusName : "";
        if (key !== root._lastGoodTitleKey) {
            root._lastGoodTitleKey = key;
            root._lastGoodTitle = root.rawTitle;
            return;
        }
        if (root.rawTitle)
            root._lastGoodTitle = root.rawTitle;
    }

    readonly property string effectiveTitle: root.rawTitle || root._lastGoodTitle

    Component.onCompleted: {
        root._lastGoodTitleKey = root.player ? root.player.dbusName : "";
        root._lastGoodTitle = root.rawTitle;
    }

    // Firefox/Zen's MPRIS bridge has a related but different bug: switching
    // videos via YouTube's SPA navigation (no full page reload) often never
    // updates xesam:title/url at all, even though PlaybackStatus and
    // Position correctly reflect the new video — confirmed against raw
    // playerctl output, not a Quickshell or widget bug. The only reliable
    // fingerprint we have is Position jumping backward (a new video
    // starting) without xesam:url changing to match; flag that combination
    // as unconfirmed and show the player's identity instead until the url
    // eventually does change.
    property real _lastPosition: 0
    property string _lastPlayerKey: ""
    property string _lastUrl: ""
    property bool titleUnconfirmed: false

    readonly property string currentUrl: root.player && root.player.metadata ? (root.player.metadata["xesam:url"] ?? "") : ""
    readonly property real currentPosition: root.player ? root.player.position : 0

    onCurrentUrlChanged: root.titleUnconfirmed = false
    onCurrentPositionChanged: {
        const key = root.player ? root.player.dbusName : "";
        if (key !== root._lastPlayerKey) {
            root._lastPlayerKey = key;
            root._lastUrl = root.currentUrl;
            root._lastPosition = root.currentPosition;
            root.titleUnconfirmed = false;
            return;
        }
        if (root.currentPosition < root._lastPosition - 3 && root.currentUrl === root._lastUrl)
            root.titleUnconfirmed = true;
        root._lastPosition = root.currentPosition;
    }

    readonly property bool titleKnown: root.player && !root.titleUnconfirmed && root.effectiveTitle
    readonly property string displayText: {
        if (!root.player)
            return "";
        if (root.titleKnown)
            return root.player.trackArtist ? `${root.player.trackArtist} - ${root.effectiveTitle}` : root.effectiveTitle;
        // Title is stale/unknown (see the Firefox/Zen note above). The
        // artist field (the YouTube channel, for browser players) tends to
        // stay accurate even when the title doesn't, so prefer it over the
        // player's generic identity; only fall back to identity when we
        // have nothing better to show.
        return root.player.trackArtist || root.player.identity;
    }

    implicitWidth: icon.implicitWidth + row.spacing + metrics.width
    implicitHeight: Theme.moduleHeight

    TextMetrics {
        id: metrics
        font: label.font
        text: root.displayText
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 8

        Text {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            // nf-fa-pause / nf-fa-play
            text: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
            color: Theme.green
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize
            font.bold: true
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - icon.implicitWidth - row.spacing
            text: root.displayText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.player)
                return;
            if (root.player.canTogglePlaying)
                root.player.togglePlaying();
            else if (root.player.isPlaying && root.player.canPause)
                root.player.pause();
            else if (!root.player.isPlaying && root.player.canPlay)
                root.player.play();
        }
        onWheel: wheel => {
            if (!root.player)
                return;
            if (wheel.angleDelta.y > 0) {
                if (root.player.canGoPrevious)
                    root.player.previous();
            } else {
                if (root.player.canGoNext)
                    root.player.next();
            }
        }
    }
}
