import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// Detail content for BluetoothRow.qml. Like NetworkCard.qml, no background
// of its own.
ColumnLayout {
    id: root

    spacing: 6

    readonly property var adapter: Bluetooth.defaultAdapter

    // Paired devices only: pairing a new one needs a BlueZ pairing agent that
    // Quickshell doesn't register (see docs/ideas/bluetooth.md). Connected
    // first, then alphabetical.
    readonly property var pairedDevices: root.adapter ? [...root.adapter.devices.values].filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name)) : []

    function selectDevice(device) {
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    RowLayout {
        visible: root.adapter !== null
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: ""
            color: root.adapter?.enabled ? Theme.blue : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize
            renderType: Text.NativeRendering
            Layout.preferredWidth: 20
        }

        Text {
            Layout.fillWidth: true
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering
        }

        Text {
            text: root.adapter?.enabled ? "On" : "Off"
            color: root.adapter?.enabled ? Theme.blue : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Text.NativeRendering

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adapter.enabled = !root.adapter.enabled
            }
        }
    }

    Rectangle {
        visible: root.adapter !== null && root.pairedDevices.length > 0
        Layout.fillWidth: true
        height: 1
        color: Theme.surface2
    }

    Text {
        visible: root.adapter === null
        text: "No Bluetooth adapter"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        renderType: Text.NativeRendering
    }

    Text {
        visible: root.adapter?.enabled === true && root.pairedDevices.length === 0
        text: "No paired devices"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        renderType: Text.NativeRendering
    }

    Repeater {
        model: root.adapter?.enabled === true ? root.pairedDevices : []

        Item {
            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: modelData.state !== BluetoothDeviceState.Connecting && modelData.state !== BluetoothDeviceState.Disconnecting
                onClicked: root.selectDevice(modelData)
            }

            RowLayout {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                Text {
                    text: ""
                    color: modelData.connected ? Theme.blue : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconFontSize
                    renderType: Text.NativeRendering
                    Layout.preferredWidth: 20
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    elide: Text.ElideRight
                    color: modelData.connected ? Theme.blue : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                    font.bold: modelData.connected
                }

                Text {
                    visible: modelData.batteryAvailable
                    text: Math.round(modelData.battery * 100) + "%"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-2)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                }

                Text {
                    text: ""
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
                    text: {
                        if (modelData.state === BluetoothDeviceState.Connecting)
                            return "Connecting…";
                        if (modelData.state === BluetoothDeviceState.Disconnecting)
                            return "Disconnecting…";
                        return modelData.connected ? "Connected" : "";
                    }
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
