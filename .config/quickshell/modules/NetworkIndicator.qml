import QtQuick
import Quickshell.Io
import Quickshell.Networking

Text {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeWifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    // nf-fa-wifi (U+F1EB) renders as a single flat arc that doesn't read
    // well at bar size. These are the Material Design Icons wifi-strength
    // glyphs (Nerd Font's supplementary-plane MDI block, U+F0000-U+F1AF0 -
    // confirmed via fc-query), the same codepoints `omarchy` uses for its
    // bar pill, which actually render as tiered signal bars.
    readonly property var wifiStrengthIcons: ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"]

    function wifiIcon(strength) {
        const index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1));
        return wifiStrengthIcons[index];
    }

    text: {
        if (activeWifiNetwork)
            return `${wifiIcon(activeWifiNetwork.signalStrength)} ${Math.round(activeWifiNetwork.signalStrength)}%`;
        if (wiredDevice && wiredDevice.connected)
            // nf-fa-plug (U+F1E6) reads as a power plug, not a LAN
            // connection. This is the MDI "ethernet" glyph (an RJ45 port
            // icon) that `omarchy` and `serpantinum` both use instead.
            return "\u{f0200}";
        return "Not connected";
    }

    color: Theme.sky
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
                if (panel.visible)
                    panel.visible = false;
                else
                    panel.open(root);
            } else {
                nmtui.running = true;
            }
        }
    }

    NetworkPanel {
        id: panel
    }

    Process {
        id: nmtui
        command: ["ghostty", "-e", "nmtui"]
    }
}
