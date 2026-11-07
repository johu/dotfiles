import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

Text {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: root.adapter !== null
    readonly property bool powered: root.adapter?.enabled ?? false
    readonly property int connectedCount: root.adapter ? root.adapter.devices.values.filter(d => d.connected).length : 0

    visible: present

    text: root.connectedCount > 0 ? " " + root.connectedCount : ""

    color: root.powered ? (root.connectedCount > 0 ? Theme.blue : Theme.subtext1) : Theme.crust
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // The device list now lives in Dashboard.qml's expand row
                // (BluetoothRow/BluetoothCard) - jump straight there.
                // Pairing a brand-new device still needs blueman-manager
                // (right-click), since Quickshell registers no BlueZ
                // pairing agent - see docs/ideas/bluetooth.md.
                DashboardBridge.openBluetoothRequested();
            } else {
                manager.running = true;
            }
        }
    }

    Process {
        id: manager
        command: ["blueman-manager"]
    }
}
