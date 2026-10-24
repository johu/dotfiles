import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property bool present: false
    property int percent: 0
    property string status: "Unknown"

    implicitWidth: present ? label.implicitWidth : 0
    implicitHeight: Theme.moduleHeight
    visible: present

    Process {
        id: poll
        command: ["sh", "-c", "d=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); if [ -z \"$d\" ]; then echo NONE; exit 0; fi; echo \"$(cat \"$d/capacity\")|$(cat \"$d/status\")\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim();
                if (line === "NONE" || line.length === 0) {
                    root.present = false;
                    return;
                }
                const [cap, st] = line.split("|");
                root.present = true;
                root.percent = parseInt(cap, 10) || 0;
                root.status = st || "Unknown";
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

    readonly property bool charging: status === "Charging"

    Text {
        id: label
        anchors.centerIn: parent

        text: {
            if (root.charging)
                return "\uf0e7 " + root.percent + "%";
            if (root.percent >= 80)
                return "\uf240 " + root.percent + "%";
            if (root.percent >= 60)
                return "\uf241 " + root.percent + "%";
            if (root.percent >= 40)
                return "\uf242 " + root.percent + "%";
            if (root.percent >= 20)
                return "\uf243 " + root.percent + "%";
            return "\uf244 " + root.percent + "%";
        }

        color: {
            if (root.charging)
                return Theme.green;
            if (root.percent <= 10)
                return Theme.red;
            if (root.percent <= 20)
                return Theme.yellow;
            return Theme.text;
        }

        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (detail.visible)
                detail.visible = false;
            else
                detail.open(root);
        }
    }

    BatteryDetail {
        id: detail
        percent: root.percent
        status: root.status
    }
}
