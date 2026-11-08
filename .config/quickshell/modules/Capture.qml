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

    function open() {
        root.phase = "hover";
        root.selW = 0;
        root.selH = 0;
        root.windows = [];
        clientsProc.running = true;
        root.visible = true;
        keys.forceActiveFocus();
    }

    function close() {
        root.visible = false;
        clientsProc.running = false;
        cursorProc.running = false;
    }

    PopupBehavior {
        name: "capture"
        popup: root
        focusGrab: false
        openFn: () => root.open()
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

    function capture(x, y, w, h) {
        const gx = Math.round(Math.max(0, x) + root.screen.x);
        const gy = Math.round(Math.max(0, y) + root.screen.y);
        const gw = Math.round(Math.min(w, root.screen.width - Math.max(0, x)));
        const gh = Math.round(Math.min(h, root.screen.height - Math.max(0, y)));
        if (gw < 1 || gh < 1) {
            root.close();
            return;
        }
        root.pendingGeometry = gx + "," + gy + " " + gw + "x" + gh;
        root.close();
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
        onTriggered: grimProc.running = true
    }

    Process {
        id: grimProc
        command: [Quickshell.shellPath("scripts/capture-save.sh"), root.saveDir, root.pendingGeometry]
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
            root.open();
        }

        function screen(): void {
            root.capture(0, 0, root.screen.width, root.screen.height);
        }

        function window(): void {
            activeProc.running = true;
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
            font.pixelSize: Theme.fontSize - 1
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
            font.pixelSize: Theme.fontSize - 1
            text: root.phase === "edit" ? "Enter capture  ·  drag edges to resize  ·  drag inside to move  ·  Esc cancel" : "Click window to capture  ·  drag to select area  ·  Esc cancel"
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
}
