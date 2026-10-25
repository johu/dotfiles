import QtQuick
import QtQuick.Layouts

// Card for Dashboard.qml's expanded detail view. Purely presentational -
// backed by an invisible AudioMixer {} logic instance owned by
// Dashboard.qml (via AudioMixerRow.qml).
Rectangle {
    id: root

    property var streams: []

    radius: Theme.radius
    color: Theme.surface2
    implicitWidth: rows.implicitWidth + 24
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
            font.pixelSize: Theme.fontSize - 2
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
