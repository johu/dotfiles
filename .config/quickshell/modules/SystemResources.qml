import QtQuick

// Logic-only adapter for the dashboard (see SystemResourcesCard.qml for the
// UI). Owns no processes: it mirrors the shared SystemData sample while
// `active` (the dashboard being open) and keeps the last values otherwise.
Item {
    id: root

    // Bind to the dashboard's visibility; keeps SystemData sampling.
    property bool active: false

    property real cpuPercent: 0
    property string cpuModel: ""
    property int cpuCores: 0

    property real ramPercent: 0
    property string ramUsedStr: ""
    property string ramTotalStr: ""
    property string ramFreeStr: ""

    property int tempCelsius: -1

    // Root filesystem percent for the one-line summary; other disk data lives
    // in `disks`.
    property real rootDiskPercent: 0

    // One ListModel entry per local disk ({mount, used, total, percent}).
    // Updated in place: a fresh array literal each poll recreates every
    // Repeater delegate and flickers (see ResourceRow.qml).
    property alias disks: disksModel
    ListModel {
        id: disksModel
    }

    Consumer {
        target: SystemData
        active: root.active
    }

    function formatGiB(bytes) {
        return (bytes / 1073741824).toFixed(1) + " GiB";
    }

    // df -h style: 1024 units, one decimal below 10, rounded up.
    function formatDf(bytes) {
        const units = ["B", "K", "M", "G", "T", "P"];
        let v = bytes, i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (v < 10 && i > 0 ? (Math.ceil(v * 10) / 10).toFixed(1) : String(Math.ceil(v))) + units[i];
    }

    function sync() {
        const s = SystemData.s;
        if (!s || !s.cpu)
            return;
        root.cpuPercent = Math.max(0, Math.min(100, s.cpu.total));
        root.cpuModel = s.cpu.model ?? "";
        root.cpuCores = s.cpu.threads ?? 0;

        if (s.mem && s.mem.total > 0) {
            root.ramPercent = Math.max(0, Math.min(100, 100 * s.mem.used / s.mem.total));
            root.ramUsedStr = root.formatGiB(s.mem.used);
            root.ramTotalStr = root.formatGiB(s.mem.total);
            root.ramFreeStr = root.formatGiB(s.mem.avail);
        }

        root.tempCelsius = (s.cpuTemp === null || s.cpuTemp === undefined) ? -1 : Math.round(s.cpuTemp);

        const seen = new Set();
        for (const m of s.mounts ?? []) {
            const entry = {
                mount: m.mount,
                used: root.formatDf(m.used),
                total: root.formatDf(m.total),
                percent: Math.ceil(m.percent)
            };
            seen.add(m.mount);
            if (m.mount === "/")
                root.rootDiskPercent = entry.percent;
            let idx = -1;
            for (let i = 0; i < disksModel.count; i++) {
                if (disksModel.get(i).mount === m.mount) {
                    idx = i;
                    break;
                }
            }
            if (idx >= 0)
                disksModel.set(idx, entry);
            else
                disksModel.append(entry);
        }
        for (let i = disksModel.count - 1; i >= 0; i--) {
            if (!seen.has(disksModel.get(i).mount))
                disksModel.remove(i);
        }
    }

    Connections {
        target: SystemData
        function onSChanged() {
            root.sync();
        }
    }

    Component.onCompleted: root.sync()
}
