import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight

    readonly property int pendingUpdates: PortageUpdates.pendingCount
    // Gates the hover-tooltip only - stays true once synced at least once
    // so "last synced Xh ago" is always checkable, even at 0 pending.
    readonly property bool tooltipAvailable: root.pendingUpdates > 0 || PortageUpdates.emergeRunning || PortageUpdates.lastSyncEpoch > 0
    // Gates the badge icon itself - only when there's actually something
    // to flag, not just "synced before" (that would make it permanently
    // visible once synced, even with 0 pending updates).
    readonly property bool hasUpdates: root.pendingUpdates > 0
    // emergeRunning alone also covers an emerge sitting idle at a
    // confirmation prompt (see PortageUpdates.qml) - only switch to the
    // spinner once there's an actual open Compiling/Merging session.
    readonly property bool buildingActive: PortageUpdates.emergeRunning && PortageUpdates.emergeTotal > 0

    Image {
        id: label
        anchors.centerIn: parent
        source: "file:///home/johu/.config/quickshell/assets/gentoo-logo.svg"
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

        // Stopping spinAnim mid-loop just freezes `rotation` at whatever
        // angle it happened to be at - finish the current revolution back
        // to upright instead of leaving the glyph stuck tilted.
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

    // onBuildingActiveChanged only fires on change, not the initial
    // binding evaluation - cover the bar starting mid-build.
    Component.onCompleted: if (root.buildingActive) spinAnim.start()

    Image {
        visible: root.hasUpdates && !root.buildingActive
        source: "file:///home/johu/.config/quickshell/assets/update.svg"
        width: 12
        height: 12
        sourceSize.width: 12
        sourceSize.height: 12
        fillMode: Image.PreserveAspectFit
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 1
        anchors.rightMargin: -1
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

    // w3/t1 are herdr's own workspace/tab ids for the "gentoo" workspace's
    // "emerge" tab (see `herdr workspace list` / `herdr tab list`) - fixed
    // ids, not names, so they'd need updating if that herdr session is
    // ever recreated from scratch.
    Process {
        id: focusGentooWorkspace
        command: ["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })' && herdr workspace focus w3 && herdr tab focus w3:t1"]
    }
}
