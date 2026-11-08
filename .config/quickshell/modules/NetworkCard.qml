import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Io

// Detail content for NetworkRow.qml's expand section. Unlike
// WeatherCard/SystemResourcesCard/AudioMixerCard, this has no Rectangle
// background of its own - it sits directly on the dashboard's own card
// color instead of introducing another nested surface tone (replaces the
// standalone NetworkPanel popup, which had its own Theme.surface1 card).
ColumnLayout {
    id: root

    spacing: 6

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var sortedNetworks: wifiDevice ? [...wifiDevice.networks.values].sort((a, b) => b.signalStrength - a.signalStrength) : []
    readonly property var activeWifiNetwork: root.sortedNetworks.find(n => n.connected) ?? null

    // Interface currently carrying traffic, if any - drives the
    // connection-details block below. Quickshell.Networking's device API
    // only exposes the MAC address (NetworkDevice.address); IPv4/IPv6/DNS
    // aren't available natively, so those come from an on-demand `nmcli`
    // call keyed on this.
    readonly property string activeIface: root.wiredDevice?.connected ? root.wiredDevice.name : (root.activeWifiNetwork ? root.wifiDevice?.name ?? "" : "")

    property string detailIp4Address: ""
    property string detailIp4Gateway: ""
    property string detailIp4Dns: ""
    property string detailIp6Address: ""
    property string detailIp6Gateway: ""
    property string detailIp6Dns: ""
    property string detailMac: ""
    property bool detailsLoaded: false

    // Live throughput of the active interface, from its sysfs byte
    // counters (diffed between 1s ticks, only while this card is shown).
    // Shows 0 KB/s until the second sample arrives, so the rows are
    // always present instead of popping in after a tick.
    readonly property string zeroRate: "0 KB/s"
    property string rateDown: zeroRate
    property string rateUp: zeroRate
    property real prevRx: -1
    property real prevTx: -1
    property real prevRateTime: 0

    function formatRate(bps) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let v = bps;
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(v < 10 ? 2 : 1)) + " " + units[i];
    }

    function resetRate() {
        root.rateDown = root.zeroRate;
        root.rateUp = root.zeroRate;
        root.prevRx = -1;
        root.prevTx = -1;
    }

    function clearDetails() {
        root.detailIp4Address = "";
        root.detailIp4Gateway = "";
        root.detailIp4Dns = "";
        root.detailIp6Address = "";
        root.detailIp6Gateway = "";
        root.detailIp6Dns = "";
        root.detailMac = "";
        root.detailsLoaded = false;
    }

    onActiveIfaceChanged: {
        root.resetRate();
        root.detailsLoaded = false;
        if (root.visible && root.activeIface.length > 0)
            detailsProc.running = true;
        else
            root.clearDetails();
    }

    Process {
        id: rateProc
        command: ["cat", "/sys/class/net/" + root.activeIface + "/statistics/rx_bytes", "/sys/class/net/" + root.activeIface + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = this.text.trim().split("\n").map(Number);
                if (isNaN(rx) || isNaN(tx))
                    return;
                const now = Date.now();
                if (root.prevRx >= 0 && now > root.prevRateTime) {
                    const dt = (now - root.prevRateTime) / 1000;
                    root.rateDown = root.formatRate(Math.max(0, (rx - root.prevRx) / dt));
                    root.rateUp = root.formatRate(Math.max(0, (tx - root.prevTx) / dt));
                }
                root.prevRx = rx;
                root.prevTx = tx;
                root.prevRateTime = now;
            }
        }
    }

    Timer {
        interval: 1000
        running: root.visible && root.activeIface.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: rateProc.running = true
    }

    Process {
        id: detailsProc
        command: ["nmcli", "-g", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS,GENERAL.HWADDR", "device", "show", root.activeIface]
        stdout: StdioCollector {
            onStreamFinished: {
                // nmcli -g escapes literal colons inside a field (so they
                // aren't mistaken for the field separator) and joins
                // multi-value fields (e.g. several IPv6 addresses) with " | ".
                const unescape = s => (s ?? "").replace(/\\:/g, ":");
                const list = s => unescape(s).split(" | ").filter(v => v.length > 0).join(", ");
                const lines = this.text.split("\n");
                root.detailIp4Address = unescape(lines[0]);
                root.detailIp4Gateway = unescape(lines[1]);
                root.detailIp4Dns = list(lines[2]);
                root.detailIp6Address = list(lines[3]);
                root.detailIp6Gateway = unescape(lines[4]);
                root.detailIp6Dns = list(lines[5]);
                root.detailMac = unescape(lines[6]).trim();
                root.detailsLoaded = true;
            }
        }
    }

    // Secured, not-yet-known network the user just clicked - shows an
    // inline password prompt under its row until it connects or is
    // cancelled. Exposed as pskActive so NetworkRow/Dashboard can grant
    // real keyboard focus only while a prompt actually needs it.
    property var pskTarget: null
    property string pskText: ""
    property string pskError: ""
    readonly property bool pskActive: root.pskTarget !== null

    function cancelPsk() {
        root.pskTarget = null;
        root.pskText = "";
        root.pskError = "";
    }

    function selectNetwork(network) {
        if (network.connected) {
            network.disconnect();
            return;
        }
        if (network.known || network.security === WifiSecurityType.None) {
            root.cancelPsk();
            network.connect();
            return;
        }
        root.pskTarget = network;
        root.pskText = "";
        root.pskError = "";
    }

    function submitPsk() {
        if (!root.pskTarget || root.pskText.length === 0)
            return;
        root.pskTarget.connectWithPsk(root.pskText);
    }

    // Scanning only while this card is actually shown (reserved by
    // NetworkRow's expand sequencing), to avoid idling the radio.
    onVisibleChanged: {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.visible;
        if (!root.visible) {
            root.cancelPsk();
            root.clearDetails();
            root.resetRate();
        } else if (root.activeIface.length > 0) {
            detailsProc.running = true;
        }
    }

    RowLayout {
        visible: root.wiredDevice !== null
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "\u{f0200}"
            color: root.wiredDevice?.connected ? Theme.green : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize
            Layout.preferredWidth: 20
        }

        Text {
            Layout.fillWidth: true
            text: "Ethernet"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            text: root.wiredDevice?.connected ? "Connected" : "Disconnected"
            color: root.wiredDevice?.connected ? Theme.green : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    ColumnLayout {
        visible: root.wiredDevice?.connected === true && root.detailsLoaded
        Layout.fillWidth: true
        spacing: 2

        NetworkDetailRow {
            label: "Down"
            value: root.rateDown
        }
        NetworkDetailRow {
            label: "Up"
            value: root.rateUp
        }
        NetworkDetailRow {
            label: "IPv4"
            value: root.detailIp4Address
        }
        NetworkDetailRow {
            label: "Gateway"
            value: root.detailIp4Gateway
        }
        NetworkDetailRow {
            label: "DNS"
            value: root.detailIp4Dns
        }
        NetworkDetailRow {
            label: "IPv6"
            value: root.detailIp6Address
        }
        NetworkDetailRow {
            label: "Gateway"
            value: root.detailIp6Gateway
        }
        NetworkDetailRow {
            label: "DNS"
            value: root.detailIp6Dns
        }
        NetworkDetailRow {
            label: "MAC"
            value: root.detailMac
        }
    }

    Rectangle {
        visible: root.wiredDevice !== null && root.sortedNetworks.length > 0
        Layout.fillWidth: true
        height: 1
        color: Theme.surface2
    }

    Text {
        visible: root.wifiDevice === null
        text: "No Wi-Fi device"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        visible: root.wifiDevice !== null && root.sortedNetworks.length === 0
        text: "Scanning\u2026"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Repeater {
        model: root.sortedNetworks

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Connections {
                target: modelData
                function onConnectionFailed(reason) {
                    if (root.pskTarget !== modelData)
                        return;
                    root.pskError = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : ConnectionFailReason.toString(reason);
                }
                function onConnectedChanged() {
                    if (modelData.connected && root.pskTarget === modelData)
                        root.cancelPsk();
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: rowContent.implicitHeight

                // Declared first so it sits below rowContent's own
                // forget-icon MouseArea and only catches clicks
                // elsewhere on the row.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectNetwork(modelData)
                }

                RowLayout {
                    id: rowContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    Text {
                        text: "\uf1eb"
                        color: {
                            if (modelData.connected)
                                return Theme.sky;
                            if (modelData.signalStrength > 0.6)
                                return Theme.subtext1;
                            if (modelData.signalStrength > 0.3)
                                return Theme.surface2;
                            return Theme.crust;
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconFontSize
                        Layout.preferredWidth: 20
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        color: modelData.connected ? Theme.sky : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: modelData.connected
                    }

                    Text {
                        visible: modelData.known
                        text: "\uf1f8"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                mouse.accepted = true;
                                modelData.forget();
                            }
                        }
                    }

                    Text {
                        visible: modelData.security !== WifiSecurityType.None
                        text: "\uf023"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        text: modelData.stateChanging ? "\u2026" : Math.round(modelData.signalStrength * 100) + "%"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            ColumnLayout {
                visible: modelData.connected && root.detailsLoaded
                Layout.fillWidth: true
                spacing: 2

                NetworkDetailRow {
                    label: "Down"
                    value: root.rateDown
                }
                NetworkDetailRow {
                    label: "Up"
                    value: root.rateUp
                }
                NetworkDetailRow {
                    label: "IPv4"
                    value: root.detailIp4Address
                }
                NetworkDetailRow {
                    label: "Gateway"
                    value: root.detailIp4Gateway
                }
                NetworkDetailRow {
                    label: "DNS"
                    value: root.detailIp4Dns
                }
                NetworkDetailRow {
                    label: "IPv6"
                    value: root.detailIp6Address
                }
                NetworkDetailRow {
                    label: "Gateway"
                    value: root.detailIp6Gateway
                }
                NetworkDetailRow {
                    label: "DNS"
                    value: root.detailIp6Dns
                }
                NetworkDetailRow {
                    label: "MAC"
                    value: root.detailMac
                }
            }

            RowLayout {
                id: pskRow
                visible: root.pskTarget === modelData
                Layout.fillWidth: true
                // Matches the left indent (aligns under the network name,
                // same as the error text below), mirrored on the right so
                // the input+eye-toggle group is centered in the remaining
                // space rather than drifting right from the lone eye icon.
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 6

                property bool showPassword: false

                onVisibleChanged: {
                    if (visible) {
                        pskRow.showPassword = false;
                        pskInput.forceActiveFocus();
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: Theme.radius
                    color: Theme.mantle
                    border.width: 1
                    border.color: root.pskError.length > 0 ? Theme.red : Theme.surface2

                    TextInput {
                        id: pskInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        echoMode: pskRow.showPassword ? TextInput.Normal : TextInput.Password
                        clip: true
                        text: root.pskText
                        onTextChanged: root.pskText = text
                        Keys.onReturnPressed: root.submitPsk()
                        Keys.onEscapePressed: root.cancelPsk()
                    }
                }

                Text {
                    text: pskRow.showPassword ? "\uf070" : "\uf06e"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pskRow.showPassword = !pskRow.showPassword
                    }
                }
            }

            Text {
                visible: root.pskTarget === modelData && root.pskError.length > 0
                Layout.leftMargin: 28
                text: root.pskError
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
