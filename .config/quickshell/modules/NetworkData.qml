pragma Singleton
import QtQuick
import Quickshell

// Network: the single owner of the netinfo.py snapshot (devices, saved
// connections, optionally access points) and of per-interface throughput
// (read from SystemData, which samples /proc/net/dev for sysmon.py).
// Views register with Consumer { target: NetworkData; active: ... }; views
// that list access points also hold a Consumer with counter "apConsumers".
// The snapshot is polled every 10 s while any consumer is active.
Singleton {
    id: root

    property int consumers: 0
    property int apConsumers: 0

    // Test hook: env for netinfo.py (e.g. NETINFO_NMCLI), forwarded by the
    // launcher view's fixture harness.
    property var testEnv: ({})

    // ---- Shared data vocabulary ----
    readonly property bool loaded: fetcher.loaded
    readonly property bool loading: fetcher.loading
    readonly property string error: fetcher.error
    readonly property real updatedAt: fetcher.updatedAt
    function refresh(force) {
        fetcher.refresh(force);
    }

    // { devices, saved, aps, ... }; always has the three lists.
    readonly property var snap: Object.assign({ devices: [], saved: [], aps: [] }, fetcher.value ?? {})
    // The snapshot includes access points (an apConsumer asked for them).
    readonly property bool apsLoaded: fetcher.value !== null && fetcher.value.aps !== undefined

    // First connected ethernet device, else connected wifi device.
    readonly property var activeDevice: root.snap.devices.find(d => d.type === "ethernet" && d.state === "connected") ?? root.snap.devices.find(d => d.type === "wifi" && d.state === "connected") ?? null
    readonly property string activeIface: root.activeDevice ? root.activeDevice.name : ""

    function device(name) {
        return name === "" ? null : (root.snap.devices.find(d => d.name === name) ?? null);
    }

    // Current throughput of an interface in bytes/s, {rx, tx}.
    function rate(iface) {
        const n = (SystemData.s.net ?? []).find(x => x.name === iface);
        return n ? { rx: n.rxBps, tx: n.txBps } : { rx: 0, tx: 0 };
    }

    // Last `count` throughput samples, oldest first.
    function history(iface, count) {
        return {
            rx: (SystemData.hist["netrx:" + iface] ?? []).slice(-count),
            tx: (SystemData.hist["nettx:" + iface] ?? []).slice(-count)
        };
    }

    // A change is about to show up in nmcli (connect, forget, toggle):
    // refresh a few times while it settles.
    property int soonLeft: 0
    function refreshSoon() {
        root.soonLeft = 3;
        soonTimer.restart();
    }
    Timer {
        id: soonTimer
        interval: 1500
        repeat: true
        onTriggered: {
            root.refresh(true);
            if (--root.soonLeft <= 0)
                stop();
        }
    }

    onApConsumersChanged: if (root.apConsumers > 0 && root.consumers > 0 && !root.apsLoaded) root.refresh(true)

    Consumer {
        target: SystemData
        active: root.consumers > 0
    }

    Fetcher {
        id: fetcher
        active: root.consumers > 0
        interval: 10000
        staleAfter: 3000
        failureText: "Could not read the network state"
        env: root.testEnv
        command: ["python3", "-I", Quickshell.shellPath("scripts/netinfo.py"), "snapshot"].concat(root.apConsumers > 0 ? ["--aps"] : [])
        // An access-point consumer arrived while a snapshot without aps was in flight.
        onFetched: d => {
            if (root.apConsumers > 0 && d.aps === undefined)
                Qt.callLater(() => root.refresh(true));
        }
    }
}
