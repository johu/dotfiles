import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight

    readonly property int pendingUpdates: PortageUpdates.pendingCount
    readonly property bool hasConflict: PortageUpdates.hasConflict
    // Gates the hover tooltip; stays true after the first sync.
    readonly property bool tooltipAvailable: root.pendingUpdates > 0 || root.hasConflict || PortageUpdates.emergeRunning || PortageUpdates.lastSyncEpoch > 0
    // Gates the badge icon: only when there's something to flag.
    readonly property bool hasUpdates: root.pendingUpdates > 0
    // emerge alone also covers one idling at a prompt (see PortageUpdates.qml);
    // spin only for an open Compiling/Merging session.
    readonly property bool buildingActive: PortageUpdates.emergeRunning && PortageUpdates.emergeTotal > 0
    // emerge open but not compiling yet (resolving, or at a prompt); unlike
    // buildingActive, it gets a badge, not the spinner.
    readonly property bool idleEmerge: PortageUpdates.emergeRunning && !root.buildingActive

    Image {
        id: label
        anchors.centerIn: parent
        source: Quickshell.shellPath("assets/gentoo-logo.svg")
        width: 24
        height: 24
        sourceSize.width: 24
        sourceSize.height: 24
        fillMode: Image.PreserveAspectFit

        RotationAnimation {
            id: spinAnim
            target: label
            property: "rotation"
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }

        // Stopping spinAnim mid-loop freezes the tilt; finish the revolution.
        RotationAnimation {
            id: settleAnim
            target: label
            property: "rotation"
            to: 360
            duration: 300
            onStopped: label.rotation = 0
        }
    }

    onBuildingActiveChanged: {
        if (root.buildingActive) {
            settleAnim.stop();
            spinAnim.start();
        } else {
            spinAnim.stop();
            settleAnim.from = label.rotation;
            settleAnim.start();
        }
    }

    // Fires on change only, so cover the bar starting mid-build.
    Component.onCompleted: if (root.buildingActive) spinAnim.start()

    Image {
        visible: (root.hasUpdates || root.hasConflict || root.idleEmerge) && !root.buildingActive
        // Priority: conflict, then an open-but-idle emerge, then the update count.
        source: root.hasConflict
            ? Quickshell.shellPath("assets/conflict.svg")
            : root.idleEmerge
                ? Quickshell.shellPath("assets/idle.svg")
                : Quickshell.shellPath("assets/update.svg")
        width: 15
        height: 15
        sourceSize.width: 15
        sourceSize.height: 15
        fillMode: Image.PreserveAspectFit
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 2
        anchors.rightMargin: 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: focusGentooWorkspace.running = true
        onEntered: if (root.tooltipAvailable) tooltip.open(root)
        onExited: tooltip.close()
    }

    LogoTooltip {
        id: tooltip
    }

    // w3/t1 are herdr's ids for the "gentoo" workspace's "emerge" tab (see
    // `herdr workspace list`); update them if that session is recreated.
    Process {
        id: focusGentooWorkspace
        command: ["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })' && herdr workspace focus w3 && herdr tab focus w3:t1"]
    }
}
