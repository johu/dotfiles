import QtQuick
import Quickshell
import Quickshell.Io
import "SysMonFormat.js" as Fmt

// Data of the launcher's system view: runs scripts/sysmon.py (one JSON sample
// per second) only while this item exists, keeps 5 minutes of history per
// metric and answers `info(key)` for the sidebar tiles and the detail pane.
Item {
    id: root

    property bool running: true
    property bool ready: false
    property var s: ({})        // latest sample
    property var procs: []      // latest process list (every 2 s)
    property int procCount: 0
    property var hist: ({})     // metric -> numbers, newest last
    property var keys: []       // resource keys, stable while the set is stable
    readonly property int maxSamples: 300

    // Test hook: a directory with a fake power_supply tree (see sysmon.py).
    property string psuDir: ""

    Process {
        // `env` rather than Process.environment, which did not reach the child.
        command: (root.psuDir !== "" ? ["env", "SYSMON_PSU=" + root.psuDir] : []).concat(["python3", "-I", Quickshell.shellPath("scripts/sysmon.py")])
        running: root.running

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.consume(data)
        }
    }

    function consume(data) {
        let o;
        try {
            o = JSON.parse(data);
        } catch (e) {
            return;
        }
        const h = Object.assign({}, root.hist);
        const add = (k, v) => {
            const a = (h[k] ?? []).concat([v ?? 0]);
            h[k] = a.length > root.maxSamples ? a.slice(a.length - root.maxSamples) : a;
        };
        add("cpu", o.cpu.total);
        add("mem", o.mem.total > 0 ? 100 * o.mem.used / o.mem.total : 0);
        add("cputemp", o.cpuTemp);
        o.gpu.forEach((g, i) => {
            add("gpu:" + i, g.util);
            add("gpuvram:" + i, g.vramTotal > 0 ? 100 * g.vramUsed / g.vramTotal : 0);
            add("gputemp:" + i, g.temp);
        });
        o.disks.forEach(d => {
            add("diskr:" + d.name, d.readBps);
            add("diskw:" + d.name, d.writeBps);
        });
        o.net.forEach(n => {
            add("netrx:" + n.name, n.rxBps);
            add("nettx:" + n.name, n.txBps);
        });
        if (o.battery) {
            add("batt", o.battery.percent);
        }
        root.hist = h;
        if (o.procs) {
            root.procs = o.procs;
            root.procCount = o.procs.length;
            delete o.procs;
        }
        root.s = o;

        const k = ["cpu", "mem"];
        o.gpu.forEach((_, i) => k.push("gpu:" + i));
        if (o.mounts.length > 0)
            k.push("storage");
        o.disks.forEach(d => k.push("disk:" + d.name));
        o.net.forEach(n => k.push("net:" + n.name));
        if (o.temps.length > 0)
            k.push("temps");
        if (o.battery)
            k.push("battery");
        if (k.join("|") !== root.keys.join("|"))
            root.keys = k;
        root.ready = true;
    }

    // Top applications by cpu ("cpu", % of one core) or memory ("mem", bytes).
    function topBy(field, n) {
        const g = {};
        for (const p of root.procs) {
            if (p.kernel)
                continue;
            const k = p.exe || p.name;
            g[k] = (g[k] ?? 0) + p[field];
        }
        return Object.keys(g).map(k => ({ name: k, value: g[k] })).sort((a, b) => b.value - a.value).slice(0, n);
    }

    // One tile / detail description per resource key; reads s and hist, so a
    // binding that calls it follows every sample.
    function info(key) {
        const s = root.s, h = root.hist;
        const empty = { title: "", sub: "", tile: "", color: Theme.blue, unit: "%", max: 100, series: [], stats: [] };
        if (!s.cpu)
            return empty;
        const sep = key.indexOf(":");
        const type = sep < 0 ? key : key.slice(0, sep);
        const id = sep < 0 ? "" : key.slice(sep + 1);
        switch (type) {
        case "cpu":
            return {
                title: "CPU",
                sub: s.cpu.model + "  ·  " + s.cpu.physical + " cores, " + s.cpu.threads + " threads",
                tile: Fmt.pct(s.cpu.total) + "   " + Fmt.ghz(s.cpu.freqMhz),
                color: Theme.blue, unit: "%", max: 100,
                series: [{ values: h.cpu, color: Theme.blue }],
                stats: [
                    ["Utilization", Fmt.pct(s.cpu.total)],
                    ["Speed", Fmt.ghz(s.cpu.freqMhz)],
                    ["Highest core", Fmt.ghz(s.cpu.maxMhz)],
                    ["Temperature", Fmt.temp(s.cpuTemp)],
                    ["Load average", s.cpu.load.map(x => x.toFixed(2)).join(" / ")],
                    ["Processes", String(root.procCount)],
                    ["Threads", String(s.cpu.threadsTotal)],
                    ["Running", String(s.cpu.running)],
                    ["Context switches", Math.round(s.cpu.ctxt / 1000) + " k/s"]
                ]
            };
        case "mem": {
            const m = s.mem;
            return {
                title: "Memory",
                sub: Fmt.bytes(m.total) + " total  ·  swap " + Fmt.bytes(m.swapTotal),
                tile: Fmt.bytes(m.used) + " / " + Fmt.bytes(m.total) + "   " + Fmt.pct(100 * m.used / m.total),
                color: Theme.mauve, unit: "%", max: 100,
                series: [{ values: h.mem, color: Theme.mauve }],
                stats: [
                    ["In use", Fmt.bytes(m.used)],
                    ["Available", Fmt.bytes(m.avail)],
                    ["Cached", Fmt.bytes(m.cached)],
                    ["Buffers", Fmt.bytes(m.buffers)],
                    ["Free", Fmt.bytes(m.free)],
                    ["Swap used", m.swapTotal > 0 ? Fmt.bytes(m.swapUsed) + " / " + Fmt.bytes(m.swapTotal) : "no swap"]
                ]
            };
        }
        case "gpu": {
            const i = parseInt(id), g = s.gpu[i];
            if (!g)
                return empty;
            return {
                title: s.gpu.length > 1 ? "GPU " + i : "GPU",
                sub: g.name,
                tile: g.name.replace(/^NVIDIA GeForce |^AMD /, "") + "   " + Fmt.pct(g.util) + (g.temp !== null ? "   " + Math.round(g.temp) + "°" : ""),
                color: Theme.green, unit: "%", max: 100,
                series: [{ values: h["gpu:" + i], color: Theme.green }, { values: h["gpuvram:" + i], color: Theme.mauve }],
                stats: [
                    ["Utilization", Fmt.pct(g.util)],
                    ["VRAM", g.vramTotal > 0 ? Fmt.bytes(g.vramUsed) + " / " + Fmt.bytes(g.vramTotal) : "–"],
                    ["Temperature", Fmt.temp(g.temp)],
                    ["Power", g.power !== null ? Fmt.watts(g.power) + (g.powerLimit ? " / " + Fmt.watts(g.powerLimit) : "") : "–"],
                    ["Fan", g.fan !== null ? Math.round(g.fan) + " %" : "–"],
                    ["Core clock", g.clock ? Math.round(g.clock) + " MHz" : "–"],
                    ["Memory clock", g.memClock ? Math.round(g.memClock) + " MHz" : "–"]
                ],
                legend: [["Utilization", Theme.green], ["VRAM", Theme.mauve]]
            };
        }
        case "storage": {
            const worst = s.mounts.reduce((a, m) => Math.max(a, m.percent), 0);
            return {
                title: "Storage",
                sub: s.mounts.length + " filesystems",
                tile: s.mounts.slice(0, 3).map(m => m.mount + " " + Math.round(m.percent) + " %").join("   "),
                color: Theme.sky, unit: "%", max: 100, series: [], stats: [], worst: worst
            };
        }
        case "disk": {
            const d = s.disks.find(x => x.name === id);
            if (!d)
                return empty;
            return {
                title: "Disk " + id,
                sub: (d.model || "Disk") + "  ·  " + Fmt.bytes(d.size),
                tile: "R " + Fmt.rate(d.readBps) + "   W " + Fmt.rate(d.writeBps),
                color: Theme.sky, unit: "rate", max: 0,
                series: [{ values: h["diskr:" + id], color: Theme.sky }, { values: h["diskw:" + id], color: Theme.mauve }],
                stats: [
                    ["Read", Fmt.rate(d.readBps)],
                    ["Write", Fmt.rate(d.writeBps)],
                    ["Active time", Fmt.pct(d.util)],
                    ["Capacity", Fmt.bytes(d.size)],
                    ["Temperature", Fmt.temp(d.temp)],
                    ["Model", d.model || "–"]
                ],
                legend: [["Read", Theme.sky], ["Write", Theme.mauve]]
            };
        }
        case "net": {
            const n = s.net.find(x => x.name === id);
            if (!n)
                return empty;
            return {
                title: (n.kind === "wifi" ? "Wi-Fi " : "Ethernet ") + id,
                sub: n.state === "up" ? (n.ip || "connected") + (n.speed > 0 ? "  ·  " + n.speed + " Mbit/s" : "") : "not connected",
                tile: n.state === "up" ? "↓ " + Fmt.rate(n.rxBps) + "   ↑ " + Fmt.rate(n.txBps) : "not connected",
                color: Theme.teal, unit: "rate", max: 0,
                series: [{ values: h["netrx:" + id], color: Theme.teal }, { values: h["nettx:" + id], color: Theme.blue }],
                stats: [
                    ["Download", Fmt.rate(n.rxBps)],
                    ["Upload", Fmt.rate(n.txBps)],
                    ["Received", Fmt.bytes(n.rxTotal)],
                    ["Sent", Fmt.bytes(n.txTotal)],
                    ["IPv4", n.ip || "–"],
                    ["Link", n.state + (n.speed > 0 ? ", " + n.speed + " Mbit/s" : "")]
                ],
                legend: [["Download", Theme.teal], ["Upload", Theme.blue]]
            };
        }
        case "temps": {
            const nv = s.temps.filter(t => t.chip === "nvme" && t.label === "Composite");
            const hot = nv.reduce((a, t) => Math.max(a, t.value), 0);
            const series = [{ values: h.cputemp, color: Theme.maroon }];
            if (s.gpu.length > 0)
                series.push({ values: h["gputemp:0"], color: Theme.green });
            return {
                title: "Temperatures",
                sub: s.temps.length + " sensors" + (s.fans.length > 0 ? ", " + s.fans.length + " fans" : ""),
                tile: "CPU " + Math.round(s.cpuTemp ?? 0) + "°" + (s.gpu.length > 0 && s.gpu[0].temp !== null ? "  GPU " + Math.round(s.gpu[0].temp) + "°" : "") + (hot > 0 ? "  NVMe " + Math.round(hot) + "°" : ""),
                color: Theme.maroon, unit: "°C", max: 100,
                series: series,
                stats: [],
                legend: [["CPU", Theme.maroon]].concat(s.gpu.length > 0 ? [["GPU", Theme.green]] : [])
            };
        }
        case "battery": {
            const b = s.battery;
            if (!b)
                return empty;
            return {
                title: "Battery",
                sub: b.status + (b.ac ? "  ·  AC connected" : ""),
                tile: Fmt.pct(b.percent) + "   " + b.status + (b.powerW > 0 ? "   " + Fmt.watts(b.powerW) : ""),
                color: Theme.green, unit: "%", max: 100,
                series: [{ values: h.batt, color: Theme.green }],
                stats: [
                    ["Charge", Fmt.pct(b.percent)],
                    ["Status", b.status],
                    ["Power draw", Fmt.watts(b.powerW)],
                    [b.status === "Charging" ? "Until full" : "Time remaining", Fmt.remaining(b.secondsLeft)],
                    ["Health", b.energyDesign > 0 ? Math.round(100 * b.energyFull / b.energyDesign) + " %" : "–"],
                    ["Energy", b.energyNow.toFixed(1) + " / " + b.energyFull.toFixed(1) + " Wh"],
                    ["Cycles", b.cycles !== null ? String(Math.round(b.cycles)) : "–"],
                    ["AC adapter", b.ac ? "connected" : "not connected"]
                ]
            };
        }
        }
        return empty;
    }
}
