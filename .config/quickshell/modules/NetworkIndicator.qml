import QtQuick
import Quickshell.Networking

Text {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeWifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    // nf-fa-wifi (U+F1EB) is a flat arc that reads poorly at bar size. Use the
    // MDI wifi-strength glyphs (U+F0000+ block, as omarchy) for tiered bars.
    readonly property var wifiStrengthIcons: ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]

    // signalStrength is a 0.0-1.0 fraction, not a percentage.
    function wifiIcon(strength) {
        const percent = strength * 100;
        const index = Math.max(0, Math.min(4, Math.ceil(percent / 20) - 1));
        return wifiStrengthIcons[index];
    }

    readonly property bool present: !!wifiDevice || !!wiredDevice

    text: {
        if (activeWifiNetwork)
            return `${wifiIcon(activeWifiNetwork.signalStrength)} ${Math.round(activeWifiNetwork.signalStrength * 100)}%`;
        if (wiredDevice && wiredDevice.connected)
            // nf-fa-plug reads as a power plug; use the MDI "ethernet" glyph (as
            // omarchy and serpantinum).
            return "\u{f0200}";
        return "Not connected";
    }

    color: Theme.sky
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    renderType: Text.NativeRendering
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                // Opens the network row in the dashboard.
                DashboardBridge.openNetworkRequested();
            } else {
                Apps.runInTerminal(["nmtui"]);
            }
        }
    }
}
