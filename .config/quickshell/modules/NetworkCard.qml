import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

// Detail content for NetworkRow's expand section. No background of its own:
// it sits on the dashboard card instead of nesting another surface tone.
ColumnLayout {
    id: root

    spacing: 6

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var sortedNetworks: wifiDevice ? [...wifiDevice.networks.values].sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []
    readonly property var activeWifiNetwork: root.sortedNetworks.find(n => n.connected) ?? null

    // Interface carrying traffic. Quickshell.Networking only exposes the MAC,
    // so IPv4/IPv6/DNS come from an on-demand nmcli call keyed on this.
    readonly property string activeIface: root.wiredDevice?.connected ? root.wiredDevice.name : (root.activeWifiNetwork ? root.wifiDevice?.name ?? "" : "")

    // Details and throughput come from the shared NetworkData / SystemData
    // singletons; this card only formats them.
    readonly property var activeDevice: NetworkData.device(root.activeIface)
    readonly property bool detailsLoaded: root.activeDevice !== null
    readonly property string detailIp4Address: root.activeDevice ? root.activeDevice.ip4.join(", ") : ""
    readonly property string detailIp4Gateway: root.activeDevice ? root.activeDevice.gateway : ""
    readonly property string detailIp4Dns: root.activeDevice ? root.activeDevice.dns.join(", ") : ""
    readonly property string detailIp6Address: root.activeDevice ? root.activeDevice.ip6.join(", ") : ""
    readonly property string detailIp6Gateway: root.activeDevice ? root.activeDevice.gateway6 : ""
    readonly property string detailIp6Dns: root.activeDevice ? root.activeDevice.dns6.join(", ") : ""
    readonly property string detailMac: root.activeDevice ? root.activeDevice.hwaddr.trim() : ""

    // Starts at 0 KB/s so the rows don't pop in later.
    readonly property string zeroRate: "0 KB/s"
    readonly property var rate: root.activeIface.length > 0 && SystemData.ready ? NetworkData.rate(root.activeIface) : null
    readonly property string rateDown: root.rate ? root.formatRate(root.rate.rx) : root.zeroRate
    readonly property string rateUp: root.rate ? root.formatRate(root.rate.tx) : root.zeroRate

    Consumer {
        target: NetworkData
        active: root.visible
    }

    // A different interface may not be in the snapshot yet.
    onActiveIfaceChanged: if (root.visible && root.activeIface.length > 0) NetworkData.refresh(true)

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

    // Secured, unknown network just clicked: shows an inline password prompt.
    // pskActive lets the dashboard grant keyboard focus only while needed.
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
        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
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

    // Scan only while shown, to avoid idling the radio.
    onVisibleChanged: {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.visible;
        if (!root.visible)
            root.cancelPsk();
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
            renderType: Text.NativeRendering
            Layout.preferredWidth: 20
        }

        Text {
            Layout.fillWidth: true
            text: "Ethernet"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
        }

        Text {
            text: root.wiredDevice?.connected ? "Connected" : "Disconnected"
            color: root.wiredDevice?.connected ? Theme.green : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
        }
    }

    ColumnLayout {
        visible: root.wiredDevice?.connected === true && root.detailsLoaded
        Layout.fillWidth: true
        spacing: 2

        NetworkDetailRow {
            label: "Interface"
            value: root.activeIface
        }
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
        renderType: Text.NativeRendering
    }

    Text {
        visible: root.wifiDevice !== null && root.sortedNetworks.length === 0
        text: "Scanning\u2026"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        renderType: Text.NativeRendering
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

                // Declared first so it sits below the forget-icon MouseArea.
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
                        renderType: Text.NativeRendering
                        Layout.preferredWidth: 20
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        color: modelData.connected ? Theme.sky : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: Text.NativeRendering
                        font.bold: modelData.connected
                    }

                    Text {
                        visible: modelData.known
                        text: "\uf1f8"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: Text.NativeRendering

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
                        visible: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
                        text: "\uf023"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: modelData.stateChanging ? "\u2026" : Math.round(modelData.signalStrength * 100) + "%"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: Text.NativeRendering
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
                    label: "Interface"
                    value: root.activeIface
                }
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
                // Mirrors the left indent so the input and eye toggle stay centered.
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
                        renderType: Text.NativeRendering
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
                    renderType: Text.NativeRendering

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
                font.pixelSize: Theme.small(-2)
                font.weight: Theme.smallWeight
                renderType: Text.NativeRendering
            }
        }
    }
}
