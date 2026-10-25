import QtQuick
import QtQuick.Layouts

// Card for Dashboard.qml's expanded detail view. Purely presentational -
// backed by an invisible SystemResources {} logic instance owned by
// Dashboard.qml (via SystemResourcesRow.qml).
Rectangle {
    id: root

    property real cpuPercent: 0
    property real ramPercent: 0
    property int tempCelsius: -1
    property string diskUsed: ""
    property string diskTotal: ""
    property real diskPercent: 0

    radius: Theme.radius
    color: Theme.surface2
    implicitWidth: rows.implicitWidth + 24
    implicitHeight: rows.implicitHeight + 20

    ColumnLayout {
        id: rows
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        ResourceRow {
            icon: "\uf2db"
            label: "CPU"
            value: Math.round(root.cpuPercent) + "%"
            percent: root.cpuPercent
            accentColor: Theme.blue
        }

        ResourceRow {
            icon: "\uf538"
            label: "RAM"
            value: Math.round(root.ramPercent) + "%"
            percent: root.ramPercent
            accentColor: Theme.mauve
        }

        ResourceRow {
            icon: "\uf2c9"
            label: "Temp"
            value: root.tempCelsius >= 0 ? root.tempCelsius + "°C" : "n/a"
            percent: -1
            accentColor: Theme.maroon
        }

        ResourceRow {
            icon: "\uf0a0"
            label: "Disk"
            value: root.diskUsed.length > 0 ? root.diskUsed + " / " + root.diskTotal : "n/a"
            percent: root.diskPercent
            accentColor: Theme.teal
        }
    }
}
