import QtQuick
import QtQuick.Layouts

// Detail card for the mixer; presentational, backed by the AudioMixer {}
// instance owned via AudioMixerRow.qml.
Rectangle {
    id: root

    property var streams: []

    radius: Theme.radius
    color: Theme.surface2
    // Floor at the parent column's width: with few streams, fillWidth alone
    // came out narrower than the other cards.
    implicitWidth: Math.max(rows.implicitWidth + 24, root.parent ? root.parent.width : 0)
    implicitHeight: rows.implicitHeight + 20

    ColumnLayout {
        id: rows
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Text {
            visible: root.streams.length === 0
            Layout.fillWidth: true
            text: "No apps playing"
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.small(-2)
            font.weight: Theme.smallWeight
            renderType: Text.NativeRendering
        }

        Repeater {
            model: root.streams

            delegate: AppVolumeRow {
                id: streamRow
                required property var modelData

                Layout.fillWidth: true
                node: streamRow.modelData
            }
        }
    }
}
