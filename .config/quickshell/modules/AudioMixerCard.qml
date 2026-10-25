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
    // Layout.fillWidth (set by the caller, AudioMixerRow.qml) is what's
    // supposed to stretch this to the full card width - but with few or
    // no streams playing, rows.implicitWidth is small, and relying on
    // fillWidth alone to override it was observed coming out narrower
    // than WeatherCard/SystemResourcesCard's own equivalents. Floor it at
    // the parent column's width directly instead of trusting that.
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
