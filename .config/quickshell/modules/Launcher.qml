import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "Calculator.js" as Calculator
import "Locations.js" as Locations
import "WebSearch.js" as WebSearch
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

    // Desktop apps plus session/toggle/capture actions (SystemActions.qml).
    readonly property var candidates: root.apps.concat(SystemActions.entries)

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

    // Row of key-cap chips: spelled-out keys, no macOS symbols.
    component KeyCaps: Row {
        id: caps

        property var keys: []
        property int fontSize: Theme.fontSize
        spacing: 4

        Repeater {
            model: caps.keys

            Rectangle {
                id: cap

                required property string modelData
                height: capLabel.implicitHeight + 8
                width: Math.max(height, capLabel.implicitWidth + 14)
                radius: 6
                color: Theme.surface2
                border.width: 1
                border.color: Theme.surface1

                Text {
                    id: capLabel

                    anchors.centerIn: parent
                    text: cap.modelData
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: caps.fontSize
                    renderType: Text.NativeRendering
                }
            }
        }
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
        root.save();
    }

    // ---- Favorites + hidden entries (omacast rows 6, 7) ----
    // favorites: ordered desktop ids, shown first in results.
    // hidden: desktop ids excluded from results (qs ipc call launcher unhideAll).
    property var favorites: []
    property var hidden: []
    // Hidden-apps mode: lists only hidden apps (even before typing) so they
    // can be restored with the same key that hides.
    property bool showHidden: false

    // ---- Search history on Up (omacast row 9) ----
    // history: most-recent-first queries that launched something.
    property var history: []
    property int historyIndex: -1
    readonly property int historyMax: 20
    property bool ctrlHeld: false

    function recordHistory(q) {
        const term = q.trim();
        if (!term)
            return;
        root.history = [term].concat(root.history.filter(h => h !== term)).slice(0, root.historyMax);
    }

    // Up in an empty search (or on the first result row while browsing)
    // steps to the next older query.
    function historyStep() {
        if (root.history.length === 0)
            return;
        root.historyIndex = Math.min(root.historyIndex + 1, root.history.length - 1);
        searchInput.text = root.history[root.historyIndex];
        searchInput.cursorPosition = searchInput.text.length;
    }

    function save() {
        visitsAdapter.visits = root.visits;
        visitsAdapter.favorites = root.favorites;
        visitsAdapter.hidden = root.hidden;
        visitsAdapter.history = root.history;
        visitsFile.writeAdapter();
        chmodProc.running = true;
    }

    // Keep the highlight on the same app after the result list reorders.
    function reselect(id) {
        const i = root.filtered.findIndex(e => e.id === id);
        root.selectedIndex = i < 0 ? 0 : i;
    }

    function toggleFavorite() {
        const e = root.selectedEntry;
        if (!e)
            return;
        root.favorites = root.favorites.includes(e.id) ? root.favorites.filter(id => id !== e.id) : root.favorites.concat([e.id]);
        root.save();
        root.reselect(e.id);
    }

    // Swap the selected favorite with its neighbouring favorite in the results.
    function moveFavorite(delta) {
        const e = root.selectedEntry;
        const other = root.filtered[root.selectedIndex + delta];
        if (!e || !other)
            return;
        const a = root.favorites.indexOf(e.id);
        const b = root.favorites.indexOf(other.id);
        if (a < 0 || b < 0)
            return;
        const next = root.favorites.slice();
        next[a] = other.id;
        next[b] = e.id;
        root.favorites = next;
        root.save();
        root.reselect(e.id);
    }

    // Hides the selected app, or restores it when in hidden-apps mode.
    function toggleHidden() {
        const e = root.selectedEntry;
        if (!e)
            return;
        const idx = root.selectedIndex;
        if (root.showHidden) {
            root.hidden = root.hidden.filter(id => id !== e.id);
        } else {
            root.hidden = root.hidden.concat([e.id]);
            root.favorites = root.favorites.filter(id => id !== e.id);
        }
        root.save();
        root.selectedIndex = Math.min(idx, root.filtered.length - 1);
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
        onLoaded: {
            root.visits = visitsAdapter.visits ?? ({});
            root.favorites = visitsAdapter.favorites ?? [];
            root.hidden = visitsAdapter.hidden ?? [];
            root.history = visitsAdapter.history ?? [];
        }

        JsonAdapter {
            id: visitsAdapter
            property var visits: ({})
            property var favorites: []
            property var hidden: []
            property var history: []
        }
    }

    // Inline calculator (omacast row 13). A clear calculation replaces the
    // app results; Enter copies the result.
    readonly property var calc: (root.showHidden || root.webLocked) ? null : Calculator.evaluate(root.query)

    function copyCalc() {
        const c = root.calc;
        if (!c)
            return;
        root.recordHistory(root.query);
        root.save();
        root.copyText(c.copy);
        ToastManager.show("Copied " + c.copy, "\uf0c5");
        root.close();
    }

    // "yt cats": a provider prefix searches that provider directly and, like
    // a calculation, replaces the app results.
    // URLs and existing paths (omacast row 15). Existence of a typed path is
    // checked asynchronously; a row appears only once it is known to exist.
    readonly property string homeDir: Quickshell.env("HOME")
    property var pathInfo: ({ path: "", kind: "" })

    readonly property var loc: {
        if (root.showHidden || root.webLocked || root.calc)
            return null;
        const q = root.query.trim();
        const u = Locations.classifyUrl(q);
        if (u)
            return u;
        if (Locations.isPathLike(q)) {
            const p = Locations.expand(q, root.homeDir);
            if (root.pathInfo.path === p && root.pathInfo.kind)
                return { kind: root.pathInfo.kind, path: p, text: Locations.display(p, root.homeDir) };
        }
        return null;
    }

    onQueryChanged: {
        if (Locations.isPathLike(root.query.trim()))
            pathTimer.restart();
    }

    Timer {
        id: pathTimer

        interval: 100
        onTriggered: {
            if (pathProc.running) {
                pathTimer.restart();
                return;
            }
            pathProc.target = Locations.expand(root.query.trim(), root.homeDir);
            pathProc.running = true;
        }
    }

    Process {
        id: pathProc

        property string target: ""

        command: ["sh", "-c", 'if [ -d "$1" ]; then echo dir; elif [ -e "$1" ]; then echo file; else echo none; fi', "sh", pathProc.target]
        stdout: StdioCollector {
            onStreamFinished: {
                const k = text.trim();
                root.pathInfo = { path: pathProc.target, kind: k === "none" ? "" : k };
            }
        }
    }

    function openLoc() {
        const l = root.loc;
        if (!l)
            return;
        root.recordHistory(root.query);
        root.save();
        if (l.kind === "url")
            Apps.openUrl(l.url);
        else
            Apps.openFile(l.path);
        root.close();
    }

    function activateInline() {
        if (root.calc)
            root.copyCalc();
        else if (root.loc)
            root.openLoc();
        else if (root.web)
            root.openSearch(root.web.provider, root.web.text);
    }

    // While the provider list is open the typed text is a web search term:
    // editing it must not switch to app results or the calculator.
    property bool webLocked: false
    property var lockedProvider: null

    readonly property var webPrefix: (root.showHidden || root.calc || root.webLocked) ? null : WebSearch.parsePrefix(root.query.trim())

    // Web search row: a prefix query, or the default provider when nothing
    // else matched.
    readonly property var web: {
        const q = root.query.trim();
        if (root.webLocked)
            return { provider: root.lockedProvider, text: q, fallback: true };
        if (!q || root.showHidden || root.calc || root.loc)
            return null;
        if (root.webPrefix)
            return root.webPrefix;
        if (Locations.isPathLike(q))
            return null;
        return root.filtered.length === 0 ? { provider: WebSearch.defaultProvider(), text: q, fallback: true } : null;
    }

    // What the row under the pill shows: calculation or web search.
    readonly property var inlineRow: {
        if (root.calc)
            return { title: root.calc.expr, text: "= " + root.calc.text, hint: "copy" };
        if (root.loc)
            return {
                title: root.loc.kind === "url" ? "Open in browser" : (root.loc.kind === "dir" ? "Open folder" : "Open file"),
                text: root.loc.text,
                hint: "open"
            };
        if (root.web)
            return {
                title: root.web.fallback ? root.web.provider.name + "  \u00b7  Ctrl+K for others" : "Search " + root.web.provider.name,
                text: root.web.text,
                hint: "search"
            };
        return null;
    }

    function openSearch(provider, text) {
        if (!text.trim())
            return;
        root.recordHistory(root.query);
        root.save();
        Apps.openUrl(WebSearch.url(provider, text));
        root.close();
    }

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if ((!q && !root.showHidden) || root.calc || root.loc || root.webPrefix || root.webLocked)
            return [];

        const now = Date.now() / 1000;
        const scored = [];
        for (const e of root.candidates) {
            if (root.hidden.includes(e.id) !== root.showHidden)
                continue;
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
        // Pins only outrank other results for real name matches (score >= 500);
        // a weak fuzzy hit on a pinned app must not beat a better match.
        const favRank = x => {
            const i = x.score >= 500 ? root.favorites.indexOf(x.entry.id) : -1;
            return i < 0 ? Infinity : i;
        };
        scored.sort((a, b) => (favRank(a) - favRank(b)) || b.score - a.score || b.frec - a.frec || a.entry.name.localeCompare(b.entry.name));
        return scored.map(s => s.entry);
    }

    function open() {
        root.query = "";
        // searchInput.text isn't bound to root.query, so clear it separately or a
        // stale query lingers on reopen.
        searchInput.text = "";
        root.selectedIndex = 0;
        root.showHidden = false;
        root.actionsOpen = false;
        root.webLocked = false;
        root.historyIndex = -1;
        root.ctrlHeld = false;
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

        function unhideAll(): void {
            root.hidden = [];
            root.save();
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
        if (entry.system)
            return "";
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
        root.recordHistory(root.query);
        root.recordVisit(entry, root.query);
        const addr = forceNew ? "" : root.findWindow(entry);
        if (addr) {
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:${addr}" })`]);
            root.close();
            return;
        }
        if (entry.system) {
            entry.execute();
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

                onTextChanged: {
                    root.query = text;
                    if (root.historyIndex >= 0 && text !== root.history[root.historyIndex])
                        root.historyIndex = -1;
                }

                // All keys are handled in onPressed: Qt emits the specific
                // handlers (onUpPressed, onReturnPressed, ...) first and they
                // would shadow the action panel and Ctrl+Alt+arrow combos.
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const alt = event.modifiers & Qt.AltModifier;
                    const shift = event.modifiers & Qt.ShiftModifier;
                    if (event.key === Qt.Key_Control)
                        root.ctrlHeld = true;
                    if (root.actionsOpen) {
                        if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_K))
                            root.actionsOpen = false;
                        else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N))
                            root.actionIndex = Math.min(root.actionIndex + 1, root.actions.length - 1);
                        else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P))
                            root.actionIndex = Math.max(root.actionIndex - 1, 0);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.runAction(root.actionIndex);
                        else if (root.webLocked)
                            return;
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && !alt && !shift && event.key === Qt.Key_K) {
                        root.openActions();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && !alt && !shift && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        root.launch(event.key - Qt.Key_1, false);
                    } else if (ctrl && !alt && !shift && event.key === Qt.Key_N) {
                        root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1);
                    } else if (ctrl && !alt && !shift && event.key === Qt.Key_P) {
                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                    } else if (ctrl && shift && event.key === Qt.Key_F) {
                        root.toggleFavorite();
                    } else if (alt && shift && event.key === Qt.Key_D) {
                        root.toggleHidden();
                    } else if (alt && shift && event.key === Qt.Key_H) {
                        root.showHidden = !root.showHidden;
                        root.selectedIndex = 0;
                    } else if (ctrl && alt && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                        root.moveFavorite(event.key === Qt.Key_Left ? -1 : 1);
                    } else if (event.key === Qt.Key_Escape) {
                        root.close();
                    } else if (event.key === Qt.Key_Right) {
                        root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1);
                    } else if (event.key === Qt.Key_Left) {
                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                    } else if (event.key === Qt.Key_Down) {
                        root.selectedIndex = Math.min(root.selectedIndex + root.resultColumns, root.filtered.length - 1);
                    } else if (event.key === Qt.Key_Up) {
                        const browsing = root.historyIndex >= 0 && root.selectedIndex < root.resultColumns;
                        if (!root.showHidden && (searchInput.text === "" || browsing))
                            root.historyStep();
                        else
                            root.selectedIndex = Math.max(root.selectedIndex - root.resultColumns, 0);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (ctrl && !root.loc && root.query.trim() !== "")
                            root.openSearch(WebSearch.defaultProvider(), root.query.trim());
                        else if (root.calc || root.loc || root.web)
                            root.activateInline();
                        else
                            root.launch(root.selectedIndex, shift !== 0);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Control)
                        root.ctrlHeld = false;
                }
            }

            Text {
                visible: root.showHidden
                Layout.alignment: Qt.AlignVCenter
                text: root.filtered.length > 0 ? "Hidden apps \u00b7 Alt+Shift+D restores" : "No hidden apps"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                renderType: Text.NativeRendering
            }
        }
    }

    // Reserves room under the pill for the calculator row.
    Item {
        id: belowPill

        anchors.top: pill.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 1
        height: root.inlineRow ? calcRow.height + 12 : 0
    }

    Rectangle {
        id: calcRow

        visible: root.inlineRow !== null
        anchors.top: pill.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.pillWidth
        height: 84
        radius: root.pillHeight / 2.5
        color: Theme.surface1
        border.width: 1
        border.color: Theme.surface2

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateInline()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 20
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.inlineRow ? root.inlineRow.title : ""
                    elide: Text.ElideRight
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: root.inlineRow ? root.inlineRow.text : ""
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 10
                    font.bold: true
                    renderType: Text.NativeRendering
                }
            }

            KeyCaps {
                Layout.alignment: Qt.AlignVCenter
                keys: ["\u21b5"]
                fontSize: root.hintFontSize
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.inlineRow ? root.inlineRow.hint : ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: root.hintFontSize
                renderType: Text.NativeRendering
            }
        }
    }

    Text {
        id: focusedDescription

        visible: root.selectedDescription.length > 0 && !root.actionsOpen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: belowPill.bottom
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

    // ---- Action panel on Ctrl+K (omacast row 10) ----
    property bool actionsOpen: false
    property int actionIndex: 0

    function copyText(text) {
        // Via stdin, not argv-built shell text.
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", text]);
    }

    readonly property var actions: {
        if (root.web) {
            // Captured now: the panel closes (and web may change) before run().
            const text = root.web.text;
            return WebSearch.ordered(root.web.provider.id).map(p => ({
                title: p.name,
                keys: [p.prefix],
                run: () => root.openSearch(p, text)
            }));
        }
        if (root.loc) {
            const l = root.loc;
            const list = [{ title: l.kind === "url" ? "Open in browser" : (l.kind === "dir" ? "Open folder" : "Open file"), keys: ["\u21b5"], run: () => root.openLoc() }];
            if (l.kind !== "url") {
                const dir = l.kind === "dir" ? l.path : (l.path.replace(/\/[^\/]*$/, "") || "/");
                const act = (title, fn) => list.push({ title: title, keys: [], run: () => {
                    fn();
                    root.close();
                } });
                act("Open in terminal", () => Apps.openInTerminal(dir));
                if (Apps.hasYazi)
                    act("Open in yazi", () => Apps.openInYazi(l.path));
                if (l.kind === "file") {
                    act("Open in editor", () => Apps.openInEditor(l.path));
                    act("Open folder in file manager", () => Apps.openFile(dir));
                }
                act("Reveal in file manager", () => Apps.revealInFileManager(l.path));
            }
            list.push({ title: l.kind === "url" ? "Copy URL" : "Copy path", keys: [], run: () => {
                root.copyText(l.kind === "url" ? l.url : l.path);
                root.close();
            } });
            return list;
        }
        const e = root.selectedEntry;
        if (!e)
            return [];
        const hasWindow = !!root.findWindow(e);
        const idx = root.selectedIndex;
        const list = [];
        list.push({ title: hasWindow ? "Focus window" : (e.system ? "Run" : "Open"), keys: ["\u21b5"], run: () => root.launch(idx, false) });
        if (hasWindow)
            list.push({ title: "New window", keys: ["Shift", "\u21b5"], run: () => root.launch(idx, true) });
        for (const a of (e.actions || [])) {
            list.push({ title: a.name, keys: [], run: () => {
                root.recordVisit(e, root.query);
                a.execute();
                root.close();
            } });
        }
        if (!e.runInTerminal && e.command && e.command.length)
            list.push({ title: "Run in terminal", keys: [], run: () => {
                root.recordVisit(e, root.query);
                Apps.runInTerminal(e.command);
                root.close();
            } });
        if (e.command && e.command.length)
            list.push({ title: "Copy command", keys: [], run: () => {
                root.copyText(e.command.join(" "));
                root.close();
            } });
        if (!root.showHidden)
            list.push({ title: root.favorites.includes(e.id) ? "Unpin" : "Pin", keys: ["Ctrl", "Shift", "F"], run: () => root.toggleFavorite() });
        list.push({ title: root.showHidden ? "Restore" : "Hide", keys: ["Alt", "Shift", "D"], run: () => root.toggleHidden() });
        list.push({ title: root.showHidden ? "Back to apps" : "Show hidden apps", keys: ["Alt", "Shift", "H"], run: () => {
            root.showHidden = !root.showHidden;
            root.selectedIndex = 0;
        } });
        return list;
    }

    function openActions() {
        if (!root.selectedEntry && !root.web && !root.loc)
            return;
        root.actionIndex = 0;
        root.lockedProvider = root.web ? root.web.provider : null;
        root.webLocked = !!root.web;
        root.actionsOpen = true;
    }

    onActionsOpenChanged: {
        if (!root.actionsOpen)
            root.webLocked = false;
    }

    function runAction(i) {
        const a = root.actions[i];
        root.actionsOpen = false;
        if (a)
            a.run();
    }

    // Context-sensitive key hints under the results (omacast row 21): rows of
    // { keys: [...], text } rendered as key-cap chips.
    readonly property int hintFontSize: Theme.fontSize + 2
    readonly property var keyHints: {
        const e = root.selectedEntry;
        if (!e)
            return [];
        const open = root.findWindow(e)
            ? [{ keys: ["\u21b5"], text: "focus window" }, { keys: ["Shift", "\u21b5"], text: "new window" }]
            : [{ keys: ["\u21b5"], text: e.system ? "run" : "open" }];
        return [open.concat([{ keys: ["Ctrl", "K"], text: "actions" }])];
    }

    Column {
        visible: resultsPanel.visible && !root.actionsOpen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: resultsPanel.bottom
        anchors.topMargin: 14
        spacing: 8
        opacity: 0.85

        Repeater {
            model: root.keyHints

            Row {
                id: hintRow

                required property var modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 26

                Repeater {
                    model: hintRow.modelData

                    Row {
                        id: hintItem

                        required property var modelData
                        spacing: 8

                        KeyCaps {
                            anchors.verticalCenter: parent.verticalCenter
                            keys: hintItem.modelData.keys
                            fontSize: root.hintFontSize
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hintItem.modelData.text
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: root.hintFontSize
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
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

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.tileIconSize
                        Layout.preferredHeight: root.tileIconSize

                        IconImage {
                            anchors.fill: parent
                            visible: !delegateRoot.modelData.glyph
                            source: Quickshell.iconPath(delegateRoot.modelData.icon, "image-missing")
                        }

                        // System actions have a Nerd Font glyph instead of an icon.
                        Text {
                            anchors.centerIn: parent
                            visible: !!delegateRoot.modelData.glyph
                            text: delegateRoot.modelData.glyph ?? ""
                            color: delegateRoot.modelData.color ?? Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: root.tileIconSize * 0.75
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.nameBlockHeight
                        verticalAlignment: Text.AlignTop
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        text: delegateRoot.modelData.name + (delegateRoot.modelData.active ? " \u2713" : "")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.resultFontSize
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: root.ctrlHeld && !root.actionsOpen && delegateRoot.index < 9
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 16
                    text: delegateRoot.index + 1
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    visible: root.favorites.includes(delegateRoot.modelData.id)
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 16
                    text: "★"
                    color: Theme.yellow
                    font.pixelSize: root.resultFontSize
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (!root.actionsOpen) root.selectedIndex = delegateRoot.index
                    onClicked: mouse => root.launch(delegateRoot.index, (mouse.modifiers & Qt.ShiftModifier) !== 0)
                }
            }
        }
    }

    // Scrim: clicking outside the panel dismisses it.
    MouseArea {
        visible: root.actionsOpen
        anchors.fill: parent
        onClicked: root.actionsOpen = false
    }

    Rectangle {
        id: actionPanel

        visible: root.actionsOpen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: 12
        width: 440
        height: actionColumn.implicitHeight + 16
        radius: Theme.radius
        color: Theme.surface1
        border.width: 1
        border.color: Theme.surface2

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: actionColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8

            Text {
                width: parent.width
                leftPadding: 12
                topPadding: 4
                bottomPadding: 6
                text: root.selectedEntry ? root.selectedEntry.name : (root.web ? "Search the web for \u201c" + root.web.text + "\u201d" : (root.loc ? root.loc.text : ""))
                elide: Text.ElideRight
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.italic: true
                renderType: Text.NativeRendering
            }

            Repeater {
                model: root.actions

                Rectangle {
                    id: actionRow

                    required property var modelData
                    required property int index

                    width: actionColumn.width
                    height: 38
                    radius: Theme.radius / 2
                    color: actionRow.index === root.actionIndex ? Theme.surface2 : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionRow.modelData.title
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        renderType: Text.NativeRendering
                    }

                    KeyCaps {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        keys: actionRow.modelData.keys
                        fontSize: Theme.fontSize - 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.actionIndex = actionRow.index
                        onClicked: root.runAction(actionRow.index)
                    }
                }
            }
        }
    }
}
