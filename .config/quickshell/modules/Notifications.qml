import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Text {
    id: root

    property string alt: "none"

    text: alt.includes("dnd") ? "\uf1f7" : "\uf0a2"

    property bool initialized: false

    onAltChanged: {
        if (!initialized) {
            initialized = true;
            return;
        }
        ToastManager.show(alt.includes("dnd") ? "DND on" : "DND off", alt.includes("dnd") ? "\uf1f7" : "\uf0a2");
    }

    color: alt.includes("notification") ? Theme.red : Theme.blue
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter
    Layout.preferredHeight: Theme.moduleHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                togglePanel.running = true;
            else
                toggleDnd.running = true;
        }
    }

    Process {
        id: subscribeProc
        running: true
        command: ["swaync-client", "-swb"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data)
                    return;
                try {
                    root.alt = JSON.parse(data).alt ?? "none";
                } catch (e) {}
            }
        }
        // Restart if swaync (and thus this subscription) ever exits.
        onRunningChanged: if (!running) running = true
    }

    Process {
        id: togglePanel
        command: ["swaync-client", "-t", "-sw"]
    }

    Process {
        id: toggleDnd
        command: ["swaync-client", "-d", "-sw"]
    }
}
