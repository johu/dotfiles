import QtQuick
import Quickshell.Io
import Quickshell.Networking

Text {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeWifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    text: {
        if (activeWifiNetwork)
            return `   ${Math.round(activeWifiNetwork.signalStrength)}%`;
        if (wiredDevice && wiredDevice.connected)
            // waybar's ethernet icon (nf-fa-ethernet, U+F6FF) isn't in this
            // font's installed charset (verified via fc-query) - nf-fa-plug
            // is a reasonable stand-in for "wired connection".
            return "";
        return "Not connected";
    }

    color: Theme.sky
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: nmtui.running = true
    }

    Process {
        id: nmtui
        command: ["ghostty", "-e", "nmtui"]
    }
}
