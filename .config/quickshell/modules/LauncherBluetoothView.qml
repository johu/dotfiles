import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth view of the launcher: paired and nearby devices in one keyboard
// driven list. j / k pick a device, Enter connects, disconnects or (for a
// nearby device) pairs, s scans, t toggles trust, f forgets (twice), p powers
// the adapter. Pairing questions (confirm / PIN / passkey) are answered by
// BtAgent in a fixed prompt slot over the detail strip, so nothing shifts.
// Same contract as the other views; fixed geometry.
Item {
    id: view

    property int textRender: Text.NativeRendering

    // Device name -> theme icon name, from launcher-config.json (bluetoothIcons).
    property var iconOverrides: ({})

    // Test hook: environment for the pairing agent (BT_AGENT_BUS=session).
    property var agentEnv: ({})

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1700
    readonly property int preferredHeight: 900

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: view.adapter?.enabled ?? false
    readonly property bool scanning: view.adapter?.discovering ?? false

    // ---- data ----
    // Flat list of { type: "header" | "empty" | "device", key, ... }. Built by
    // a binding (so it follows the devices' properties) but only applied when
    // its signature changes, which keeps the ListView from being rebuilt by
    // property noise such as battery updates.
    property var rows: []
    property string selectedKey: ""

    function devName(d) {
        return d.name || d.deviceName || d.address;
    }

    function iconFor(d) {
        const over = view.iconOverrides?.[view.devName(d)];
        if (over)
            return over;
        // BlueZ derives the icon from the device class; audio-card is its
        // generic guess for speakers.
        if (d.icon === "audio-card")
            return "audio-speakers";
        return d.icon || "";
    }

    function typeLabel(d) {
        switch (view.iconFor(d)) {
        case "audio-headset":
            return "headset";
        case "audio-headphones":
            return "headphones";
        case "audio-speakers":
            return "speaker";
        case "input-keyboard":
            return "keyboard";
        case "input-mouse":
            return "mouse";
        case "input-gaming":
            return "controller";
        case "input-tablet":
            return "tablet";
        case "phone":
            return "phone";
        case "computer":
            return "computer";
        case "camera-photo":
        case "camera-video":
            return "camera";
        case "printer":
            return "printer";
        }
        return "device";
    }

    function build() {
        const a = view.adapter;
        if (!a || !a.enabled)
            return [];
        const all = [...a.devices.values];
        const byName = (x, y) => view.devName(x).localeCompare(view.devName(y));
        const paired = all.filter(d => d.paired).sort((x, y) => (y.connected - x.connected) || byName(x, y));
        // Unnamed devices show their address: list the named ones first.
        const named = d => d.name !== "" || d.deviceName !== "";
        const nearby = all.filter(d => !d.paired).sort((x, y) => (named(y) - named(x)) || byName(x, y));
        const out = [{ type: "header", key: "h-paired", title: "Paired" }];
        if (paired.length === 0)
            out.push({ type: "empty", key: "e-paired", title: "No paired devices" });
        for (const d of paired)
            out.push({ type: "device", key: d.address, dev: d, paired: true });
        out.push({ type: "header", key: "h-nearby", title: "Nearby", scan: true });
        if (nearby.length === 0)
            out.push({ type: "empty", key: "e-nearby", title: view.scanning ? "Searching for devices…" : "Press s to look for devices" });
        for (const d of nearby)
            out.push({ type: "device", key: d.address, dev: d, paired: false });
        return out;
    }

    readonly property var built: view.build()

    function sig(r) {
        return r.map(x => x.key + "|" + (x.dev ? view.devName(x.dev) + "|" + view.iconFor(x.dev) : (x.title ?? ""))).join("\n");
    }

    function applyBuilt() {
        if (view.sig(view.built) !== view.sig(view.rows))
            view.rows = view.built;
        view.ensureSelection();
    }

    onBuiltChanged: view.applyBuilt()

    readonly property var deviceRows: view.rows.filter(r => r.type === "device")
    readonly property int selectedRowIndex: view.rows.findIndex(r => r.key === view.selectedKey)
    readonly property var selected: view.selectedRowIndex >= 0 ? view.rows[view.selectedRowIndex] : null
    readonly property var selDev: view.selected && view.selected.type === "device" ? view.selected.dev : null

    function ensureSelection() {
        if (view.selected)
            return;
        view.selectedKey = view.deviceRows.length > 0 ? view.deviceRows[0].key : "";
    }

    function moveSelection(delta) {
        const list = view.deviceRows;
        if (list.length === 0)
            return;
        const i = list.findIndex(r => r.key === view.selectedKey);
        view.selectedKey = list[Math.max(0, Math.min(list.length - 1, (i < 0 ? 0 : i) + delta))].key;
    }

    function selectEdge(last) {
        const list = view.deviceRows;
        if (list.length > 0)
            view.selectedKey = list[last ? list.length - 1 : 0].key;
    }

    Component.onCompleted: view.applyBuilt()

    // ---- feedback ----
    property string toastText: ""

    function toast(text) {
        view.toastText = text;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer

        interval: 2600
        onTriggered: view.toastText = ""
    }

    // ---- pairing agent ----
    BtAgent {
        id: agent

        running: true
        testEnv: view.agentEnv
    }

    property string pin: ""      // what the user typed for a PIN / passkey prompt
    readonly property var req: agent.request
    readonly property bool typing: view.req !== null && (view.req.kind === "pin" || view.req.kind === "passkey")
    readonly property bool prompting: view.req !== null || agent.display !== null
    onReqChanged: view.pin = ""

    function pad(n, w) {
        return String(n).padStart(w, "0");
    }

    readonly property string promptTitle: {
        const r = view.req;
        if (r) {
            switch (r.kind) {
            case "confirm":
                return "Pair with " + r.name + "?";
            case "pin":
                return "Enter the PIN for " + r.name;
            case "passkey":
                return "Enter the passkey for " + r.name;
            case "authorize":
                return "Allow " + r.name + " to connect?";
            case "service":
                return "Allow " + r.name + " to use a service?";
            }
        }
        const dsp = agent.display;
        if (dsp)
            return "Type this code on " + dsp.name;
        return "";
    }

    // The code worth showing big: the passkey to compare or to type.
    readonly property string promptCode: {
        const r = view.req;
        if (r && r.kind === "confirm" && r.passkey !== undefined)
            return view.pad(r.passkey, 6);
        const dsp = agent.display;
        if (dsp)
            return dsp.passkey !== undefined ? view.pad(dsp.passkey, 6) : String(dsp.pin ?? "");
        return "";
    }

    // ---- device actions ----
    property string pairingAddr: ""
    property string connectingAddr: ""
    property string forgetArm: ""

    function findDevice(addr) {
        return view.adapter ? [...view.adapter.devices.values].find(d => d.address === addr) ?? null : null;
    }

    function activate() {
        const d = view.selDev;
        if (!d)
            return;
        if (d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
            return;
        if (!d.paired) {
            view.pairingAddr = d.address;
            d.pair();
            view.toast("Pairing with " + view.devName(d) + "…");
        } else if (d.connected) {
            d.disconnect();
        } else {
            view.connectingAddr = d.address;
            d.connect();
        }
    }

    function toggleTrust() {
        const d = view.selDev;
        if (!d || !d.paired)
            return;
        d.trusted = !d.trusted;
        view.toast(view.devName(d) + (d.trusted ? " trusted" : " not trusted"));
    }

    function forget() {
        const d = view.selDev;
        if (!d || !d.paired)
            return;
        if (view.forgetArm !== d.address) {
            view.forgetArm = d.address;
            forgetTimer.restart();
            view.toast("Press f again to forget " + view.devName(d));
            return;
        }
        view.forgetArm = "";
        view.toast("Forgot " + view.devName(d));
        d.forget();
    }

    Timer {
        id: forgetTimer

        interval: 3000
        onTriggered: view.forgetArm = ""
    }

    function togglePower() {
        if (!view.adapter)
            return;
        view.adapter.enabled = !view.adapter.enabled;
    }

    property bool startedScan: false

    function toggleScan() {
        if (!view.adapter || !view.adapter.enabled) {
            view.toast("Bluetooth is off (p turns it on)");
            return;
        }
        if (view.adapter.discovering) {
            view.adapter.discovering = false;
            scanTimer.stop();
        } else {
            view.adapter.discovering = true;
            view.startedScan = true;
            scanTimer.restart();
        }
    }

    // Scanning disturbs audio streams and drains the radio: stop on its own.
    Timer {
        id: scanTimer

        interval: 30000
        onTriggered: if (view.adapter)
            view.adapter.discovering = false
    }

    // A pairing that ends without the device being paired is reported once
    // BlueZ has had a moment to flip `paired`.
    Timer {
        id: pairCheckTimer

        interval: 1500
        onTriggered: {
            const d = view.findDevice(view.pairingAddr);
            if (d && !d.paired && !d.pairing)
                view.toast("Pairing with " + view.devName(d) + " failed");
            view.pairingAddr = "";
        }
    }

    Instantiator {
        model: view.adapter ? view.adapter.devices.values : []

        delegate: Item {
            id: watch

            required property var modelData

            Connections {
                target: watch.modelData

                function onPairedChanged() {
                    const d = watch.modelData;
                    if (d.paired && d.address === view.pairingAddr) {
                        view.pairingAddr = "";
                        pairCheckTimer.stop();
                        d.trusted = true;
                        view.connectingAddr = d.address;
                        d.connect();
                        view.toast("Paired with " + view.devName(d));
                    }
                }

                function onPairingChanged() {
                    if (!watch.modelData.pairing && watch.modelData.address === view.pairingAddr)
                        pairCheckTimer.restart();
                }

                function onStateChanged() {
                    const d = watch.modelData;
                    if (d.address !== view.connectingAddr)
                        return;
                    if (d.state === BluetoothDeviceState.Connected) {
                        view.connectingAddr = "";
                    } else if (d.state === BluetoothDeviceState.Disconnected) {
                        view.connectingAddr = "";
                        view.toast("Couldn't connect to " + view.devName(d));
                    }
                }
            }
        }
    }

    Component.onDestruction: {
        // Leave the radio as we found it.
        if (view.startedScan && view.adapter)
            view.adapter.discovering = false;
    }

    // ---- keys ----
    function handleEscape() {
        if (view.req) {
            agent.reject();
            return true;
        }
        if (agent.display) {
            const d = view.findDevice(view.pairingAddr);
            if (d)
                d.cancelPair();
            return true;
        }
        return false;
    }

    readonly property var hints: {
        if (view.req) {
            const typing = view.typing;
            return [[
                    { keys: ["↵"], text: typing ? "send" : "yes", slot: "send" },
                    { keys: ["Esc"], text: typing ? "cancel" : "no", slot: "cancel" }
                ]];
        }
        const d = view.selDev;
        const paired = !!d && d.paired;
        return [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["↵"], text: !d ? "connect" : (!paired ? "pair" : (d.connected ? "disconnect" : "connect")), slot: "disconnect", ghost: !d },
                { keys: ["s"], text: "scan" },
                { keys: ["t"], text: "trust", ghost: !paired },
                { keys: ["f"], text: d && view.forgetArm === d.address ? "forget?" : "forget", slot: "forget?", ghost: !paired },
                { keys: ["p"], text: "power" },
                { keys: ["q"], text: "close" }
            ]];
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (view.req) {
            const r = view.req;
            if (view.typing) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (view.pin !== "")
                        agent.submit(view.pin);
                } else if (event.key === Qt.Key_Backspace) {
                    view.pin = view.pin.slice(0, -1);
                } else if (!ctrl && event.text.length === 1 && event.text >= " ") {
                    const max = r.kind === "passkey" ? 6 : 16;
                    if ((r.kind !== "passkey" || (event.text >= "0" && event.text <= "9")) && view.pin.length < max)
                        view.pin += event.text;
                }
                return true;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Y)
                agent.accept();
            else if (event.key === Qt.Key_N || event.key === Qt.Key_Q)
                agent.reject();
            return true;
        }
        if (agent.display)
            return event.key !== Qt.Key_Q;
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
        case Qt.Key_Return:
        case Qt.Key_Enter:
            view.activate();
            return true;
        case Qt.Key_S:
            view.toggleScan();
            return true;
        case Qt.Key_T:
            view.toggleTrust();
            return true;
        case Qt.Key_F:
            view.forget();
            return true;
        case Qt.Key_P:
            view.togglePower();
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    // ---- layout ----
    readonly property int rowH: 60
    readonly property int headerH: 56
    readonly property int stripH: 150

    Text {
        x: 0
        y: 0
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Bluetooth"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    // adapter chip (fixed slot: "on" and "off" share the width)
    Rectangle {
        x: 200
        y: 12
        width: 130
        height: 30
        radius: 15
        color: Theme.base
        border.color: Theme.surface2
        visible: view.adapter !== null

        Text {
            anchors.centerIn: parent
            text: view.powered ? "adapter on" : "adapter off"
            color: view.powered ? Theme.green : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }
    }

    Text {
        x: view.width - width
        y: 0
        width: 700
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
        height: view.height - 64 - view.stripH - 20
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

            readonly property bool isDev: modelData.type === "device"
            readonly property bool sel: modelData.key === view.selectedKey
            readonly property var dev: isDev ? modelData.dev : null
            readonly property bool connected: dev ? dev.connected : false
            readonly property bool busy: dev ? (dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting) : false
            readonly property string iconName: dev ? view.iconFor(dev) : ""

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

                // scan state, fixed slot at the right
                Row {
                    visible: modelData.scan === true && view.scanning
                    x: parent.width - width - 6
                    y: 20
                    height: 30
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.yellow

                        SequentialAnimation on opacity {
                            running: view.scanning
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 600 }
                            NumberAnimation { to: 1; duration: 600 }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "scanning"
                        color: Theme.yellow
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        renderType: view.textRender
                    }
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

            // device row
            Rectangle {
                visible: row.isDev
                anchors.fill: parent
                radius: 14
                color: row.sel ? Theme.surface2 : "transparent"

                Item {
                    x: 20
                    y: (parent.height - height) / 2
                    width: 38
                    height: 38
                    opacity: row.connected || row.busy ? 1 : 0.55

                    Rectangle {
                        anchors.fill: parent
                        radius: 19
                        color: Theme.base
                    }

                    ResolvedIcon {
                        visible: row.iconName !== ""
                        anchors.centerIn: parent
                        size: 26
                        iconSource: row.iconName !== "" ? "image://icon/" + row.iconName : ""
                    }

                    Text {
                        visible: row.iconName === ""
                        anchors.centerIn: parent
                        text: ""
                        color: row.connected ? Theme.blue : Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        renderType: view.textRender
                    }
                }

                // state badge on the icon: check = connected, pulsing dot = busy
                Rectangle {
                    visible: row.connected || row.busy
                    x: 20 + 38 - 14
                    y: (parent.height - 38) / 2 - 5
                    width: 18
                    height: 18
                    radius: 9
                    color: row.busy ? Theme.yellow : Theme.green
                    border.color: row.sel ? Theme.surface2 : Theme.mantle
                    border.width: 2

                    Text {
                        visible: !row.busy
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.base
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        renderType: view.textRender
                    }

                    Rectangle {
                        visible: row.busy
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.base

                        SequentialAnimation on opacity {
                            running: row.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 450 }
                            NumberAnimation { to: 1; duration: 450 }
                        }
                    }
                }

                Text {
                    x: 80
                    y: 8
                    width: parent.width - 80 - 140
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    text: row.dev ? view.devName(row.dev) : ""
                    color: row.sel || row.connected ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: row.sel
                    elide: Text.ElideRight
                    renderType: view.textRender
                }

                // type, or the transient state while something is happening
                Text {
                    x: 80
                    y: 34
                    width: parent.width - 80 - 140
                    height: 20
                    verticalAlignment: Text.AlignVCenter
                    text: {
                        if (!row.dev)
                            return "";
                        if (row.dev.pairing)
                            return "pairing…";
                        if (row.dev.state === BluetoothDeviceState.Connecting)
                            return "connecting…";
                        if (row.dev.state === BluetoothDeviceState.Disconnecting)
                            return "disconnecting…";
                        return view.typeLabel(row.dev);
                    }
                    color: row.busy ? Theme.yellow : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: view.textRender
                }

                Text {
                    visible: row.dev && row.dev.batteryAvailable && row.connected
                    x: parent.width - width - 24
                    width: 100
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: row.dev && row.dev.batteryAvailable ? Math.round(row.dev.battery * 100) + " %" : ""
                    color: row.dev && row.dev.battery < 0.2 ? Theme.red : Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    renderType: view.textRender
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: view.selectedKey = modelData.key
                    onDoubleClicked: {
                        view.selectedKey = modelData.key;
                        view.activate();
                    }
                }
            }
        }
    }

    // adapter off / missing
    EmptyState {
        visible: view.adapter === null || !view.powered
        x: 0
        y: 64
        width: view.width
        height: view.height - 64 - view.stripH - 20
        illustration: "bluetooth.svg"
        title: view.adapter === null ? "No Bluetooth adapter" : "Bluetooth is off"
        hint: view.adapter === null ? "Plug in or enable an adapter" : "Press p to turn it on"
        textRender: view.textRender
    }

    // ---- detail strip / prompt (same slot) ----
    Rectangle {
        x: 0
        y: view.height - view.stripH
        width: view.width
        height: 1
        color: Theme.surface2
    }

    Item {
        id: strip

        visible: !view.prompting
        x: 0
        y: view.height - view.stripH + 14
        width: view.width
        height: view.stripH - 14

        Text {
            x: 6
            height: 36
            verticalAlignment: Text.AlignVCenter
            text: view.selDev ? view.devName(view.selDev) : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 8
            font.bold: true
            renderType: view.textRender
        }

        Row {
            y: 50
            x: 6
            spacing: 0

            Repeater {
                model: {
                    const d = view.selDev;
                    if (!d)
                        return [];
                    const conn = d.pairing ? "pairing…" : (d.state === BluetoothDeviceState.Connecting ? "connecting…" : (d.state === BluetoothDeviceState.Disconnecting ? "disconnecting…" : (d.connected ? "connected" : (d.paired ? "not connected" : "not paired"))));
                    return [
                        { k: "Address", v: d.address },
                        { k: "Type", v: view.typeLabel(d) },
                        { k: "Connection", v: conn },
                        { k: "Trusted", v: d.paired ? (d.trusted ? "yes" : "no") : "–" },
                        { k: "Battery", v: d.batteryAvailable ? Math.round(d.battery * 100) + " %" : "–" }
                    ];
                }

                Item {
                    required property var modelData

                    width: 300
                    height: 60

                    Text {
                        text: modelData.k
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: view.textRender
                    }

                    Text {
                        y: 26
                        width: parent.width - 20
                        text: modelData.v
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 3
                        elide: Text.ElideRight
                        renderType: view.textRender
                    }
                }
            }
        }
    }

    Rectangle {
        visible: view.prompting
        x: 0
        y: view.height - view.stripH + 14
        width: view.width
        height: view.stripH - 14
        radius: 14
        color: Theme.base
        border.color: Theme.blue
        border.width: 1

        Text {
            x: 26
            y: 18
            width: parent.width - 52
            text: view.promptTitle
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 6
            font.bold: true
            elide: Text.ElideRight
            renderType: view.textRender
        }

        // code to compare / type on the device, or what the user has typed
        Text {
            x: 26
            y: 62
            width: parent.width - 52
            height: 44
            verticalAlignment: Text.AlignVCenter
            text: view.typing ? (view.pin + "▏") : view.promptCode
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 16
            font.bold: true
            renderType: view.textRender
        }

        Text {
            x: parent.width - width - 26
            y: 70
            visible: agent.display !== null && agent.display.entered !== undefined
            text: agent.display && agent.display.entered !== undefined ? agent.display.entered + " / 6" : ""
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
            renderType: view.textRender
        }
    }
}
