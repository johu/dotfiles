import QtQuick
import Quickshell.Io

// Logic-only: polls CPU/RAM/temp/disk and exposes the values. No visual
// representation of its own — see SystemResourcesCard.qml for that,
// embedded in Dashboard.qml's expand section.
Item {
    id: root

    property real cpuPercent: 0
    property real ramPercent: 0
    property int tempCelsius: -1
    property string diskUsed: ""
    property string diskTotal: ""
    property real diskPercent: 0

    property var prevIdle: -1
    property var prevTotal: -1

    Process {
        id: cpuPoll
        command: ["sh", "-c", "head -n1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Fields after "cpu": user nice system idle iowait irq softirq steal
                const fields = this.text.trim().split(/\s+/).slice(1).map(Number);
                const idle = fields[3] + fields[4];
                const total = fields.reduce((a, b) => a + b, 0);
                if (root.prevTotal >= 0) {
                    const totalDelta = total - root.prevTotal;
                    const idleDelta = idle - root.prevIdle;
                    if (totalDelta > 0)
                        root.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - idleDelta / totalDelta)));
                }
                root.prevIdle = idle;
                root.prevTotal = total;
            }
        }
    }

    Process {
        id: ramPoll
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                let total = 0, available = 0;
                for (const line of lines) {
                    const [key, value] = line.split(":");
                    const kb = parseInt(value.trim(), 10);
                    if (key === "MemTotal")
                        total = kb;
                    else if (key === "MemAvailable")
                        available = kb;
                }
                if (total > 0)
                    root.ramPercent = Math.max(0, Math.min(100, 100 * (1 - available / total)));
            }
        }
    }

    Process {
        id: tempPoll
        command: ["sh", "-c", "for f in /sys/class/thermal/thermal_zone*/temp; do cat \"$f\" 2>/dev/null; done | sort -rn | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const millidegrees = parseInt(this.text.trim(), 10);
                root.tempCelsius = isNaN(millidegrees) ? -1 : Math.round(millidegrees / 1000);
            }
        }
    }

    Process {
        id: diskPoll
        command: ["sh", "-c", "df -h --output=used,size,pcent / | tail -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = this.text.trim().split(/\s+/);
                if (fields.length === 3) {
                    root.diskUsed = fields[0];
                    root.diskTotal = fields[1];
                    root.diskPercent = parseInt(fields[2], 10) || 0;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuPoll.running = true;
            ramPoll.running = true;
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tempPoll.running = true
    }

    Timer {
        interval: 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskPoll.running = true
    }
}
