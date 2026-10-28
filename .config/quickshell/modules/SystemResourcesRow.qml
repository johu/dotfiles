import QtQuick
import QtQuick.Layouts

// Always-visible CPU/RAM/Disk summary for Dashboard.qml; click toggles the
// detailed SystemResourcesCard (CPU/RAM/temp/disk) below it. Backed by an
// invisible SystemResources {} logic instance owned by the caller.
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
        // Matches the Lock/Logout/Reboot row's PowerButton background.
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
                // Distinct from the detail card's CPU glyph - this
                // summarizes CPU+RAM+Disk together, not just CPU.
                source: "file:///home/johu/.config/quickshell/assets/icons/system.svg"
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                spacing: 2

                Text {
                    text: "System"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    text: "CPU " + Math.round(root.cpuPercent) + "% \u00b7 RAM " + Math.round(root.ramPercent) + "% \u00b7 Disk " + Math.round(root.rootDiskPercent) + "%"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Reserves layout space the instant expanded flips true/false -
    // Dashboard.qml's outer `card` Rectangle has its own `Behavior on
    // height`, so this is what actually drives the box growing/shrinking.
    // Decoupled from the card's own opacity (below) so expand and collapse
    // can be sequenced symmetrically: collapse fades content out *then*
    // frees the space (reserved only drops once fadeOut finishes), so
    // expand grows the box first and only then fades content in - without
    // this delay, expand would grow an already-empty box and "pop" the
    // content in once growth finished, while collapse (fade-then-shrink)
    // already looked smooth.
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
        // Matches Dashboard.qml's card height Behavior duration, so the
        // box has finished growing before content starts fading in.
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
