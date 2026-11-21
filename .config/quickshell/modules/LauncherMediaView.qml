import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Media view of the launcher: cover, transport and seek, time-synced lyrics
// (LyricsData, from LRCLIB) and a cava visualizer. Three modes share one
// scene: "normal" (poster player, three lyric lines, quiet bars behind),
// "lyrics" (the lyrics take the view) and "visualizer" (full-width mirrored
// bars). Every element's geometry is a blend of three poses driven by two
// animated weights (lyricsF, visF), so switching modes animates the whole
// scene, and even an interrupted switch stays consistent.
Item {
    id: view

    property int textRender: Text.NativeRendering

    // Asked for by the launcher: this view takes much more of the screen than
    // the calendar and weather views (clamped to what fits).
    readonly property int preferredWidth: 2000
    readonly property int preferredHeight: 1100

    signal closeRequested
    signal leaveRequested

    // ---- players ----
    readonly property var players: Mpris.players.values
    property string chosenPlayer: ""
    readonly property var player: view.players.find(p => p.dbusName === view.chosenPlayer) ?? view.players.find(p => p.isPlaying) ?? view.players[0] ?? null
    readonly property bool hasPlayer: view.player !== null

    // Spotify briefly reports an empty title around pause/resume.
    property string goodTitle: ""
    readonly property string rawTitle: view.player ? view.player.trackTitle : ""
    onRawTitleChanged: if (view.rawTitle)
        view.goodTitle = view.rawTitle
    readonly property string title: view.rawTitle || view.goodTitle
    readonly property string artist: view.player ? view.player.trackArtist : ""
    readonly property string album: view.player ? view.player.trackAlbum : ""

    // Icon of the player: the icon of its desktop entry, else a theme icon named
    // like the entry. Empty when the theme has none (then the name is shown).
    readonly property string playerIconName: {
        if (!view.player)
            return "";
        const id = view.player.desktopEntry;
        const entry = id ? DesktopEntries.heuristicLookup(id) : null;
        const name = entry && entry.icon ? entry.icon : id;
        return name && Quickshell.iconPath(name, true) !== "" ? name : "";
    }

    // Position only notifies on seeks and track changes, so poll it.
    readonly property real pos: view.player ? view.player.position : 0
    readonly property real length: view.player ? Math.max(0, view.player.length) : 0

    Timer {
        running: view.player !== null && view.player.isPlaying
        interval: 250
        repeat: true
        onTriggered: view.player.positionChanged()
    }

    // ---- modes and the animated pose weights ----
    // "normal" | "lyrics" | "visualizer"
    property string mode: "normal"
    property real lyricsF: view.mode === "lyrics" ? 1 : 0
    property real visF: view.mode === "visualizer" ? 1 : 0
    readonly property real normalF: Math.max(0, 1 - view.lyricsF - view.visF)

    Behavior on lyricsF {
        NumberAnimation {
            duration: 460
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on visF {
        NumberAnimation {
            duration: 460
            easing.type: Easing.InOutCubic
        }
    }

    // Blend of the value in each mode.
    function pose(normal, lyrics, vis) {
        return normal * view.normalF + lyrics * view.lyricsF + vis * view.visF;
    }

    // The poses are designed for a 780 px high view; the real height is a bit
    // less (the launcher card has padding), so vertical values are scaled.
    readonly property real ky: view.height / 780
    // Horizontal scale against the compact 1318 px the widths were designed for.
    readonly property real kx: view.width / 1318
    function posey(normal, lyrics, vis) {
        return view.pose(normal, lyrics, vis) * view.ky;
    }

    function setMode(m) {
        view.mode = view.mode === m ? "normal" : m;
    }

    function handleEscape() {
        if (view.mode === "normal")
            return false;
        view.mode = "normal";
        return true;
    }

    // ---- lyrics ----
    readonly property string trackSig: view.player ? [view.artist, view.title, view.album, Math.round(view.length)].join("|") : ""
    onTrackSigChanged: {
        view.scrollOffset = 0;
        sigTimer.restart();
    }

    // Wait for the metadata to settle before asking the network.
    Timer {
        id: sigTimer

        interval: 500
        onTriggered: view.requestLyrics(false)
    }

    function requestLyrics(force) {
        if (view.player && view.title)
            LyricsData.request(view.artist, view.title, view.album, view.length, force);
    }

    Component.onCompleted: view.requestLyrics(false)

    readonly property int lineCount: LyricsData.lines.length
    readonly property int curLine: LyricsData.synced ? LyricsData.lineAt(view.pos + 0.2) : -1

    // j / k move the highlight away from the playing line (or through
    // unsynced lyrics); a few seconds later a synced view follows the song again.
    property int scrollOffset: 0
    readonly property int scrollBase: LyricsData.synced ? view.curLine : 0
    readonly property real targetPos: Math.max(LyricsData.synced ? -1 : 0, Math.min(view.lineCount - 1, view.scrollBase + view.scrollOffset))
    property real scrollPos: view.targetPos

    Behavior on scrollPos {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: followTimer

        interval: 5000
        onTriggered: if (LyricsData.synced)
            view.scrollOffset = 0
    }

    function scrollLines(delta) {
        const lo = (LyricsData.synced ? -1 : 0) - view.scrollBase;
        const hi = view.lineCount - 1 - view.scrollBase;
        view.scrollOffset = Math.max(lo, Math.min(hi, view.scrollOffset + delta));
        followTimer.restart();
    }

    readonly property string statusText: {
        switch (LyricsData.status) {
        case "loading":
            return "Looking up lyrics…";
        case "none":
            return "No lyrics found";
        case "instrumental":
            return "♪  Instrumental  ♪";
        case "error":
            return "Could not load lyrics (r to retry)";
        case "idle":
            return view.title ? "" : "";
        }
        return "";
    }

    readonly property string lyricsInfo: {
        // Synced is the normal case and needs no label; unsynced explains why
        // the highlight does not follow the song.
        if (LyricsData.status !== "ok" || LyricsData.synced)
            return "";
        return "Unsynced lyrics (j k to scroll)";
    }

    // ---- transport ----
    function seekBy(seconds) {
        if (!view.player || !view.player.canSeek)
            return;
        view.player.position = Math.max(0, Math.min(view.length, view.player.position + seconds));
    }

    function seekToLine() {
        if (!LyricsData.synced || !view.player || !view.player.canSeek)
            return;
        const line = LyricsData.lines[Math.round(view.scrollPos)];
        if (line) {
            view.player.position = line.t;
            view.scrollOffset = 0;
        }
    }

    property real toastAt: 0
    property string toastText: ""

    function changeVolume(delta) {
        if (!view.player || !view.player.volumeSupported)
            return;
        view.player.volume = Math.max(0, Math.min(1, view.player.volume + delta));
        view.toastText = "Volume " + Math.round(view.player.volume * 100) + " %";
        toastTimer.restart();
    }

    Timer {
        id: toastTimer

        interval: 1400
        onTriggered: view.toastText = ""
    }

    function nextPlayer() {
        if (view.players.length < 2)
            return;
        const i = view.players.findIndex(p => p === view.player);
        view.chosenPlayer = view.players[(i + 1) % view.players.length].dbusName;
        view.scrollOffset = 0;
    }

    function fmt(seconds) {
        const t = Math.max(0, Math.floor(seconds));
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
    }

    // ---- keys ----
    readonly property var hints: {
        const play = { keys: ["Space"], text: "play" };
        const tracks = { keys: ["n", "p"], text: "track" };
        const seek = { keys: ["H", "L"], text: "seek" };
        const lyricsKey = { keys: ["l"], text: "lyrics" };
        const visKey = { keys: ["v"], text: "visualizer" };
        const back = { keys: ["h"], text: "back" };
        if (!view.hasPlayer)
            return [[{ keys: ["q"], text: "close" }]];
        const players = view.players.length > 1 ? [{ keys: ["Tab"], text: "player" }] : [];
        if (view.mode === "lyrics")
            return [[{ keys: ["j", "k"], text: "scroll" }, { keys: ["↵"], text: "jump to line" }, { keys: ["t"], text: "follow" }, { keys: ["r"], text: "reload" }], [play, tracks, seek, visKey, back]];
        if (view.mode === "visualizer")
            return [[play, tracks, seek, lyricsKey, back]];
        return [[play, tracks, seek, lyricsKey, visKey].concat(players).concat([{ keys: ["q"], text: "close" }])];
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Space:
            if (view.player && view.player.canTogglePlaying)
                view.player.togglePlaying();
            return true;
        case Qt.Key_N:
            if (view.player && view.player.canGoNext)
                view.player.next();
            return true;
        case Qt.Key_P:
            if (view.player && view.player.canGoPrevious)
                view.player.previous();
            return true;
        case Qt.Key_H:
            if (shift)
                view.seekBy(-5);
            else
                view.mode = "normal";
            return true;
        case Qt.Key_Left:
            view.seekBy(-5);
            return true;
        case Qt.Key_Right:
            view.seekBy(5);
            return true;
        case Qt.Key_L:
            if (shift)
                view.seekBy(5);
            else
                view.setMode("lyrics");
            return true;
        case Qt.Key_V:
            view.setMode("visualizer");
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            view.scrollLines(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.scrollLines(-1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.scrollLines(5);
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.scrollLines(-5);
            return true;
        case Qt.Key_T:
        case Qt.Key_Home:
            view.scrollOffset = 0;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            view.seekToLine();
            return true;
        case Qt.Key_R:
            view.requestLyrics(true);
            return true;
        case Qt.Key_Tab:
            view.nextPlayer();
            return true;
        case Qt.Key_Plus:
        case Qt.Key_Equal:
            view.changeVolume(0.05);
            return true;
        case Qt.Key_Minus:
            view.changeVolume(-0.05);
            return true;
        case Qt.Key_Q:
            if (!view.handleEscape())
                view.leaveRequested();
            return true;
        }
        return false;
    }

    // ---- visualizer data ----
    property var levels: []

    Process {
        running: view.hasPlayer
        command: ["sh", Quickshell.shellPath("scripts/cava-run.sh"), Quickshell.shellPath("assets/cava-view.conf")]
        stderr: SplitParser {
            onRead: data => console.warn("cava: " + data)
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.split(";");
                const out = [];
                for (let i = 0; i < parts.length; i++)
                    if (parts[i].length > 0)
                        out.push(Number(parts[i]));
                if (out.length > 0)
                    view.levels = out;
            }
        }
    }

    // Settle the bars when the player goes away.
    onHasPlayerChanged: if (!view.hasPlayer)
        view.levels = []

    // ---- nothing playing ----
    EmptyState {
        visible: !view.hasPlayer
        anchors.fill: parent
        illustration: "music.svg"
        title: "Nothing playing"
        hint: "Start a song in your player and it shows up here"
        textRender: view.textRender
    }

    // ---- the scene ----
    Item {
        id: stage

        visible: view.hasPlayer
        anchors.fill: parent

        AudioBars {
            x: 40 * view.kx
            y: view.posey(520, 520, 290)
            width: view.width - 80 * view.kx
            height: view.posey(260, 260, 360)
            mirror: view.visF
            opacity: view.pose(0.16, 0.08, 1)
            levels: view.levels
            count: 64
        }

        CoverArt {
            readonly property real size: view.posey(340, 0, 190)

            visible: size > 1
            width: size
            height: size
            x: (view.width - width) / 2
            y: view.posey(10, 0, 0)
            radius: view.pose(16, 6, 14)
            opacity: view.pose(1, 0, 1)
            artUrl: view.player ? view.player.trackArtUrl : ""
        }

        Text {
            width: view.width - 100
            height: 56 * view.ky
            x: (view.width - width) / 2
            y: view.posey(362, 0, 202)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: view.title || "Unknown title"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(view.pose(42, 32, 34) * view.ky)
            font.bold: true
            elide: Text.ElideRight
            renderType: view.textRender
        }

        Text {
            width: view.width - 100
            height: 34 * view.ky
            x: (view.width - width) / 2
            y: view.posey(418, 50, 246)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: view.artist + (view.artist && view.album ? "  ·  " : "") + view.album
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(view.pose(24, 20, 22) * view.ky)
            elide: Text.ElideRight
            renderType: view.textRender
        }

        // Player icon (top left; its name when there is no icon) and the
        // unsynced note / volume toast (top right).
        ResolvedIcon {
            visible: view.playerIconName !== ""
            x: 0
            y: 0
            size: Math.round(36 * view.ky)
            iconSource: view.playerIconName !== "" ? "image://icon/" + view.playerIconName : ""
        }

        Text {
            visible: view.playerIconName === ""
            x: 0
            y: 0
            height: 24
            text: view.player ? view.player.identity : ""
            color: Theme.subtext1
            opacity: 0.8
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSize * view.ky)
            renderType: view.textRender
        }

        Text {
            x: view.width - width
            y: 0
            width: 380
            height: 24
            horizontalAlignment: Text.AlignRight
            text: view.toastText !== "" ? view.toastText : view.lyricsInfo
            color: view.toastText !== "" ? Theme.yellow : Theme.subtext1
            opacity: 0.8
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSize * view.ky)
            renderType: view.textRender
        }

        // ---- seek bar ----
        Item {
            id: seekBox

            width: view.pose(920, 1200, 1200) * view.kx
            height: 44 * view.ky
            x: (view.width - width) / 2
            y: view.posey(466, 715, 715)

            readonly property real ratio: view.length > 0 ? Math.min(1, view.pos / view.length) : 0

            Rectangle {
                id: track

                y: 8
                width: parent.width
                height: 6 * view.ky
                radius: height / 2
                color: Theme.surface2

                Rectangle {
                    width: parent.width * seekBox.ratio
                    height: parent.height
                    radius: parent.radius
                    color: Theme.blue
                }

                Rectangle {
                    x: parent.width * seekBox.ratio - width / 2
                    y: (parent.height - height) / 2
                    width: 14 * view.ky
                    height: 14 * view.ky
                    radius: width / 2
                    color: Theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
                    enabled: view.player && view.player.canSeek
                    onPressed: mouse => view.player.position = Math.max(0, Math.min(1, mouse.x / width)) * view.length
                    onPositionChanged: mouse => {
                        if (pressed)
                            view.player.position = Math.max(0, Math.min(1, mouse.x / width)) * view.length;
                    }
                }
            }

            Text {
                y: 20 * view.ky
                text: view.fmt(view.pos)
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Math.round((Theme.fontSize + 2) * view.ky)
                renderType: view.textRender
            }

            Text {
                y: 20 * view.ky
                x: parent.width - width
                text: "-" + view.fmt(Math.max(0, view.length - view.pos))
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Math.round((Theme.fontSize + 2) * view.ky)
                renderType: view.textRender
            }
        }

        // ---- transport buttons (normal mode only) ----
        Item {
            id: controls

            readonly property real shown: view.normalF

            visible: shown > 0.01
            opacity: shown
            width: 380
            height: 80
            scale: view.ky
            x: (view.width - width) / 2
            y: 548 * view.ky - height / 2

            Image {
                x: 50
                y: 23
                width: 34
                height: 34
                source: Quickshell.shellPath("assets/icons/media-previous.svg")
                sourceSize: Qt.size(68, 68)
                opacity: view.player && view.player.canGoPrevious ? 1 : 0.35

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    enabled: view.player && view.player.canGoPrevious
                    onClicked: view.player.previous()
                }
            }

            Rectangle {
                x: 152
                y: 2
                width: 76
                height: 76
                radius: 38
                color: Theme.blue

                Image {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    sourceSize: Qt.size(68, 68)
                    source: view.player && view.player.isPlaying ? Quickshell.shellPath("assets/icons/media-pause.svg") : Quickshell.shellPath("assets/icons/media-play.svg")
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: view.player && view.player.canTogglePlaying
                    onClicked: view.player.togglePlaying()
                }
            }

            Image {
                x: 296
                y: 23
                width: 34
                height: 34
                source: Quickshell.shellPath("assets/icons/media-next.svg")
                sourceSize: Qt.size(68, 68)
                opacity: view.player && view.player.canGoNext ? 1 : 0.35

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    enabled: view.player && view.player.canGoNext
                    onClicked: view.player.next()
                }
            }
        }

        // ---- lyrics ----
        readonly property real lyricsCenter: view.posey(678, 392, 668)
        readonly property real pitch: view.posey(54, 84, 60)
        readonly property real curSize: view.pose(36, 56, 32) * view.ky
        readonly property real otherSize: view.pose(26, 34, 24) * view.ky
        // How many lines beside the current one stay visible per mode.
        readonly property real reach: view.pose(1, 3.0, 0)
        readonly property real lineWidth: view.pose(1100, 1260, 1200) * view.kx

        Text {
            visible: view.statusText !== ""
            width: stage.lineWidth
            x: (view.width - width) / 2
            y: stage.lyricsCenter - height / 2
            horizontalAlignment: Text.AlignHCenter
            text: view.statusText
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(stage.otherSize)
            font.italic: true
            renderType: view.textRender
        }

        Repeater {
            model: LyricsData.lines

            Text {
                id: line

                required property var modelData
                required property int index

                readonly property real dist: line.index - view.scrollPos
                readonly property real adist: Math.abs(line.dist)
                readonly property real fade: Math.max(0, Math.min(1, stage.reach + 1 - line.adist)) * Math.max(0.14, 1 - 0.45 * Math.min(1, line.adist) - 0.08 * Math.max(0, line.adist - 1))

                visible: line.fade > 0.01
                opacity: line.fade
                width: stage.lineWidth
                x: (view.width - width) / 2
                y: stage.lyricsCenter + line.dist * stage.pitch - height / 2
                horizontalAlignment: Text.AlignHCenter
                // Gaps in a song come as empty synced lines; show them as a note.
                text: line.modelData.s !== "" ? line.modelData.s : (LyricsData.synced ? "♪" : " ")
                color: line.adist < 0.5 ? Theme.yellow : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(stage.otherSize + (stage.curSize - stage.otherSize) * Math.max(0, 1 - line.adist))
                font.bold: line.adist < 0.5
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 14
                elide: Text.ElideRight
                renderType: view.textRender

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }
    }
}
