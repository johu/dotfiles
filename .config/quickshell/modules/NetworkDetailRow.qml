import QtQuick
import QtQuick.Layouts

// Single label:value row for NetworkCard.qml's connection-details block
// (IP/gateway/DNS/MAC under the active Ethernet/Wi-Fi connection).
// Hides itself when empty so callers don't need a visible: check per row
// (e.g. no IPv6 gateway on networks without routable IPv6).
RowLayout {
    id: root

    property string label: ""
    property string value: ""

    visible: root.value.length > 0
    Layout.fillWidth: true
    Layout.leftMargin: 28
    spacing: 12

    Text {
        text: root.label
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.small(-2)
        font.weight: Theme.smallWeight
        renderType: Text.NativeRendering
        Layout.preferredWidth: 80
    }

    Text {
        text: root.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.small(-2)
        font.weight: Theme.smallWeight
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
}
