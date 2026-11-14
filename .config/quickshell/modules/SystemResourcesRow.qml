import QtQuick
import QtQuick.Layouts
import Quickshell

// CPU/RAM/Disk summary; click expands the SystemResourcesCard. Backed by
// an invisible SystemResources {} owned by the caller.
ColumnLayout {
    id: root

    property real cpuPercent: 0
    property string cpuModel: ""
    property int cpuCores: 0
    property real ramPercent: 0
    property string ramUsedStr: ""
    property string ramTotalStr: ""
    property string ramFreeStr: ""
    property int tempCelsius: -1
    property real rootDiskPercent: 0
    property var disks: null
    property bool expanded: false

    spacing: 6

    Rectangle {
        Layout.fillWidth: true
        color: Qt.lighter(Theme.surface1, 1.3)
        radius: Theme.radius
        implicitHeight: summaryRow.implicitHeight + 16

        RowLayout {
            id: summaryRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            Image {
                // Distinct from the detail card's CPU glyph: this covers CPU+RAM+Disk.
                source: Quickshell.shellPath("assets/icons/system-mauve.svg")
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "System"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                    font.bold: true
                }

                Text {
                    // fillWidth + elide, see WeatherRow: a dynamic-width subtitle shifts the
                    // icon column otherwise.
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: "CPU " + Math.round(root.cpuPercent) + "% \u00b7 RAM " + Math.round(root.ramPercent) + "% \u00b7 Disk " + Math.round(root.rootDiskPercent) + "%"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-2)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Reserves layout space the moment `expanded` flips, which drives
    // Dashboard's card height Behavior. Decoupled from opacity so expand grows
    // the box first, then fades in, and collapse fades out, then frees the
    // space (`reserved` drops after fadeOut). Without it, expand popped
    // content into an already-grown box.
    property bool reserved: false

    onExpandedChanged: {
        if (root.expanded) {
            fadeOut.stop();
            root.reserved = true;
            growDelay.restart();
        } else {
            growDelay.stop();
            fadeIn.stop();
            fadeOut.restart();
        }
    }

    Timer {
        id: growDelay
        // Matches Dashboard's card height Behavior, so the box finishes growing
        // before the content fades in.
        interval: 180
        onTriggered: fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: detailCard
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: detailCard
        property: "opacity"
        to: 0
        duration: 150
        easing.type: Easing.OutCubic
        onStopped: if (!root.expanded)
            root.reserved = false
    }

    SystemResourcesCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
        cpuPercent: root.cpuPercent
        cpuModel: root.cpuModel
        cpuCores: root.cpuCores
        ramPercent: root.ramPercent
        ramUsedStr: root.ramUsedStr
        ramTotalStr: root.ramTotalStr
        ramFreeStr: root.ramFreeStr
        tempCelsius: root.tempCelsius
        disks: root.disks
    }
}
