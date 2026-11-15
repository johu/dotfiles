import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio mixer view of the launcher: output devices, playing apps, input
// devices and recording apps in one keyboard-driven list. j / k pick a row,
// h / l change its volume, m mutes, Enter makes a device the default or (for
// an app) moves its stream to another output. Same contract as the other
// views; fixed geometry so nothing shifts while volumes change.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1700
    readonly property int preferredHeight: 1000

    // ---- data ----
    // Flat list of { type: "header" | "empty" | "node", key, ... }. Rebuilt
    // only when the set of nodes or their names change: volumes and mute are
    // read live by the delegates, so a Discord call churning properties does
    // not rebuild the list.
    property var rows: []
    property string selectedKey: ""

    function appIdentity(n) {
        const p = n.properties ?? {};
        const bin = p["application.process.binary"] || "";
        const name = bin || p["application.name"] || n.description || n.name;
        const pid = p["application.process.id"] ?? "";
        const steamName = pid ? SteamGameIcon.gameNameForPid(pid) : "";
        const key = bin || name;
        return {
            name: steamName || name,
            iconName: (key ? AppIconResolver.iconNameForBinary(key) : "") || (p["application.icon-name"] ?? ""),
            steamPath: pid ? SteamGameIcon.iconPathForPid(pid) : ""
        };
    }

    function deviceName(n) {
        return n.description || n.nickname || n.name;
    }

    function refresh() {
        const sinks = [], apps = [], sources = [], recs = [];
        for (const n of Pipewire.nodes.values) {
            const cls = n.properties?.["media.class"];
            if (!cls || !n.audio)
                continue;
            // The shell's own visualizer (the bar pill and the media view run cava)
            // is not a recording the user cares about.
            if (cls === "Stream/Input/Audio" && n.properties?.["application.name"] === "cava")
                continue;
            if (cls === "Audio/Sink")
                sinks.push({ type: "node", kind: "sink", key: "n" + n.id, node: n, name: view.deviceName(n), iconName: "", steamPath: "" });
            else if (cls === "Audio/Source")
                sources.push({ type: "node", kind: "source", key: "n" + n.id, node: n, name: view.deviceName(n), iconName: "", steamPath: "" });
            else if (cls === "Stream/Output/Audio")
                apps.push(Object.assign({ type: "node", kind: "app", key: "n" + n.id, node: n }, view.appIdentity(n)));
            else if (cls === "Stream/Input/Audio")
                recs.push(Object.assign({ type: "node", kind: "rec", key: "n" + n.id, node: n }, view.appIdentity(n)));
        }
        const byName = (a, b) => a.name.localeCompare(b.name);
        apps.sort(byName);
        recs.sort(byName);
        const out = [{ type: "header", key: "h-sink", title: "Output devices" }].concat(sinks);
        out.push({ type: "header", key: "h-app", title: "Playing" });
        if (apps.length > 0)
            out.push(...apps);
        else
            out.push({ type: "empty", key: "e-app", title: "No apps playing" });
        out.push({ type: "header", key: "h-source", title: "Input devices" });
        out.push(...sources);
        if (recs.length > 0) {
            out.push({ type: "header", key: "h-rec", title: "Recording" });
            out.push(...recs);
        }
        const sig = r => r.map(x => x.key + "|" + (x.name ?? x.title) + "|" + (x.iconName ?? "") + "|" + (x.steamPath ?? "")).join("\n");
        if (sig(out) !== sig(view.rows))
            view.rows = out;
        view.ensureSelection();
    }

    readonly property var nodeRows: view.rows.filter(r => r.type === "node")
    readonly property int selectedRowIndex: view.rows.findIndex(r => r.key === view.selectedKey)
    readonly property var selected: view.selectedRowIndex >= 0 ? view.rows[view.selectedRowIndex] : null

    function ensureSelection() {
        if (view.selected)
            return;
        view.selectedKey = view.nodeRows.length > 0 ? view.nodeRows[0].key : "";
    }

    function moveSelection(delta) {
        const list = view.nodeRows;
        if (list.length === 0)
            return;
        const i = list.findIndex(r => r.key === view.selectedKey);
        view.selectedKey = list[Math.max(0, Math.min(list.length - 1, (i < 0 ? 0 : i) + delta))].key;
    }

    function selectEdge(last) {
        const list = view.nodeRows;
        if (list.length > 0)
            view.selectedKey = list[last ? list.length - 1 : 0].key;
    }

    Component.onCompleted: view.refresh()

    Connections {
        target: Pipewire.nodes

        function onValuesChanged() {
            view.refresh();
        }
    }

    Connections {
        target: SteamGameIcon

        function onCacheChanged() {
            view.refresh();
        }
    }

    // A node whose properties turn valid after the list was built must not stay
    // filtered out (see AudioMixer.qml).
    Instantiator {
        model: Pipewire.nodes.values

        delegate: Item {
            required property var modelData

            Connections {
                target: modelData

                function onReadyChanged() {
                    view.refresh();
                }

                function onPropertiesChanged() {
                    view.refresh();
                }
            }
        }
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // ---- actions ----
    function isDefault(row) {
        if (!row)
            return false;
        if (row.kind === "sink")
            return Pipewire.defaultAudioSink === row.node;
        if (row.kind === "source")
            return Pipewire.defaultAudioSource === row.node;
        return false;
    }

    function setVolume(row, value) {
        if (!row?.node?.audio)
            return;
        row.node.audio.volume = Math.max(0, Math.min(1, value));
        if (value > 0 && row.node.audio.muted)
            row.node.audio.muted = false;
    }

    function changeVolume(delta) {
        const row = view.selected;
        if (row?.node?.audio)
            view.setVolume(row, row.node.audio.volume + delta);
    }

    function toggleMute() {
        const a = view.selected?.node?.audio;
        if (a)
            a.muted = !a.muted;
    }

    property string toastText: ""

    function toast(text) {
        view.toastText = text;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer

        interval: 2200
        onTriggered: view.toastText = ""
    }

    // Move mode: pick the output for the selected app's stream.
    property bool moving: false
    property int moveIndex: 0
    readonly property var sinkRows: view.rows.filter(r => r.kind === "sink")

    function activate() {
        const row = view.selected;
        if (!row)
            return;
        if (row.kind === "sink" || row.kind === "source") {
            Quickshell.execDetached(["pactl", row.kind === "sink" ? "set-default-sink" : "set-default-source", row.node.name]);
            view.toast((row.kind === "sink" ? "Default output: " : "Default input: ") + row.name);
        } else if (row.kind === "app" && view.sinkRows.length > 0) {
            const cur = view.sinkRows.findIndex(r => view.isDefault(r));
            view.moveIndex = Math.max(0, cur);
            view.moving = true;
        }
    }

    function confirmMove() {
        const row = view.selected;
        const target = view.sinkRows[view.moveIndex];
        view.moving = false;
        if (!row || !target)
            return;
        const serial = row.node.properties?.["object.serial"];
        if (serial === undefined)
            return;
        Quickshell.execDetached(["pactl", "move-sink-input", String(serial), target.node.name]);
        view.toast(row.name + " → " + target.name);
    }

    function handleEscape() {
        if (view.moving) {
            view.moving = false;
            return true;
        }
        return false;
    }

    // ---- keys ----
    readonly property var hints: {
        if (view.moving)
            return [[{ keys: ["j", "k"], text: "choose output" }, { keys: ["↵"], text: "move" }, { keys: ["Esc"], text: "cancel" }]];
        const k = view.selected ? view.selected.kind : "";
        return [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["h", "l"], text: "volume" },
                { keys: ["H", "L"], text: "fine" },
                { keys: ["0-9"], text: "set" },
                { keys: ["m"], text: "mute" },
                { keys: ["↵"], text: k === "app" ? "move to output" : "make default", slot: "move to output", ghost: k === "rec" },
                { keys: ["q"], text: "close" }
            ]];
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (view.moving) {
            switch (event.key) {
            case Qt.Key_J:
            case Qt.Key_Down:
                view.moveIndex = Math.min(view.sinkRows.length - 1, view.moveIndex + 1);
                return true;
            case Qt.Key_K:
            case Qt.Key_Up:
                view.moveIndex = Math.max(0, view.moveIndex - 1);
                return true;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                view.confirmMove();
                return true;
            case Qt.Key_Q:
                view.moving = false;
                return true;
            }
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            view.moveSelection(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.moveSelection(-1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.moveSelection(4);
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.moveSelection(-4);
            return true;
        case Qt.Key_G:
            view.selectEdge(shift);
            return true;
        case Qt.Key_H:
        case Qt.Key_Left:
            view.changeVolume(shift ? -0.01 : -0.05);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            view.changeVolume(shift ? 0.01 : 0.05);
            return true;
        case Qt.Key_M:
            view.toggleMute();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            view.activate();
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9 && !ctrl) {
            // 1..9 = 10..90 %, 0 = 100 %
            const d = event.key - Qt.Key_0;
            view.setVolume(view.selected, d === 0 ? 1 : d / 10);
            return true;
        }
        return false;
    }

    // ---- layout ----
    readonly property int rowH: 60
    readonly property int headerH: 56
    readonly property int sliderX: 720
    readonly property int sliderW: view.width - view.sliderX - 330
    readonly property int pctX: view.sliderX + view.sliderW + 20
    readonly property int badgeX: view.pctX + 96

    Text {
        x: 0
        y: 0
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Audio"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    Text {
        x: view.width - width
        y: 0
        width: 600
        height: 52
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: view.toastText
        color: Theme.yellow
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        elide: Text.ElideLeft
        renderType: view.textRender
    }

    ListView {
        id: list

        x: 0
        y: 64
        width: view.width
        height: view.height - 64
        clip: true
        spacing: 4
        model: view.rows
        currentIndex: view.selectedRowIndex
        onCurrentIndexChanged: if (list.currentIndex >= 0)
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool isNode: modelData.type === "node"
            readonly property bool sel: modelData.key === view.selectedKey
            readonly property var audio: isNode ? modelData.node.audio : null
            readonly property real vol: audio ? audio.volume : 0
            readonly property bool muted: audio ? audio.muted : false
            readonly property bool isDef: view.isDefault(modelData)

            width: list.width
            height: modelData.type === "header" ? view.headerH : (modelData.type === "empty" ? 44 : view.rowH)

            // section header
            Item {
                visible: modelData.type === "header"
                anchors.fill: parent

                Text {
                    x: 6
                    y: 20
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.title ?? ""
                    color: Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    renderType: view.textRender
                }

                Rectangle {
                    x: 0
                    y: parent.height - 3
                    width: parent.width
                    height: 1
                    color: Theme.surface2
                }
            }

            Text {
                visible: modelData.type === "empty"
                x: 80
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: modelData.title ?? ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.italic: true
                renderType: view.textRender
            }

            // device / app row
            Rectangle {
                visible: row.isNode
                anchors.fill: parent
                radius: 14
                color: row.sel ? Theme.surface2 : "transparent"
                opacity: row.muted ? 0.55 : 1

                // icon
                Item {
                    x: 20
                    y: (parent.height - height) / 2
                    width: 38
                    height: 38

                    Image {
                        visible: row.isNode && modelData.steamPath !== ""
                        anchors.fill: parent
                        sourceSize: Qt.size(76, 76)
                        fillMode: Image.PreserveAspectFit
                        source: row.isNode && modelData.steamPath ? "file://" + modelData.steamPath : ""
                    }

                    ResolvedIcon {
                        visible: row.isNode && modelData.steamPath === "" && modelData.iconName !== ""
                        anchors.centerIn: parent
                        size: 38
                        iconSource: row.isNode && modelData.iconName ? "image://icon/" + modelData.iconName : ""
                    }

                    Text {
                        visible: row.isNode && modelData.steamPath === "" && modelData.iconName === ""
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.kind === "sink" ? "\uf028" : (modelData.kind === "source" || modelData.kind === "rec" ? "\uf130" : "\uf001")
                        color: row.sel ? Theme.text : Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        renderType: view.textRender
                    }
                }

                Text {
                    x: 80
                    width: view.sliderX - 100
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: row.isNode ? modelData.name : ""
                    color: row.sel ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: row.sel
                    elide: Text.ElideRight
                    renderType: view.textRender
                }

                // slider
                Rectangle {
                    id: track

                    x: view.sliderX
                    y: (parent.height - height) / 2
                    width: view.sliderW
                    height: 10
                    radius: 5
                    color: Theme.surface1

                    Rectangle {
                        width: parent.width * Math.min(1, row.vol)
                        height: parent.height
                        radius: parent.radius
                        color: row.muted ? Theme.subtext1 : (row.sel ? Theme.blue : Theme.teal)
                    }

                    Rectangle {
                        x: parent.width * Math.min(1, row.vol) - width / 2
                        y: (parent.height - height) / 2
                        width: 18
                        height: 18
                        radius: 9
                        color: row.sel ? Theme.text : Theme.subtext1
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -14
                        anchors.bottomMargin: -14
                        onPressed: mouse => {
                            view.selectedKey = modelData.key;
                            view.setVolume(modelData, mouse.x / width);
                        }
                        onPositionChanged: mouse => {
                            if (pressed)
                                view.setVolume(modelData, mouse.x / width);
                        }
                    }
                }

                Text {
                    x: view.pctX
                    width: 76
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: Math.round(row.vol * 100) + " %"
                    color: row.sel ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    renderType: view.textRender
                }

                // badges: muted glyph, default chip (fixed slots)
                Text {
                    visible: row.muted
                    x: view.badgeX
                    width: 36
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "\uf026"
                    color: Theme.red
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 6
                    renderType: view.textRender
                }

                Rectangle {
                    visible: row.isDef
                    x: view.badgeX + 44
                    y: (parent.height - height) / 2
                    width: 110
                    height: 30
                    radius: 15
                    color: Theme.green
                    opacity: 0.9

                    Text {
                        anchors.centerIn: parent
                        text: "default"
                        color: Theme.base
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        renderType: view.textRender
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: view.width - view.sliderX + 10
                    onClicked: view.selectedKey = modelData.key
                    onDoubleClicked: {
                        view.selectedKey = modelData.key;
                        view.activate();
                    }
                }
            }
        }
    }

    // ---- move mode overlay ----
    Rectangle {
        visible: view.moving
        anchors.fill: parent
        color: Theme.surface1
        opacity: 0.9
    }

    Rectangle {
        id: picker

        visible: view.moving
        width: 760
        height: 96 + view.sinkRows.length * 52
        x: (view.width - width) / 2
        y: (view.height - height) / 2
        radius: 18
        color: Theme.mantle
        border.width: 1
        border.color: Theme.surface2

        Text {
            x: 28
            y: 20
            width: parent.width - 56
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: "Move " + (view.selected ? view.selected.name : "") + " to"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 6
            font.bold: true
            elide: Text.ElideRight
            renderType: view.textRender
        }

        Repeater {
            model: view.sinkRows

            Rectangle {
                required property var modelData
                required property int index

                x: 16
                y: 76 + index * 52
                width: picker.width - 32
                height: 46
                radius: 12
                color: index === view.moveIndex ? Theme.surface2 : "transparent"

                Text {
                    x: 16
                    width: parent.width - 150
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.name
                    color: index === view.moveIndex ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    elide: Text.ElideRight
                    renderType: view.textRender
                }

                Text {
                    visible: view.isDefault(modelData)
                    x: parent.width - 130
                    width: 114
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: "default"
                    color: Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: view.textRender
                }
            }
        }
    }
}
