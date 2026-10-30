import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.moduleHeight
    implicitHeight: Theme.moduleHeight

    readonly property int pendingUpdates: PortageUpdates.pendingCount
    readonly property bool badgeVisible: root.pendingUpdates > 0 || PortageUpdates.emergeRunning || PortageUpdates.lastSyncEpoch > 0
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

        RotationAnimation on rotation {
            running: root.buildingActive
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }

    Image {
        visible: root.badgeVisible && !root.buildingActive
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
        onEntered: if (root.badgeVisible) tooltip.open(root)
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
