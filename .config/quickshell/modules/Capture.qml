import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Screenshot picker + capture. Full-screen layer-shell overlay:
//   - hover snaps to the window under the cursor; click captures it
//   - drag draws a free selection that stays editable (drag edges/corners
//     to resize, drag inside to move, drag outside to start over)
//   - Enter/Space captures, Esc cancels
// Capture itself shells out to `grim -g` after the overlay is hidden
// (layer surfaces are part of the composited output, so it must be gone
// first), then wl-copy + a notification with a thumbnail. IPC target `capture`:
//   region    open the picker
//   screen    capture the whole output immediately
//   window    capture the focused window immediately
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

    // Cover the bar too, and its reserved zone must not shrink the surface.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property string saveDir: Quickshell.env("HOME") + "/pics/screenshots"
    readonly property int handleSize: 10
    readonly property int minSize: 4

    // Selection rect in surface-local coordinates (== screen-local).
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    readonly property bool hasSel: selW > 0 && selH > 0

    // "hover": selection (if any) is the snapped window under the cursor.
    // "drag": user is drawing a new selection.
    // "edit": a free selection awaits Enter.
    property string phase: "hover"
    property var windows: []

    // "shot": the picker takes a screenshot. "record": it starts a screen
    // recording (Recorder.qml) of the picked area instead.
    property string pickMode: "shot"

    // Follow the focused monitor (falls back to Env.targetScreen()), so the
    // picker and whole-screen/window captures hit the screen in use.
    function retarget() {
        if (root.visible)
            return;
        const name = Hyprland.focusedMonitor?.name;
        const match = name ? Quickshell.screens.find(s => s.name === name) : null;
        root.screen = match ?? Env.targetScreen();
    }

    // Frozen backdrop: the whole output is grabbed before the overlay maps,
    // shown behind the dim, and cropped for the final screenshot (no
    // hide-then-wait delay, and moving content can't change). Screenshots
    // only; if grim fails the picker opens live and captures the old way.
    readonly property string freezeFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-capture-freeze.png"
    property string freezePath: ""
    property bool freezeKeep: false
    property string pendingFreeze: ""
    property string pendingCrop: ""

    // Shot mode: open the annotator (satty) right after capturing instead
    // of showing the notification. Per capture; A toggles it in the picker.
    property bool annotate: false
    property bool pendingAnnotate: false

    function open(mode, annotate) {
        if (freezeProc.running)
            return;
        root.annotate = annotate === true;
        root.retarget();
        root.pickMode = mode ?? "shot";
        root.phase = "hover";
        root.selW = 0;
        root.selH = 0;
        root.windows = [];
        root.freezeKeep = false;
        root.freezePath = "";
        if (root.pickMode === "shot" || root.pickMode === "ocr" || root.pickMode === "qr") {
            freezeProc.running = true;
            return;
        }
        root.showPicker();
    }

    function showPicker() {
        clientsProc.running = true;
        root.visible = true;
        keys.forceActiveFocus();
    }

    Process {
        id: freezeProc
        command: ["grim", "-o", root.screen ? root.screen.name : "", root.freezeFile]
        onExited: code => {
            root.freezePath = code === 0 ? root.freezeFile : "";
            root.showPicker();
        }
    }

    Process {
        id: freezeCleanup
        command: ["rm", "-f", root.freezeFile]
    }

    function close() {
        if (root.freezePath !== "" && !root.freezeKeep)
            freezeCleanup.running = true;
        root.freezePath = "";
        root.visible = false;
        clientsProc.running = false;
        cursorProc.running = false;
    }

    PopupBehavior {
        name: "capture"
        popup: root
        focusGrab: false
        openFn: () => root.open("shot")
    }

    // --- window snapping ---------------------------------------------------

    function windowAt(x, y) {
        for (const w of root.windows) {
            if (x >= w.x && y >= w.y && x < w.x + w.w && y < w.y + w.h)
                return w;
        }
        return null;
    }

    function snapTo(x, y) {
        const w = root.windowAt(x, y);
        if (w) {
            root.selX = w.x;
            root.selY = w.y;
            root.selW = w.w;
            root.selH = w.h;
        } else {
            root.selW = 0;
            root.selH = 0;
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                const sx = root.screen.x;
                const sy = root.screen.y;
                // Topmost first: floating above tiled, then most recently focused.
                // `visible` alone is true for windows on other workspaces too.
                const wsId = Hyprland.monitorFor(root.screen)?.activeWorkspace?.id;
                const wins = list.filter(c => c.mapped && !c.hidden && c.workspace.id === wsId && c.size[0] > 0).map(c => ({
                            x: c.at[0] - sx,
                            y: c.at[1] - sy,
                            w: c.size[0],
                            h: c.size[1],
                            floating: c.floating,
                            fullscreen: c.fullscreen > 0,
                            focusId: c.focusHistoryID
                        }));
                wins.sort((a, b) => (b.fullscreen - a.fullscreen) || (b.floating - a.floating) || (a.focusId - b.focusId));
                root.windows = wins;
                cursorProc.running = true;
            }
        }
    }

    // The pointer doesn't report a position until it moves, so seed the
    // initial hover snap from the compositor's cursor position.
    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.phase !== "hover")
                    return;
                try {
                    const p = JSON.parse(text);
                    root.snapTo(p.x - root.screen.x, p.y - root.screen.y);
                } catch (e) {}
            }
        }
    }

    // --- capture -----------------------------------------------------------

    property string pendingGeometry: ""
    property string pendingRegion: ""

    function capture(x, y, w, h) {
        const gx = Math.round(Math.max(0, x) + root.screen.x);
        const gy = Math.round(Math.max(0, y) + root.screen.y);
        const gw = Math.round(Math.min(w, root.screen.width - Math.max(0, x)));
        const gh = Math.round(Math.min(h, root.screen.height - Math.max(0, y)));
        if (gw < 1 || gh < 1) {
            root.close();
            return;
        }
        const mode = root.pickMode;
        root.pendingAnnotate = root.annotate && mode === "shot";
        root.pendingFreeze = "";
        root.pendingTool = mode === "ocr" || mode === "qr" ? mode : "";
        if ((mode === "shot" || mode === "ocr" || mode === "qr") && root.freezePath !== "" && root.screen.width > 0) {
            const k = freezeImage.implicitWidth / root.screen.width;
            if (k > 0) {
                const cx = Math.round(Math.max(0, x) * k);
                const cy = Math.round(Math.max(0, y) * k);
                root.pendingCrop = Math.round(gw * k) + "x" + Math.round(gh * k) + "+" + cx + "+" + cy;
                root.pendingFreeze = root.freezePath;
                root.freezeKeep = true;
            }
        }
        root.close();
        if (mode === "record") {
            // Same logical-coordinate rect, in gpu-screen-recorder's format.
            // The overlay must be gone before frames are grabbed.
            root.pendingRegion = gw + "x" + gh + "+" + gx + "+" + gy;
            recordDelay.restart();
            return;
        }
        root.pendingGeometry = gx + "," + gy + " " + gw + "x" + gh;
        if (root.pendingFreeze !== "") {
            root.runGrab();
            return;
        }
        // Let the compositor finish unmapping the overlay (and its fade).
        grabDelay.restart();
    }

    function captureSelection() {
        if (root.hasSel)
            root.capture(root.selX, root.selY, root.selW, root.selH);
    }

    Timer {
        id: grabDelay
        interval: 250
        onTriggered: root.runGrab()
    }

    property string pendingTool: ""

    function runGrab() {
        if (root.pendingTool === "ocr")
            ocrProc.running = true;
        else if (root.pendingTool === "qr")
            qrProc.running = true;
        else
            grimProc.running = true;
    }

    // QR pick mode: the decoded payload goes to the clipboard (links also
    // get an Open notification from the script).
    Process {
        id: qrProc
        command: [Quickshell.shellPath("scripts/capture-qr.sh"), root.pendingGeometry, root.pendingFreeze, root.pendingCrop]
        stdout: StdioCollector {
            id: qrOut
        }
        onExited: code => {
            if (code === 2) {
                ToastManager.show("No QR code found", "");
                return;
            }
            if (code !== 0) {
                ToastManager.show("QR scan failed", "");
                return;
            }
            const t = qrOut.text.trim();
            ToastManager.show("QR copied: " + (t.length > 60 ? t.slice(0, 60) + "…" : t), "");
        }
    }

    // OCR pick mode: the selection's text goes to the clipboard.
    Process {
        id: ocrProc
        command: [Quickshell.shellPath("scripts/capture-ocr.sh"), root.pendingGeometry, root.pendingFreeze, root.pendingCrop]
        stdout: StdioCollector {
            id: ocrOut
        }
        onExited: code => {
            if (code === 2) {
                ToastManager.show("No text found", "");
                return;
            }
            if (code !== 0) {
                ToastManager.show("Text capture failed", "");
                return;
            }
            const t = ocrOut.text.trim().replace(/\s+/g, " ");
            ToastManager.show("Text copied: " + (t.length > 60 ? t.slice(0, 60) + "…" : t), "");
        }
    }

    Timer {
        id: recordDelay
        interval: 250
        onTriggered: Recorder.start("region", root.pendingRegion)
    }

    Process {
        id: grimProc
        command: [Quickshell.shellPath("scripts/capture-save.sh"), root.saveDir, root.pendingGeometry, root.pendingFreeze, root.pendingCrop, root.pendingAnnotate ? "1" : ""]
        onExited: code => {
            // Success is announced by the script's notification (Open/Edit actions).
            if (code !== 0)
                ToastManager.show("Screenshot failed", "");
        }
    }

    // IPC `window` needs the focused window's geometry.
    Process {
        id: activeProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text);
                    root.capture(c.at[0] - root.screen.x, c.at[1] - root.screen.y, c.size[0], c.size[1]);
                } catch (e) {
                    ToastManager.show("No focused window", "");
                }
            }
        }
    }

    function request(mode) {
        root.retarget();
        root.pickMode = "shot";
        if (mode === "record-region") {
            if (Recorder.recording)
                Recorder.stop();
            else
                root.open("record");
            return;
        }
        if (mode === "record-screen") {
            Recorder.toggleScreen(root.screen.name);
            return;
        }
        if (mode === "screen")
            root.capture(0, 0, root.screen.width, root.screen.height);
        else if (mode === "window")
            activeProc.running = true;
        else
            root.open();
    }

    // Dashboard tile.
    Connections {
        target: DashboardBridge
        function onCaptureRequested(mode) {
            root.request(mode);
        }
    }

    IpcHandler {
        target: "capture"

        function region(): void {
            root.open("shot");
        }

        // Region picker, then straight into the annotator.
        function annotate(): void {
            root.open("shot", true);
        }

        function screen(): void {
            root.retarget();
            root.annotate = false;
            root.pickMode = "shot";
            root.capture(0, 0, root.screen.width, root.screen.height);
        }

        // Region picker, then OCR the selection into the clipboard.
        function text(): void {
            root.open("ocr");
        }

        // Region picker, then decode a QR code in the selection.
        function qr(): void {
            root.open("qr");
        }

        function window(): void {
            root.retarget();
            root.annotate = false;
            root.pickMode = "shot";
            activeProc.running = true;
        }
    }

    // Screen recording. `region` picks an area (or window) then records;
    // `screen`/`window` start immediately; `stop` finishes and saves;
    // `toggle` stops if recording, else opens the region picker.
    IpcHandler {
        target: "record"

        function region(): void {
            if (Recorder.recording)
                Recorder.stop();
            else
                root.open("record");
        }

        function screen(): void {
            root.retarget();
            Recorder.toggleScreen(root.screen.name);
        }

        function window(): void {
            if (Recorder.recording) {
                Recorder.stop();
                return;
            }
            root.retarget();
            root.pickMode = "record";
            activeProc.running = true;
        }

        function stop(): void {
            Recorder.stop();
        }

        // audio: "off" | "desktop" | "mic" | "both"
        function audio(mode: string): void {
            Recorder.setDesktopAudio(mode === "desktop" || mode === "both");
            Recorder.setMicAudio(mode === "mic" || mode === "both");
        }

        function toggle(): void {
            region();
        }
    }

    // --- UI ----------------------------------------------------------------

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: root.captureSelection()
        Keys.onEnterPressed: root.captureSelection()
        Keys.onSpacePressed: root.captureSelection()
        Keys.onPressed: ev => {
            if (root.pickMode !== "record") {
                if (ev.key === Qt.Key_A && root.pickMode === "shot")
                    root.annotate = !root.annotate;
                return;
            }
            if (ev.key === Qt.Key_D)
                Recorder.setDesktopAudio(!Recorder.desktopAudio);
            else if (ev.key === Qt.Key_M)
                Recorder.setMicAudio(!Recorder.micAudio);
        }
    }

    Image {
        id: freezeImage
        anchors.fill: parent
        visible: root.freezePath !== ""
        source: root.freezePath !== "" ? "file://" + root.freezePath : ""
        cache: false
        smooth: true
    }

    function hint() {
        const edit = root.phase === "edit";
        const verb = root.pickMode === "record" ? "record" : root.pickMode === "ocr" ? "copy text" : root.pickMode === "qr" ? "scan QR" : "capture";
        let h = edit ? "Enter " + verb + "  ·  drag edges to resize  ·  drag inside to move" : "Click window to " + verb + "  ·  drag to select area";
        if (root.pickMode === "record")
            h += "  ·  D/M audio";
        else if (root.pickMode === "shot")
            h += "  ·  A annotate" + (root.annotate ? " ✓" : "");
        return h + "  ·  Esc cancel";
    }

    readonly property color dimColor: Qt.rgba(0, 0, 0, 0.5)

    // Dim: four rects around the hole (the whole surface when no selection).
    Rectangle {
        color: root.dimColor
        x: 0
        y: 0
        width: root.width
        height: root.hasSel ? root.selY : root.height
    }
    Rectangle {
        visible: root.hasSel
        color: root.dimColor
        x: 0
        y: root.selY + root.selH
        width: root.width
        height: root.height - y
    }
    Rectangle {
        visible: root.hasSel
        color: root.dimColor
        x: 0
        y: root.selY
        width: root.selX
        height: root.selH
    }
    Rectangle {
        visible: root.hasSel
        color: root.dimColor
        x: root.selX + root.selW
        y: root.selY
        width: root.width - x
        height: root.selH
    }

    Rectangle {
        visible: root.hasSel
        color: "transparent"
        border.color: Theme.blue
        border.width: 2
        x: root.selX - 2
        y: root.selY - 2
        width: root.selW + 4
        height: root.selH + 4
    }

    // Corner/edge handles while the selection is editable.
    Repeater {
        model: root.phase === "edit" && root.hasSel ? [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]] : []

        Rectangle {
            required property var modelData
            width: 8
            height: 8
            radius: 2
            color: Theme.blue
            x: root.selX + root.selW * modelData[0] - 4
            y: root.selY + root.selH * modelData[1] - 4
        }
    }

    // Size badge: just outside the selection (below, else above, else inside).
    Rectangle {
        visible: root.hasSel
        color: Theme.base
        border.color: Theme.surface2
        radius: 8
        width: badgeText.implicitWidth + 16
        height: badgeText.implicitHeight + 8
        x: Math.max(4, Math.min(root.selX, root.width - width - 4))
        y: {
            const below = root.selY + root.selH + 8;
            if (below + height < root.height)
                return below;
            const above = root.selY - height - 8;
            return above >= 0 ? above : root.selY + 8;
        }

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: Math.round(root.selW) + " × " + Math.round(root.selH)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.small(-1)
            font.weight: Theme.smallWeight
            renderType: Text.NativeRendering
        }
    }

    // Hint line.
    Rectangle {
        color: Theme.base
        border.color: Theme.surface2
        radius: Theme.radius
        width: hintText.implicitWidth + 28
        height: hintText.implicitHeight + 14
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - 36

        Text {
            id: hintText
            anchors.centerIn: parent
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.small(-1)
            font.weight: Theme.smallWeight
            renderType: Text.NativeRendering
            text: root.hint()
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.CrossCursor

        // Press-time snapshot for drag operations.
        property string op: ""
        property real px: 0
        property real py: 0
        property real ox: 0
        property real oy: 0
        property real ow: 0
        property real oh: 0
        property bool eLeft: false
        property bool eRight: false
        property bool eTop: false
        property bool eBottom: false
        property bool moved: false

        function hit(x, y) {
            const h = root.handleSize;
            const nearL = Math.abs(x - root.selX) <= h;
            const nearR = Math.abs(x - (root.selX + root.selW)) <= h;
            const nearT = Math.abs(y - root.selY) <= h;
            const nearB = Math.abs(y - (root.selY + root.selH)) <= h;
            const inX = x >= root.selX - h && x <= root.selX + root.selW + h;
            const inY = y >= root.selY - h && y <= root.selY + root.selH + h;
            eLeft = inY && nearL;
            eRight = inY && nearR && !nearL;
            eTop = inX && nearT;
            eBottom = inX && nearB && !nearT;
            if (eLeft || eRight || eTop || eBottom)
                return "resize";
            if (x >= root.selX && x <= root.selX + root.selW && y >= root.selY && y <= root.selY + root.selH)
                return "move";
            return "new";
        }

        onPressed: ev => {
            px = ev.x;
            py = ev.y;
            ox = root.selX;
            oy = root.selY;
            ow = root.selW;
            oh = root.selH;
            moved = false;
            eLeft = eRight = eTop = eBottom = false;
            op = (root.phase === "edit" && root.hasSel) ? hit(ev.x, ev.y) : "new";
        }

        onPositionChanged: ev => {
            if (!pressed) {
                if (root.phase === "hover")
                    root.snapTo(ev.x, ev.y);
                return;
            }
            const dx = ev.x - px;
            const dy = ev.y - py;
            if (!moved && Math.abs(dx) < 3 && Math.abs(dy) < 3)
                return;
            moved = true;

            if (op === "new") {
                root.phase = "drag";
                root.selX = Math.max(0, Math.min(px, ev.x));
                root.selY = Math.max(0, Math.min(py, ev.y));
                root.selW = Math.min(root.width, Math.max(px, ev.x)) - root.selX;
                root.selH = Math.min(root.height, Math.max(py, ev.y)) - root.selY;
            } else if (op === "move") {
                root.selX = Math.max(0, Math.min(root.width - ow, ox + dx));
                root.selY = Math.max(0, Math.min(root.height - oh, oy + dy));
            } else if (op === "resize") {
                let x1 = ox;
                let y1 = oy;
                let x2 = ox + ow;
                let y2 = oy + oh;
                const cx = Math.max(0, Math.min(root.width, ev.x));
                const cy = Math.max(0, Math.min(root.height, ev.y));
                if (eLeft)
                    x1 = cx;
                if (eRight)
                    x2 = cx;
                if (eTop)
                    y1 = cy;
                if (eBottom)
                    y2 = cy;
                // Dragging an edge past its opposite flips the rect.
                root.selX = Math.min(x1, x2);
                root.selY = Math.min(y1, y2);
                root.selW = Math.abs(x2 - x1);
                root.selH = Math.abs(y2 - y1);
            }
        }

        onReleased: ev => {
            if (!moved) {
                // Plain click: capture the snapped window, or ignore a click
                // on an empty spot / inside an editable selection.
                if (root.phase === "hover" && root.hasSel)
                    root.captureSelection();
                else if (root.phase === "edit" && op === "new") {
                    root.phase = "hover";
                    root.snapTo(ev.x, ev.y);
                }
                return;
            }
            if (root.hasSel && root.selW >= root.minSize && root.selH >= root.minSize)
                root.phase = "edit";
            else {
                root.phase = "hover";
                root.snapTo(ev.x, ev.y);
            }
        }
    }

    // Audio source toggles, record mode only. Declared after the full-screen
    // MouseArea so they sit above it and receive clicks.
    Row {
        visible: root.pickMode === "record"
        spacing: 8
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 36 - 40 - height - 8

        Repeater {
            model: [
                {
                    label: "Desktop audio (D)",
                    on: Recorder.desktopAudio,
                    toggle: () => Recorder.setDesktopAudio(!Recorder.desktopAudio)
                },
                {
                    label: "Microphone (M)",
                    on: Recorder.micAudio,
                    toggle: () => Recorder.setMicAudio(!Recorder.micAudio)
                }
            ]

            Rectangle {
                required property var modelData
                radius: Theme.radius
                color: modelData.on ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.25) : Theme.base
                border.color: modelData.on ? Theme.red : Theme.surface2
                width: chipText.implicitWidth + 28
                height: chipText.implicitHeight + 14

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: (modelData.on ? "● " : "○ ") + modelData.label
                    color: modelData.on ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-1)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.toggle()
                }
            }
        }
    }
}
