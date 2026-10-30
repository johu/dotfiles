import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

// Bar pill: a live cava-style audio visualizer, replacing the old
// icon+"Artist - Title" text pill entirely (see docs/ideas/media-player-popup.md).
// Left-click: play/pause. Scroll: prev/next. Hover: MediaHoverPopup (cover
// art + title/artist + playback progress, read-only).
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
    // the title shown in MediaHoverPopup/MediaExpandCard; it only updates again
    // once a genuinely new non-empty title arrives, or the player changes.
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
        // Only trust this heuristic for players that actually report a
        // url (browsers) - Spotify and most native players never populate
        // xesam:url, so currentUrl stays "" permanently and every normal
        // track change (position resets to ~0) would otherwise look like
        // the Firefox/Zen stale-title bug and get stuck unconfirmed
        // forever, since the only reset path is the url changing.
        if (root.currentUrl !== "" && root.currentPosition < root._lastPosition - 3 && root.currentUrl === root._lastUrl)
            root.titleUnconfirmed = true;
        root._lastPosition = root.currentPosition;
    }

    readonly property bool titleKnown: root.player && !root.titleUnconfirmed && root.effectiveTitle
    readonly property string displayTitle: root.titleKnown ? root.effectiveTitle : ""
    readonly property string displayArtist: root.player ? (root.titleKnown ? root.player.trackArtist : "") : ""
    // Fallback identity (player name) for when the title itself is
    // unconfirmed/stale - same heuristic the old text pill used.
    readonly property string displayFallback: root.player ? (root.player.trackArtist || root.player.identity) : ""

    readonly property int barCount: 26
    readonly property real barWidth: 3
    readonly property real barSpacing: 3
    readonly property real barMaxHeight: 20

    implicitWidth: barCount * barWidth + (barCount - 1) * barSpacing
    implicitHeight: Theme.moduleHeight

    ListModel {
        id: barModel
        Component.onCompleted: {
            for (let i = 0; i < root.barCount; i++)
                append({ v: 0 });
        }
    }

    // Only spawned while a player is actually active - otherwise it keeps
    // a PipeWire capture stream open and burns CPU on FFT work for a bar
    // element nobody can see (hidden by the Loader in Bar.qml).
    Process {
        id: cava
        running: root.player !== null
        command: ["cava", "-p", "/home/johu/.config/quickshell/assets/cava.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.split(";").filter(s => s.length > 0);
                if (parts.length === 0)
                    return;
                for (let i = 0; i < barModel.count && i < parts.length; i++)
                    barModel.setProperty(i, "v", Number(parts[i]));
            }
        }
    }

    // Bars settle back to 0 rather than freezing mid-animation once cava
    // stops (player went away) - otherwise the last frame's heights stick
    // around on a pill that's about to be destroyed by the Loader.
    onPlayerChanged: if (!root.player) {
        for (let i = 0; i < barModel.count; i++)
            barModel.setProperty(i, "v", 0);
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.barSpacing

        Repeater {
            model: barModel

            delegate: Rectangle {
                required property real v

                width: root.barWidth
                radius: width / 2
                height: Math.max(width, (v / 100) * root.barMaxHeight)
                anchors.bottom: parent.bottom
                color: root.player && root.player.isPlaying ? Theme.mauve : Theme.subtext1

                Behavior on height {
                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    MediaHoverPopup {
        id: hoverPopup
        player: root.player
        displayTitle: root.displayTitle || root.displayFallback
        displayArtist: root.titleKnown ? root.displayArtist : ""
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hoverPopup.open(root)
        onExited: hoverPopup.close()
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
