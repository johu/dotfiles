import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

PopupWindow {
    id: root

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"

    implicitWidth: 280
    implicitHeight: card.implicitHeight

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var sortedNetworks: wifiDevice ? [...wifiDevice.networks.values].sort((a, b) => b.signalStrength - a.signalStrength) : []

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width / 2, item.height);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x - root.implicitWidth / 2;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.visible = true;
    }

    // Only run the Wi-Fi scanner while the panel is open, to avoid
    // burning power scanning in the background at all times.
    onVisibleChanged: {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.visible;
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.left: parent.left
        implicitWidth: parent.width
        implicitHeight: layout.implicitHeight + 24
        radius: Theme.radius
        color: Theme.surface1

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\uf1eb"
                        color: {
                            if (modelData.connected)
                                return Theme.sky;
                            if (modelData.signalStrength > 60)
                                return Theme.subtext1;
                            if (modelData.signalStrength > 30)
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
                        visible: modelData.security !== WifiSecurityType.None
                        text: "\uf023"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        text: Math.round(modelData.signalStrength) + "%"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
