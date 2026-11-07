import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

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
