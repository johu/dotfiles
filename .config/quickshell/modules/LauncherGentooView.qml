import QtQuick
import Quickshell
import Quickshell.Io
import "GentooParse.js" as P

// Gentoo view of the launcher: an overview of six cards (Sync, Updates, Build, News,
// Statistics, Housekeeping) and one drill-in page per card. Read-only: whatever needs
// root (emerge, eclean-dist, dispatch-conf) is handed to a terminal. Data comes from
// scripts/gentoo.py and from PortageUpdates (the pretend run and the live build state,
// so there is no second poller). Same contract as the other views.
Item {
    id: view

    property int textRender: Text.NativeRendering
    // Handed to the page components (a property named "root" would shadow Launcher.qml's root in the
    // onCloseRequested / onLeaveRequested handlers).
    readonly property var host: view

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 2000
    readonly property int preferredHeight: 1100

    // Fixture mode (tests): helper output comes from fixtureDir/*.json, the pretend text
    // from fixturePretend, build state from the build fixture, and actions are only logged
    // as GENTOO-ACTION lines.
    property bool fixture: false
    property string fixtureDir: ""
    property string fixturePretend: ""

    // "overview" | "sync" | "updates" | "build" | "news" | "housekeeping" | "stats"
    // plus the text sub-pages "conflict", "security", "buildlog"
    property string page: "overview"
    property int sel: 0
    property double nowMs: Date.now()

    readonly property string helper: Quickshell.shellPath("scripts/gentoo.py")
    readonly property var base: ["python3", "-I", view.helper].concat(view.fixture ? ["--fixture", view.fixtureDir] : [])

    readonly property color dim: GentooStyle.dim

    onTextRenderChanged: GentooStyle.textRender = view.textRender

    // ---- data ----
    readonly property var syncD: Object.assign(({ timerActive: false, interval: "", first: "", nextEpoch: 0, lastTriggerEpoch: 0, service: "", result: "", gamemode: false, paused: false, emergeRunning: false, lastSyncEpoch: 0, repos: [], runs: [] }), syncJ.data ?? ({}))
    readonly property var newsD: Object.assign(({ items: [], unread: 0, read: 0, hidden: 0 }), newsJ.data ?? ({}))
    readonly property var buildD: Object.assign(({ running: false, session: [], current: null, logPath: "", logTail: [], average: ({}), makeopts: "", emergeProcs: 0, load: 0, recent: [], todayCount: 0, todaySince: 0 }), buildJ.data ?? ({}))
    readonly property var hkD: Object.assign(({ cfgCount: 0, cfgFiles: [], depclean: ({ world: 0, system: 0, required: 0, remove: 0, packages: [] }), distfiles: ({ files: 0, reclaimBytes: 0, totalBytes: 0 }), binpkgs: ({ clean: true, reclaimBytes: 0, files: 0 }), notInTree: [], kernels: ({ running: "", latest: "", list: [], reboot: false }), failed: [], tmpdir: "/var/tmp/portage", checkedEpoch: 0 }), hkJ.data ?? ({}))
    readonly property var statsD: Object.assign(({ installed: 0, installedByRepo: [], treeByRepo: [], treeTotal: 0, eapiInstalled: [], eapiTree: [], categories: [], slowest: [], checkedEpoch: 0 }), statsJ.data ?? ({}))
    readonly property var liveD: Object.assign(({ items: [] }), liveJ.data ?? ({}))
    readonly property var flatpakD: Object.assign(({ available: true, installed: 0, updates: [], checkedEpoch: 0 }), flatpakJ.data ?? ({}))
    readonly property var glsaD: Object.assign(({ affected: [], checkedEpoch: 0 }), glsaJ.data ?? ({}))

    readonly property string pretendText: view.fixture ? view.fixturePretend : PortageUpdates.pretendText
    readonly property int pretendEpoch: view.fixture ? (view.fixturePretend !== "" ? Math.floor(Date.now() / 1000) - 3400 : 0) : PortageUpdates.pretendEpoch
    readonly property bool pretendBusy: view.fixture ? false : PortageUpdates.checking
    readonly property var pretend: P.parsePretend(view.pretendText)
    readonly property bool emergeRunning: view.fixture ? view.buildD.running : PortageUpdates.emergeRunning
    readonly property bool paused: view.syncD.paused
    readonly property bool haveCore: Dependencies.has("portageq")

    readonly property int unreadNews: view.newsD.unread
    readonly property bool securityAffected: view.glsaD.affected.length > 0

    function ageText(epoch) {
        return P.ageText(epoch, view.nowMs);
    }

    function refresh() {
        view.reloadAll(true);
    }

    function reloadAll(force) {
        syncJ.reload();
        newsJ.reload();
        buildJ.reload();
        hkJ.reload(force ? ["--refresh"] : []);
        statsJ.reload(force ? ["--refresh"] : []);
        glsaJ.reload(force ? ["--refresh"] : []);
        liveJ.reload(force ? ["--refresh"] : []);
        flatpakJ.reload(force ? ["--refresh"] : []);
        if (!view.fixture && !PortageUpdates.checking && (force || PortageUpdates.pretendEpoch === 0))
            PortageUpdates.check();
    }

    Component.onCompleted: {
        GentooStyle.textRender = view.textRender;
        view.reloadAll(false);
    }

    GentooJson {
        id: syncJ
        base: view.base
        args: ["sync"]
    }

    GentooJson {
        id: newsJ
        base: view.base
        args: ["news"]
    }

    GentooJson {
        id: buildJ
        base: view.base
        args: ["build"]
    }

    GentooJson {
        id: hkJ
        base: view.base
        args: ["housekeeping"]
    }

    GentooJson {
        id: statsJ
        base: view.base
        args: ["stats"]
    }

    GentooJson {
        id: liveJ
        base: view.base
        args: ["live"]
    }

    GentooJson {
        id: flatpakJ
        base: view.base
        args: ["flatpak"]
    }

    GentooJson {
        id: glsaJ
        base: view.base
        args: ["glsa"]
    }

    GentooJson {
        id: textJ
        base: view.base
        property string kind: ""
        onDone: {
            view.textBody = (textJ.data?.text ?? "");
            view.textPath = (textJ.data?.path ?? "");
        }
    }

    // body of the text sub-pages (advisory text, build log)
    property string textBody: ""
    property string textTitle: ""
    property string textPath: ""

    function openText(kind, title, args) {
        view.textBody = "";
        view.textPath = "";
        view.textTitle = title;
        textJ.args = args;
        textJ.reload();
        view.page = kind;
    }

    function openRaw(kind, title, text) {
        view.textPath = "";
        view.textTitle = title;
        view.textBody = text;
        view.page = kind;
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: view.nowMs = Date.now()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: syncJ.reload()
    }

    // live build: poll only while emerge runs
    Timer {
        interval: 3000
        running: view.emergeRunning && !view.fixture
        repeat: true
        onTriggered: buildJ.reload()
    }

    Connections {
        target: PortageUpdates
        enabled: !view.fixture

        function onEmergeRunningChanged() {
            buildJ.reload();
            syncJ.reload();
        }

        function onLastSyncEpochChanged() {
            syncJ.reload();
        }
    }

    // ---- actions ----
    function toast(text) {
        if (view.fixture)
            console.log("GENTOO-TOAST " + text);
        ToastManager.show(text, "");
    }

    // Root actions (emerge, eclean, dispatch-conf, ...) are typed into herdr's "emerge" tab, the same
    // place portage-sync.sh uses (hypr/scripts/herdr-emerge-run.sh starts herdr when needed, focuses
    // the tab and refuses while another portage / flatpak process runs).
    readonly property string runScript: Quickshell.env("HOME") + "/.config/hypr/scripts/herdr-emerge-run.sh"

    function inTerminal(cmd) {
        if (view.fixture) {
            console.log("GENTOO-ACTION terminal: " + cmd);
            return;
        }
        if (runProc.running)
            return;
        runProc.command = ["bash", view.runScript, cmd];
        runProc.running = true;
    }

    Process {
        id: runProc

        stderr: StdioCollector {
            id: runErr
        }
        onExited: code => {
            if (code === 0) {
                view.closeRequested();
            } else if (code === 3) {
                view.toast("Busy, not started: " + runErr.text.replace(/^busy: /, "").trim());
            } else {
                view.toast("Could not reach the herdr emerge tab" + (runErr.text.trim() !== "" ? ": " + runErr.text.trim().split("\n").pop() : ""));
            }
        }
    }

    function openInNvim(path) {
        if (view.fixture) {
            console.log("GENTOO-ACTION nvim " + path);
            return;
        }
        Apps.runInTerminal(["nvim", "-R", path]);
        view.closeRequested();
    }

    function syncNow() {
        if (view.syncD.paused) {
            view.toast("Sync is paused, press p to resume");
            return;
        }
        if (view.syncD.gamemode) {
            view.toast("Game mode is on, the sync would be skipped");
            return;
        }
        if (view.emergeRunning) {
            view.toast("An emerge is running, the sync would be skipped");
            return;
        }
        if (view.fixture) {
            console.log("GENTOO-ACTION sync-now");
            return;
        }
        actionProc.command = view.base.concat(["sync-now"]);
        actionProc.after = "Sync started, output is in the emerge tab";
        actionProc.running = true;
    }

    function togglePause() {
        if (view.fixture) {
            console.log("GENTOO-ACTION pause");
            return;
        }
        actionProc.command = view.base.concat(["pause", "toggle"]);
        actionProc.after = "";
        actionProc.running = true;
    }

    function markNews(op, ids) {
        if (view.fixture) {
            console.log("GENTOO-ACTION news " + op + " " + ids.join(" "));
            return;
        }
        actionProc.command = view.base.concat(["news-mark", op], ids);
        actionProc.after = "";
        actionProc.running = true;
    }

    Process {
        id: actionProc

        property string after: ""

        stdout: StdioCollector {
        }
        onExited: {
            if (actionProc.after !== "")
                view.toast(actionProc.after);
            syncJ.reload();
            newsJ.reload();
        }
    }

    // ---- navigation ----
    readonly property var parentPage: ({ conflict: "updates", security: "updates", buildlog: "build" })

    function openPage(name) {
        view.page = name;
    }

    function handleEscape() {
        if (pageLoader.item && pageLoader.item.handleEscape && pageLoader.item.handleEscape())
            return true;
        if (view.page === "overview")
            return false;
        view.page = view.parentPage[view.page] ?? "overview";
        return true;
    }

    readonly property var hints: pageLoader.item ? pageLoader.item.hints : []

    function handleKey(event) {
        if (!view.haveCore)
            return event.key === Qt.Key_Q ? (view.leaveRequested(), true) : false;
        if (pageLoader.item && pageLoader.item.handleKey(event))
            return true;
        switch (event.key) {
        case Qt.Key_R:
            view.refresh();
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    // ---- header ----
    readonly property var pageTitles: ({ sync: "Sync", updates: "Updates", build: "Build", news: "News", housekeeping: "Housekeeping", stats: "Statistics", conflict: "Dependency conflict", security: "Security advisory", buildlog: "Build log" })

    Image {
        id: logo

        x: 0
        y: 6
        width: 46
        height: 46
        source: Quickshell.shellPath("assets/gentoo-logo.svg")
        sourceSize: Qt.size(92, 92)
        fillMode: Image.PreserveAspectFit
        opacity: 0.85
    }

    GText {
        visible: view.page !== "overview"
        x: logo.width + 14
        y: 6
        height: 46
        text: "›"
        color: view.dim
        size: Theme.fontSize + 12
    }

    GText {
        visible: view.page !== "overview"
        x: logo.width + 48
        y: 6
        height: 46
        text: view.pageTitles[view.page] ?? ""
        color: Theme.text
        size: Theme.fontSize + 12
        strong: true
    }

    GText {
        x: Math.round(parent.width * 0.4)
        y: 6
        width: Math.round(parent.width * 0.6)
        height: 46
        horizontalAlignment: Text.AlignRight
        text: pageLoader.item?.note ?? ""
        color: view.dim
        size: Theme.fontSize
    }

    Loader {
        id: pageLoader

        x: 0
        y: 66
        width: view.width
        height: view.height - 66
        active: view.haveCore
        sourceComponent: ({ overview: overviewC, sync: syncC, updates: updatesC, build: buildC, news: newsC, housekeeping: hkC, stats: statsC, conflict: textC, security: textC, buildlog: textC })[view.page] ?? overviewC
    }

    Component {
        id: overviewC

        GentooOverview {
            view: host
        }
    }

    Component {
        id: syncC

        GentooSyncPage {
            view: host
        }
    }

    Component {
        id: updatesC

        GentooUpdatesPage {
            view: host
        }
    }

    Component {
        id: buildC

        GentooBuildPage {
            view: host
        }
    }

    Component {
        id: newsC

        GentooNewsPage {
            view: host
        }
    }

    Component {
        id: hkC

        GentooHousekeepingPage {
            view: host
        }
    }

    Component {
        id: statsC

        GentooStatsPage {
            view: host
        }
    }

    Component {
        id: textC

        GentooTextPage {
            view: host
        }
    }

    EmptyState {
        visible: !view.haveCore
        anchors.centerIn: parent
        illustration: "keys.svg"
        title: "Portage not found"
        hint: Dependencies.why("portageq")
        textRender: view.textRender
    }
}
