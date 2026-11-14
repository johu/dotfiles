import QtQuick
import QtQuick.Layouts
import Quickshell

// Detail card; presentational, backed by the SystemResources {} instance
// owned via SystemResourcesRow.qml.
Rectangle {
    id: root

    property real cpuPercent: 0
    property string cpuModel: ""
    property int cpuCores: 0
    property real ramPercent: 0
    property string ramUsedStr: ""
    property string ramTotalStr: ""
    property string ramFreeStr: ""
    property int tempCelsius: -1
    // Disk ListModel from SystemResources.qml ({mount, used, total, percent}),
    // passed by reference so in-place updates avoid Repeater churn.
    property var disks: null

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
            value: Math.round(root.cpuPercent) + "%"
            tooltip: root.cpuModel.length > 0 ? root.cpuModel + "\n" + root.cpuCores + " cores" : ""
            percent: root.cpuPercent
            accentColor: Theme.blue
        }

        ResourceRow {
            // No nerd-font glyph renders reliably for RAM; use a custom asset.
            iconSource: Quickshell.shellPath("assets/icons/ram.svg")
            value: Math.round(root.ramPercent) + "%"
            tooltip: root.ramTotalStr.length > 0 ? root.ramUsedStr + " used\n" + root.ramTotalStr + " total\n" + root.ramFreeStr + " free" : ""
            percent: root.ramPercent
            accentColor: Theme.mauve
        }

        ResourceRow {
            icon: "\uf2c9"
            value: root.tempCelsius >= 0 ? root.tempCelsius + "°C" : "n/a"
            percent: -1
            accentColor: Theme.maroon
        }

        Repeater {
            model: root.disks

            ResourceRow {
                icon: "\uf0a0"
                value: Math.round(model.percent) + "%"
                tooltip: model.mount + "\n" + model.used + " / " + model.total
                percent: model.percent
                accentColor: Theme.sky
            }
        }
    }
}
