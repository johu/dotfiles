import QtQuick
import Quickshell.Io

// Logic-only: polls CPU/RAM/temp/disk and exposes the values. No visual
// representation of its own — see SystemResourcesCard.qml for that,
// embedded in Dashboard.qml's expand section.
Item {
    id: root

    property real cpuPercent: 0
    property string cpuModel: ""
    property int cpuCores: 0

    property real ramPercent: 0
    property string ramUsedStr: ""
    property string ramTotalStr: ""
    property string ramFreeStr: ""

    property int tempCelsius: -1

    // Root filesystem's percent, kept separately for SystemResourcesRow.qml's
    // one-line summary (which can't show every disk) - everything else about
    // disks lives in the `disks` model below.
    property real rootDiskPercent: 0

    // One ListModel entry per local disk ({mount, used, total, percent}).
    // Updated in place (set/append/remove) rather than reassigned wholesale
    // each poll - a fresh array/object literal gets a new identity every
    // tick, which makes a Repeater destroy and recreate every delegate and
    // flicker continuously while visible (see ResourceRow.qml's own note
    // on the same footgun for the old single-disk row).
    property alias disks: disksModel
    ListModel {
        id: disksModel
    }

    property var prevIdle: -1
    property var prevTotal: -1

    function formatGiB(kb) {
        return (kb / 1048576).toFixed(1) + " GiB";
    }

    Process {
        id: cpuInfoPoll
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo; nproc"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length >= 2) {
                    root.cpuModel = lines[0].split(":")[1]?.trim() ?? "";
                    root.cpuCores = parseInt(lines[1], 10) || 0;
                }
            }
        }
    }
    Component.onCompleted: cpuInfoPoll.running = true

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
                if (total > 0) {
                    root.ramPercent = Math.max(0, Math.min(100, 100 * (1 - available / total)));
                    root.ramUsedStr = root.formatGiB(total - available);
                    root.ramTotalStr = root.formatGiB(total);
                    root.ramFreeStr = root.formatGiB(available);
                }
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
        // Local block-device mounts only - tmpfs/devtmpfs/efivarfs (RAM-backed)
        // and network filesystems (nfs/nfs4) aren't "disks" in the sense the
        // dashboard cares about.
        command: ["sh", "-c", "df -h -x tmpfs -x devtmpfs -x efivarfs -x nfs -x nfs4 -x overlay -x squashfs --output=target,used,size,pcent | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set();
                for (const line of this.text.trim().split("\n")) {
                    const fields = line.trim().split(/\s+/);
                    if (fields.length !== 4)
                        continue;
                    const [mount, used, total, pcent] = fields;
                    const percent = parseInt(pcent, 10) || 0;
                    seen.add(mount);

                    if (mount === "/")
                        root.rootDiskPercent = percent;

                    let idx = -1;
                    for (let i = 0; i < disksModel.count; i++) {
                        if (disksModel.get(i).mount === mount) {
                            idx = i;
                            break;
                        }
                    }
                    if (idx >= 0)
                        disksModel.set(idx, {
                            mount,
                            used,
                            total,
                            percent
                        });
                    else
                        disksModel.append({
                            mount,
                            used,
                            total,
                            percent
                        });
                }

                for (let i = disksModel.count - 1; i >= 0; i--) {
                    if (!seen.has(disksModel.get(i).mount))
                        disksModel.remove(i);
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
