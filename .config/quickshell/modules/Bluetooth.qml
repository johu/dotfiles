import QtQuick
import Quickshell.Io

Text {
    id: root

    property bool present: false
    property bool powered: false
    property int connectedCount: 0

    visible: present

    Process {
        id: poll
        command: ["sh", "-c", "out=$(timeout 2 bluetoothctl show 2>/dev/null); if [ -z \"$out\" ]; then echo NONE; exit 0; fi; powered=$(echo \"$out\" | grep -q 'Powered: yes' && echo yes || echo no); count=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep -c '^Device'); echo \"$powered|$count\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim();
                if (line === "NONE" || line.length === 0) {
                    root.present = false;
                    return;
                }
                const [pw, count] = line.split("|");
                root.present = true;
                root.powered = pw === "yes";
                root.connectedCount = parseInt(count, 10) || 0;
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    text: {
        if (!root.powered)
            return "\uf293";
        if (root.connectedCount > 0)
            return "\uf293 " + root.connectedCount;
        return "\uf293";
    }

    color: root.powered ? (root.connectedCount > 0 ? Theme.blue : Theme.subtext1) : Theme.crust
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: manager.running = true
    }

    Process {
        id: manager
        command: ["blueman-manager"]
    }
}
