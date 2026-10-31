import QtQuick
import QtQuick.Layouts
import Quickshell

// Hover tooltip for Logo.qml's update badge: pending-update count and
// time since the last eix-sync, or live emerge build progress when a
// build is actually running (see PortageUpdates.qml).
PopupWindow {
    id: root

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width / 2, 0);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x - card.implicitWidth / 2;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function formatSince(epoch) {
        if (epoch <= 0)
            return "Last sync: never";
        const seconds = Math.max(0, Math.floor(Date.now() / 1000) - epoch);
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0)
            return "Last sync: " + hours + "h " + minutes + "m ago";
        if (minutes > 0)
            return "Last sync: " + minutes + "m ago";
        return "Last sync: just now";
    }

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"

    implicitWidth: card.implicitWidth + 2
    implicitHeight: card.implicitHeight + 2

    // "Nm ago" needs to keep ticking while the tooltip is open, not just
    // when lastSyncEpoch itself changes (which only happens once per sync).
    Timer {
        running: root.visible
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: lastSyncText.text = root.formatSince(PortageUpdates.lastSyncEpoch)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.surface1
        implicitWidth: layout.implicitWidth + 28
        implicitHeight: layout.implicitHeight + 20

        ColumnLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 4

            Text {
                visible: PortageUpdates.emergeRunning
                Layout.alignment: Qt.AlignHCenter
                text: PortageUpdates.emergeTotal > 0
                    ? "Building " + PortageUpdates.emergeCurrent + " of " + PortageUpdates.emergeTotal
                    : "Emerge running"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
            }

            Text {
                visible: PortageUpdates.emergeRunning && PortageUpdates.emergeAtom !== ""
                Layout.alignment: Qt.AlignHCenter
                text: PortageUpdates.emergeAtom
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                elide: Text.ElideMiddle
                Layout.maximumWidth: 240
            }

            Text {
                visible: !PortageUpdates.emergeRunning
                Layout.alignment: Qt.AlignHCenter
                text: PortageUpdates.pendingCount === 0
                    ? "No updates available"
                    : PortageUpdates.pendingCount + (PortageUpdates.pendingCount === 1 ? " update available" : " updates available")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
            }

            Text {
                id: lastSyncText
                Layout.alignment: Qt.AlignHCenter
                text: root.formatSince(PortageUpdates.lastSyncEpoch)
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
            }
        }
    }
}
