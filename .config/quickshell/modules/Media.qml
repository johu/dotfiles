import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Bar pill: a cava-style audio visualizer (see docs/ideas/media-player-popup.md).
// Left-click: play/pause. Scroll: prev/next. Hover: MediaHoverPopup.
Item {
    id: root

    property string lastActivePlayerId: ""

    readonly property var players: Mpris.players.values
    // With several players playing, prefer the one that started most recently
    // (lastActivePlayerId, set in Bar.qml) so the control target doesn't flip
    // between sources on each click.
    readonly property var player: players.find(p => p.dbusName === root.lastActivePlayerId && p.playbackState !== MprisPlaybackState.Stopped) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    // Spotify's MPRIS occasionally sends an empty xesam:title around
    // pause/resume, wiping trackTitle until the next track. Keep the last
    // non-empty title per player instead.
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

    // Firefox/Zen's MPRIS bridge doesn't update xesam:title/url on YouTube SPA
    // navigation. Position jumping backward without a url change is the only
    // signal, so flag the title as unconfirmed and show the player name until
    // the url changes.
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
        // Only for players that report a url (browsers). Others leave it empty, so
        // every normal track change would look stale and never reset.
        if (root.currentUrl !== "" && root.currentPosition < root._lastPosition - 3 && root.currentUrl === root._lastUrl)
            root.titleUnconfirmed = true;
        root._lastPosition = root.currentPosition;
    }

    readonly property bool titleKnown: root.player && !root.titleUnconfirmed && root.effectiveTitle
    readonly property string displayTitle: root.titleKnown ? root.effectiveTitle : ""
    readonly property string displayArtist: root.player ? (root.titleKnown ? root.player.trackArtist : "") : ""
    // Player name, shown when the title is unconfirmed.
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

    // True while cava hears sound, even with the MPRIS player paused.
    property bool audioActive: false
    Timer {
        id: silenceTimer
        interval: 800
        onTriggered: root.audioActive = false
    }

    // Only spawned while active: it holds a PipeWire capture stream open and
    // burns CPU on FFT work.
    Process {
        id: cava
        running: root.player !== null
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.split(";").filter(s => s.length > 0);
                if (parts.length === 0)
                    return;
                let peak = 0;
                for (let i = 0; i < barModel.count && i < parts.length; i++) {
                    const n = Number(parts[i]);
                    peak = Math.max(peak, n);
                    barModel.setProperty(i, "v", n);
                }
                // Non-MPRIS audio (games, etc.) counts as active too.
                if (peak > 0) {
                    root.audioActive = true;
                    silenceTimer.restart();
                }
            }
        }
    }

    // Settle bars to 0 instead of freezing the last frame on a pill the Loader
    // is about to destroy.
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
                color: (root.player && root.player.isPlaying) || root.audioActive ? Theme.green : Theme.subtext1

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
