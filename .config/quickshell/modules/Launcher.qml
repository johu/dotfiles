import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    visible: false
    color: "transparent"
    screen: Env.targetScreen()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Ignore the bar's exclusive zone so the surface and its screencopy cover
    // the full screen; otherwise the capture letterboxes.
    exclusionMode: ExclusionMode.Ignore

    // Exclusive keyboard focus, like rofi. PopupWindow's grabFocus dismisses
    // almost immediately on Hyprland (see Calendar.qml).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property int pillWidth: 460
    readonly property int pillHeight: 64
    readonly property int resultsPanelWidth: 880
    readonly property int tileWidth: 220
    readonly property int tileContentMargin: 16
    readonly property int tileIconSize: 48
    readonly property int tileIconSpacing: 8
    readonly property int maxVisibleRows: 3
    readonly property int resultColumns: Math.max(1, Math.floor(root.resultsPanelWidth / root.tileWidth))
    readonly property int inputFontSize: Theme.fontSize + 8
    readonly property int resultFontSize: Theme.fontSize + 4
    readonly property int focusedDescFontSize: Theme.fontSize + 1
    // Fixed 2-line height so short names don't misalign icons.
    readonly property int nameBlockHeight: Math.round(root.resultFontSize * 2.8)
    // Derived so the margin above the icon equals the one below the name.
    readonly property int tileHeight: root.tileContentMargin * 2 + root.tileIconSize + root.tileIconSpacing + root.nameBlockHeight
    // Fixed slot for the focused item's description so the grid doesn't shift.
    readonly property int focusedDescHeight: Math.round(root.focusedDescFontSize * 3.2)

    readonly property var selectedEntry: root.filtered[root.selectedIndex] ?? null
    readonly property string selectedDescription: root.selectedEntry ? (root.selectedEntry.comment || root.selectedEntry.genericName || "") : ""

    property string query: ""
    property int selectedIndex: 0

    readonly property var apps: {
        const entries = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        return entries.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    // fzf-style subsequence scorer: rewards consecutive runs and word-boundary
    // starts, penalizes scattered spans. Returns -1 if needle isn't a
    // subsequence.
    function fuzzyScore(needle, haystack) {
        if (!needle)
            return 0;

        let score = 0;
        let needleIndex = 0;
        let lastMatchIndex = -1;
        let consecutiveRun = 0;

        for (let i = 0; i < haystack.length && needleIndex < needle.length; i++) {
            if (haystack[i] !== needle[needleIndex])
                continue;

            let charScore = 1;
            if (lastMatchIndex === i - 1) {
                consecutiveRun++;
                charScore += consecutiveRun * 3;
            } else {
                consecutiveRun = 0;
            }

            const prev = i > 0 ? haystack[i - 1] : "";
            if (i === 0 || prev === " " || prev === "-" || prev === "_" || prev === ".")
                charScore += 4;

            score += charScore;
            lastMatchIndex = i;
            needleIndex++;
        }

        if (needleIndex < needle.length)
            return -1;

        const span = lastMatchIndex + 1;
        score += Math.max(0, 20 - (span - needle.length));
        return score;
    }

    // ---- Frecency + learned search terms (ideas/app-launcher-omacast.md 1, 2) ----
    // visits: { [desktopId]: { anchor: <epoch s>, terms: [{ term, at: <epoch s> }] } }
    // Frecency ported from oma-cast core/Frecency.js: score decays with a
    // 10-day half-life, each launch adds 100. `anchor` is the moment the
    // score decays to 1, so no per-item timestamp churn.
    readonly property real frecencyLambda: Math.LN2 / 10
    readonly property int termMax: 20
    readonly property real termTtl: 17 * 86400
    property var visits: ({})

    function frecency(id, now) {
        const v = root.visits[id];
        if (!v)
            return 1;
        return Math.max(1, Math.exp(root.frecencyLambda * (v.anchor - now) / 86400));
    }

    function recordVisit(entry, rawQuery) {
        const now = Date.now() / 1000;
        const next = Object.assign({}, root.visits);
        const old = next[entry.id];
        const score = root.frecency(entry.id, now) + 100;
        const rec = {
            anchor: now + 86400 * Math.log(score) / root.frecencyLambda,
            terms: (old && old.terms ? old.terms : []).filter(t => now - t.at < root.termTtl)
        };
        const term = rawQuery.trim().toLowerCase();
        if (term && term !== (entry.name || "").toLowerCase()) {
            rec.terms = rec.terms.filter(t => t.term !== term);
            rec.terms.unshift({ term: term, at: now });
            rec.terms = rec.terms.slice(0, root.termMax);
        }
        next[entry.id] = rec;
        root.visits = next;
        visitsAdapter.visits = next;
        visitsFile.writeAdapter();
        chmodProc.running = true;
    }

    // State dir 0700 / file 0600 (omacast row 18). Re-run after each write.
    property var chmodProc: Process {
        command: ["sh", "-c", "chmod 700 \"$HOME/.local/state/quickshell\" && chmod 600 \"$HOME/.local/state/quickshell/launcher.json\""]
    }

    property var mkdirProc: Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", Quickshell.env("HOME") + "/.local/state/quickshell"]
    }

    property var visitsFile: FileView {
        id: visitsFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/launcher.json"
        printErrors: false
        onLoaded: root.visits = visitsAdapter.visits ?? ({})

        JsonAdapter {
            id: visitsAdapter
            property var visits: ({})
        }
    }

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return [];

        const now = Date.now() / 1000;
        const scored = [];
        for (const e of root.apps) {
            const name = (e.name || "").toLowerCase();
            const generic = (e.genericName || "").toLowerCase();
            const comment = (e.comment || "").toLowerCase();
            const keywords = (e.keywords || []).join(" ").toLowerCase();

            // Terms that previously launched this app act like an exact/prefix hit.
            let learned = -1;
            const vrec = root.visits[e.id];
            if (vrec && vrec.terms) {
                for (const t of vrec.terms) {
                    if (now - t.at >= root.termTtl)
                        continue;
                    if (t.term === q) {
                        learned = 1100;
                        break;
                    }
                    if (t.term.startsWith(q))
                        learned = Math.max(learned, 850);
                }
            }

            let score = -1;
            if (learned >= 0)
                score = learned;
            else if (name === q)
                score = 1000;
            else if (name.startsWith(q))
                score = 800;
            else if (name.includes(q))
                score = 500;
            else if (generic.includes(q) || keywords.includes(q))
                score = 300;
            else if (comment.includes(q))
                score = 100;
            else {
                const fuzzy = root.fuzzyScore(q, name);
                if (fuzzy >= 0)
                    score = 50 + Math.min(fuzzy, 40);
            }

            if (score >= 0) {
                // Frecency: small additive bonus (<= 40) plus an exact tie-breaker below.
                const f = root.frecency(e.id, now);
                score += Math.min(40, 8 * Math.log2(f));
                scored.push({ entry: e, score: score, frec: f });
            }
        }
        scored.sort((a, b) => b.score - a.score || b.frec - a.frec || a.entry.name.localeCompare(b.entry.name));
        return scored.map(s => s.entry);
    }

    function open() {
        root.query = "";
        // searchInput.text isn't bound to root.query, so clear it separately or a
        // stale query lingers on reopen.
        searchInput.text = "";
        root.selectedIndex = 0;
        // lastIpcObject is empty until refreshed; needed for window matching.
        Hyprland.refreshToplevels();
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    PopupBehavior {
        name: "launcher"
        popup: root
        focusGrab: false
        openFn: () => root.open()
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    // DesktopEntry.execute() ignores runInTerminal, so wrap Terminal=true apps
    // in $TERMINAL (differs per machine).
    // Window classes this entry may map to (lowercase): startupClass, desktop
    // id, and the Exec binary name. Windows rarely expose the desktop id.
    function entryClasses(entry) {
        const set = new Set();
        if (entry.startupClass)
            set.add(entry.startupClass.toLowerCase());
        if (entry.id)
            set.add(entry.id.replace(/\.desktop$/, "").toLowerCase());
        const exe = (entry.command && entry.command.length) ? entry.command[0].split("/").pop().toLowerCase() : "";
        if (exe)
            set.add(exe);
        return set;
    }

    // Address of the most recently focused open window of this app, or "".
    function findWindow(entry) {
        const classes = root.entryClasses(entry);
        let best = null;
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.address || !o.mapped)
                continue;
            const cls = (o.class || "").toLowerCase();
            const init = (o.initialClass || "").toLowerCase();
            if (!classes.has(cls) && !classes.has(init))
                continue;
            if (!best || (o.focusHistoryID ?? 1e9) < (best.focusHistoryID ?? 1e9))
                best = o;
        }
        return best ? best.address : "";
    }

    // Enter focuses an already-open window of the app; Shift+Enter (or
    // forceNew) always starts a new instance.
    function launch(index, forceNew) {
        const entry = root.filtered[index];
        if (!entry)
            return;
        root.recordVisit(entry, root.query);
        const addr = forceNew ? "" : root.findWindow(entry);
        if (addr) {
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:${addr}" })`]);
            root.close();
            return;
        }
        if (entry.runInTerminal) {
            Apps.runInTerminal(entry.command);
        } else {
            entry.execute();
        }
        root.close();
    }

    onVisibleChanged: {
        if (root.visible)
            Qt.callLater(() => searchInput.forceActiveFocus());
    }

    onFilteredChanged: root.selectedIndex = 0

    // Hyprland's layer_rule blur doesn't render on this Lua-config engine.
    // Fake it with a one-shot screencopy + MultiEffect, a snapshot taken when
    // the launcher opens.
    Item {
        id: blurredBackground

        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            active: root.visible
            sourceComponent: ScreencopyView {
                captureSource: root.screen
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // The launcher sits on one screen, so give every other screen a blur-only
    // window to dim the whole desktop.
    Variants {
        model: Quickshell.screens.filter(s => s !== root.screen)

        PanelWindow {
            id: backdrop

            required property var modelData

            screen: modelData
            visible: root.visible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                anchors.fill: parent

                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    blurMultiplier: 1
                }

                Loader {
                    anchors.fill: parent
                    active: backdrop.visible
                    sourceComponent: ScreencopyView {
                        captureSource: backdrop.screen
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.32 - height / 2
        width: root.pillWidth
        height: root.pillHeight
        radius: root.pillHeight / 2.5
        color: Theme.surface1
        border.width: 1
        border.color: Theme.surface2

        // Swallow clicks so they don't reach the dismiss MouseArea behind.
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                text: "\uf002"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: root.inputFontSize
                renderType: Text.NativeRendering
            }

            TextInput {
                id: searchInput

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.inputFontSize
                renderType: Text.NativeRendering
                clip: true

                onTextChanged: root.query = text

                Keys.onEscapePressed: root.close()
                Keys.onRightPressed: root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1)
                Keys.onLeftPressed: root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                Keys.onDownPressed: root.selectedIndex = Math.min(root.selectedIndex + root.resultColumns, root.filtered.length - 1)
                Keys.onUpPressed: root.selectedIndex = Math.max(root.selectedIndex - root.resultColumns, 0)
                Keys.onReturnPressed: event => root.launch(root.selectedIndex, (event.modifiers & Qt.ShiftModifier) !== 0)
            }
        }
    }

    Text {
        id: focusedDescription

        visible: root.selectedDescription.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: 10
        width: root.resultsPanelWidth
        height: root.focusedDescHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: root.selectedDescription
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.italic: true
        font.pixelSize: root.focusedDescFontSize
        renderType: Text.NativeRendering
    }

    Item {
        id: resultsPanel

        visible: root.filtered.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: focusedDescription.bottom
        anchors.topMargin: 14
        width: root.resultsPanelWidth
        height: Math.min(grid.contentHeight, root.maxVisibleRows * root.tileHeight)
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        GridView {
            id: grid

            anchors.fill: parent
            clip: true
            cellWidth: resultsPanel.width / root.resultColumns
            cellHeight: root.tileHeight
            model: root.filtered
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true

            onCurrentIndexChanged: grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)

            delegate: Item {
                id: delegateRoot

                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: Theme.radius / 2
                    color: delegateRoot.index === root.selectedIndex ? Theme.surface2 : "transparent"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.tileContentMargin
                    spacing: root.tileIconSpacing

                    IconImage {
                        source: Quickshell.iconPath(delegateRoot.modelData.icon, "image-missing")
                        implicitSize: root.tileIconSize
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.nameBlockHeight
                        verticalAlignment: Text.AlignTop
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        text: delegateRoot.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.resultFontSize
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = delegateRoot.index
                    onClicked: mouse => root.launch(delegateRoot.index, (mouse.modifiers & Qt.ShiftModifier) !== 0)
                }
            }
        }
    }
}
