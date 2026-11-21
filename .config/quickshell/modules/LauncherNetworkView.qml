import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "SysMonFormat.js" as Fmt

// Network view of the launcher (NetworkManager): wired, VPN profiles and a
// scrolling Wi-Fi list on the left, a detail card on the right.
//
//   Data      native Quickshell.Networking (networks in range, live state,
//             connect / connectWithPsk / disconnect / forget) plus ONE helper
//             script (scripts/netinfo.py: nmcli for what the native API lacks:
//             saved profiles incl. out-of-range and VPN, band / channel,
//             addresses, secrets). The snapshot is owned by the NetworkData
//             singleton (shared with the dashboard card); throughput history
//             comes from SystemData. Passwords never go on a command line.
//   Keys      j k g G Ctrl-d/u move, Enter connect / disconnect (wired asks twice),
//             / filter, r rescan, n add (hidden) network, a autoconnect, f forget
//             (twice), p show the saved password, Q QR to share a network,
//             y copy IP, o open captive-portal login, w Wi-Fi radio, m weak
//             networks, q close.
//
// Test hook: `fixture` replaces the live data, e.g.
//   { connectivity: "full", wifiOn: true, hasWifi: true,
//     info: <netinfo snapshot shape>, nets: [{ name, signalStrength (0..1),
//     security: "open" | "WPA2" | ..., known, connected, state }] }
// Actions on fixture networks are logged (console.warn "NETVIEW-ACTION ...").
// `testEnv` (env for netinfo.py, e.g. NETINFO_NMCLI) and `nmcliBin` are test hooks too.
Item {
    id: view

    property int textRender: Text.NativeRendering
    property var fixture: null
    property var testEnv: ({})
    property string nmcliBin: "nmcli"

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1700
    readonly property int preferredHeight: 950

    readonly property bool live: view.fixture === null

    // ---------------------------------------------------------------- state
    readonly property var wifiDevice: view.live ? (Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null) : null
    readonly property bool hasBackend: view.live ? Networking.backend === NetworkBackendType.NetworkManager : true
    readonly property bool hasWifiDev: view.live ? view.wifiDevice !== null : view.fixture.hasWifi !== false
    readonly property bool wifiOn: view.live ? Networking.wifiEnabled : view.fixture.wifiOn !== false
    readonly property bool wifiHw: view.live ? Networking.wifiHardwareEnabled : true

    readonly property string connectivity: {
        if (!view.live)
            return view.fixture.connectivity ?? "full";
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return "full";
        case NetworkConnectivity.Limited:
            return "limited";
        case NetworkConnectivity.Portal:
            return "portal";
        case NetworkConnectivity.None:
            return "none";
        }
        return "unknown";
    }

    // netinfo snapshot (see scripts/netinfo.py)
    readonly property var snap: NetworkData.snap
    readonly property var info: view.live ? view.snap : (view.fixture.info ?? ({ devices: [], saved: [], aps: [] }))
    // Loaded once the shared snapshot includes access points.
    readonly property bool infoLoaded: view.live && NetworkData.loaded && NetworkData.apsLoaded
    // The wired / VPN rows only exist once the first snapshot arrived: start on
    // the first row of the complete list, not on whatever was there before.
    onInfoLoadedChanged: if (view.infoLoaded)
        view.selectedKey = view.items.length > 0 ? view.items[0].key : ""
    property double now: Date.now()

    readonly property var nets: {
        if (!view.live)
            return view.fixture.nets ?? [];
        return view.wifiDevice ? [...view.wifiDevice.networks.values] : [];
    }

    function secLabel(n) {
        const s = n.security;
        if (typeof s === "string")
            return s;
        switch (s) {
        case WifiSecurityType.Open:
            return "open";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa3SuiteB192:
            return "Enterprise";
        case WifiSecurityType.Leap:
            return "LEAP";
        }
        return "unknown";
    }
    function isOpen(label) {
        return label === "open" || label === "OWE";
    }
    function bucket(sig) {
        return sig > 0.66 ? 3 : (sig > 0.33 ? 2 : (sig > 0.12 ? 1 : 0));
    }
    function barLevel(sig) {
        return sig > 0.75 ? 4 : (sig > 0.5 ? 3 : (sig > 0.25 ? 2 : (sig > 0.05 ? 1 : 0)));
    }
    function wifiGlyph(sig) {
        return ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"][view.barLevel(sig)];
    }

    // ------------------------------------------------------------ rows
    property string selectedKey: ""
    property string filter: ""
    property bool searching: false
    property bool showWeak: false
    readonly property real weakLimit: 0.15

    function savedWifiBySsid(ssid) {
        return view.info.saved.find(s => s.type === "wifi" && s.ssid === ssid) ?? null;
    }
    function apBySsid(ssid) {
        return (view.info.aps ?? []).find(a => a.ssid === ssid) ?? null;
    }

    readonly property var wiredRows: view.info.devices.filter(d => d.type === "ethernet").map(d => ({
                    type: "wired",
                    key: "e:" + d.name,
                    dev: d,
                    saved: view.info.saved.find(s => s.type === "ethernet" && (s.device === d.name || s.id === d.connection)) ?? null
                }))
    readonly property var vpnRows: view.info.saved.filter(s => s.type === "vpn").map(s => ({ type: "vpn", key: "v:" + s.uuid, saved: s }))

    readonly property var pinnedRows: {
        const out = [];
        if (view.wiredRows.length > 0) {
            out.push({ type: "header", key: "h-wired", title: "Wired" });
            for (const r of view.wiredRows)
                out.push(r);
        }
        if (view.hasBackend) {
            out.push({ type: "header", key: "h-vpn", title: "VPN" });
            for (const r of view.vpnRows)
                out.push(r);
            if (view.vpnRows.length === 0)
                out.push({ type: "emptyvpn", key: "e-vpn" });
        }
        return out;
    }

    // interface name of the Wi-Fi adapter (shown next to the Wi-Fi header and in the card)
    readonly property string wifiIface: view.live ? (view.wifiDevice ? view.wifiDevice.name : "") : ((view.info.devices.find(d => d.type === "wifi") ?? ({ name: "" })).name)

    readonly property int headerH: 44
    readonly property int rowH: 60
    readonly property int dividerH: 36
    readonly property int pinnedH: view.pinnedRows.reduce((h, r) => h + (r.type === "header" ? view.headerH : view.rowH) + 4, 0)

    // Wi-Fi: built by a binding, applied only when its signature changes so
    // signal jitter does not rebuild the list.
    property var wifiRows: []
    property int wifiTotal: 0
    property int weakHidden: 0
    property int savedAway: 0

    function matches(ssid) {
        const q = view.filter.trim().toLowerCase();
        return q === "" || q.split(/\s+/).every(w => ssid.toLowerCase().indexOf(w) >= 0);
    }

    function buildWifi() {
        const res = { rows: [], total: 0, weak: 0, away: 0 };
        if (!view.wifiOn || !view.hasWifiDev)
            return res;
        const filtering = view.filter.trim() !== "";
        const names = {};
        const near = [];
        for (const n of view.nets) {
            if (!n.name || names[n.name])
                continue;
            names[n.name] = true;
            const sv = view.savedWifiBySsid(n.name);
            near.push({ type: "wifi", key: "s:" + n.name, ssid: n.name, net: n, saved: sv, ap: view.apBySsid(n.name), inRange: true, known: n.known || sv !== null });
        }
        res.total = near.length;
        near.sort((a, b) => (b.net.connected - a.net.connected) || (b.known - a.known) || (view.bucket(b.net.signalStrength) - view.bucket(a.net.signalStrength)) || a.ssid.localeCompare(b.ssid));
        for (const r of near) {
            if (!view.matches(r.ssid))
                continue;
            const weak = r.net.signalStrength < view.weakLimit && !r.net.connected && !r.known && r.key !== view.selectedKey;
            if (weak && !view.showWeak && !filtering) {
                res.weak++;
                continue;
            }
            res.rows.push(r);
        }
        const away = view.info.saved.filter(s => s.type === "wifi" && s.ssid !== "" && !names[s.ssid] && view.matches(s.ssid)).sort((a, b) => a.ssid.localeCompare(b.ssid));
        res.away = away.length;
        if (away.length > 0) {
            res.rows.push({ type: "divider", key: "d-away", title: "Saved · not in range" });
            for (const s of away)
                res.rows.push({ type: "wifi", key: "s:" + s.ssid, ssid: s.ssid, net: null, saved: s, ap: null, inRange: false, known: true });
        }
        return res;
    }

    readonly property var wifiBuilt: view.buildWifi()

    function sigOf(rows) {
        return rows.map(r => r.key + "|" + (r.saved ? r.saved.uuid + (r.saved.autoconnect ? "a" : "n") : "-") + "|" + (r.ap ? r.ap.best.band + r.ap.best.chan + r.ap.count : "-") + "|" + (r.net ? view.secLabel(r.net) : "")).join("\n");
    }

    function applyWifi() {
        const b = view.wifiBuilt;
        if (view.sigOf(b.rows) !== view.sigOf(view.wifiRows))
            view.wifiRows = b.rows;
        view.wifiTotal = b.total;
        view.weakHidden = b.weak;
        view.savedAway = b.away;
        // while filtering, keep the selection on a visible match
        if (view.filter.trim() !== "") {
            const sel = view.selected;
            const shown = sel && sel.type === "wifi" && view.wifiRows.some(r => r.key === sel.key);
            const first = view.wifiRows.find(r => r.type === "wifi");
            if (!shown && first)
                view.selectedKey = first.key;
        }
        view.ensureSelection();
    }

    onWifiBuiltChanged: view.applyWifi()

    readonly property var items: view.wiredRows.concat(view.vpnRows).concat(view.wifiRows.filter(r => r.type === "wifi"))
    readonly property var selected: view.items.find(r => r.key === view.selectedKey) ?? null

    function ensureSelection() {
        if (view.selected)
            return;
        view.selectedKey = view.items.length > 0 ? view.items[0].key : "";
    }
    onItemsChanged: view.ensureSelection()

    function moveSelection(delta) {
        const list = view.items;
        if (list.length === 0)
            return;
        const i = list.findIndex(r => r.key === view.selectedKey);
        view.selectedKey = list[Math.max(0, Math.min(list.length - 1, (i < 0 ? 0 : i) + delta))].key;
    }
    function selectEdge(last) {
        const list = view.items;
        if (list.length > 0)
            view.selectedKey = list[last ? list.length - 1 : 0].key;
    }
    onSelectedKeyChanged: {
        view.hidePrivate();
        view.wiredArm = "";
        view.forgetArm = "";
        view.autoArm = "";
    }

    // --------------------------------------------------- per-row state
    function rowConnected(r) {
        if (!r)
            return false;
        if (r.type === "wifi")
            return r.net ? r.net.connected : false;
        if (r.type === "wired")
            return r.dev.state === "connected";
        if (r.type === "vpn")
            return r.saved.active;
        return false;
    }
    function rowBusy(r) {
        if (!r)
            return false;
        if (cmdProc.running && cmdProc.key === r.key)
            return true;
        if (r.type === "wifi" && r.net && view.live)
            return r.net.state === ConnectionState.Connecting || r.net.state === ConnectionState.Disconnecting;
        if (r.type === "wifi" && r.net && !view.live)
            return r.net.state === "connecting";
        return false;
    }
    function rowSub(r) {
        if (r.type === "wired")
            return view.rowBusy(r) ? "working…" : (r.dev.state === "connected" ? r.dev.name + (r.dev.speed && r.dev.speed !== "unknown" ? " · " + view.speedLabel(r.dev.speed) : "") : (r.dev.name + " · not connected"));
        if (r.type === "vpn")
            return view.rowBusy(r) ? "working…" : (r.saved.active ? "connected" : "not connected");
        if (r.type === "wifi") {
            if (!r.inRange)
                return "saved · not in range";
            const label = view.secLabel(r.net);
            if (r.net.connected && !view.rowBusy(r))
                return label;
            if (view.rowBusy(r))
                return view.live && r.net.state === ConnectionState.Disconnecting ? "disconnecting…" : "connecting…";
            return label + (r.known ? " · saved" : "");
        }
        return "";
    }
    function speedLabel(s) {
        const m = parseInt(s);
        return isNaN(m) ? s : (m >= 1000 ? (m / 1000) + " Gbit/s" : m + " Mbit/s");
    }
    function typeLabel(t) {
        const names = { fortisslvpn: "FortiSSL VPN", openvpn: "OpenVPN", wireguard: "WireGuard", vpnc: "Cisco VPN", openconnect: "OpenConnect", strongswan: "strongSwan", l2tp: "L2TP", pptp: "PPTP" };
        return names[t] ?? (t || "VPN");
    }
    function ipOf(r) {
        if (r.type === "wired")
            return r.dev.ip4.length > 0 ? r.dev.ip4[0].split("/")[0] : "";
        if (r.type === "wifi" && r.net && r.net.connected) {
            const d = view.info.devices.find(x => x.type === "wifi" && x.state === "connected");
            return d && d.ip4.length > 0 ? d.ip4[0].split("/")[0] : "";
        }
        return "";
    }

    // --------------------------------------------------------- feedback
    property string toastText: ""
    function toast(text) {
        view.toastText = text;
        toastTimer.restart();
    }
    Timer {
        id: toastTimer

        interval: 3200
        onTriggered: view.toastText = ""
    }

    property var actionLog: []
    function call(obj, name, ...args) {
        if (typeof obj[name] === "function") {
            obj[name](...args);
        } else {
            view.actionLog = view.actionLog.concat([name + ":" + (obj.name ?? "") + (args.length ? ":" + args.join(",") : "")]);
            console.warn("NETVIEW-ACTION " + name + " " + (obj.name ?? "") + " " + args.join(","));
        }
    }
    function nm(args) {
        if (!view.live) {
            view.actionLog = view.actionLog.concat(["nmcli " + args.join(" ")]);
            console.warn("NETVIEW-ACTION nmcli " + args.join(" "));
            return;
        }
        Quickshell.execDetached([view.nmcliBin].concat(args));
    }

    // ------------------------------------------------- data refresh
    readonly property var envPrefix: Object.keys(view.testEnv).length > 0 ? ["env"].concat(Object.keys(view.testEnv).map(k => k + "=" + view.testEnv[k])) : []
    readonly property string helper: Quickshell.shellPath("scripts/netinfo.py")

    // Shared snapshot: NetworkData polls netinfo.py while a Consumer is
    // active. The fixture harness's env is forwarded to it (live views only).
    Consumer {
        target: NetworkData
        active: view.live && view.visible
    }
    Consumer {
        target: NetworkData
        counter: "apConsumers"
        active: view.live && view.visible
    }
    Binding {
        target: NetworkData
        property: "testEnv"
        value: view.testEnv
        when: view.live && Object.keys(view.testEnv).length > 0
    }

    function refresh() {
        view.now = Date.now();
        if (view.live)
            NetworkData.refresh(true);
    }
    function refreshSoon() {
        if (view.live)
            NetworkData.refreshSoon();
    }
    Timer {
        interval: 10000
        running: view.live
        repeat: true
        onTriggered: {
            view.now = Date.now();
            if (view.wifiDevice && view.wifiOn)
                view.wifiDevice.scannerEnabled = true;
        }
    }
    Component.onCompleted: {
        if (view.live) {
            view.now = Date.now();
            if (view.wifiDevice)
                view.wifiDevice.scannerEnabled = true;
            // The singleton may already hold a snapshot from an earlier open.
            if (view.infoLoaded)
                view.selectedKey = view.items.length > 0 ? view.items[0].key : "";
        }
        view.applyWifi();
    }
    Component.onDestruction: {
        if (view.live && view.wifiDevice)
            view.wifiDevice.scannerEnabled = false;
    }

    // ---------------------------------------------- native watchers
    Instantiator {
        model: view.nets

        delegate: Item {
            id: watch

            required property var modelData

            Connections {
                target: typeof watch.modelData.connectWithPsk === "function" ? watch.modelData : null

                function onConnectionFailed(reason) {
                    const n = watch.modelData;
                    if (view.pskTarget && view.pskTarget.name === n.name) {
                        view.pskError = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : ConnectionFailReason.toString(reason);
                    } else {
                        view.toast("Couldn't connect to " + n.name);
                    }
                    view.refreshSoon();
                }
                function onConnectedChanged() {
                    const n = watch.modelData;
                    if (n.connected) {
                        if (view.pskTarget && view.pskTarget.name === n.name)
                            view.closePsk();
                        view.toast("Connected to " + n.name);
                    }
                    view.refreshSoon();
                }
                function onKnownChanged() {
                    view.refreshSoon();
                }
            }
        }
    }

    // -------------------------------------------------------- throughput
    readonly property string rateIface: {
        const r = view.selected;
        if (!view.live || !r || !view.rowConnected(r))
            return "";
        if (r.type === "wired")
            return r.dev.name;
        if (r.type === "vpn")
            return r.saved.device ?? "";
        const d = view.info.devices.find(x => x.type === "wifi" && x.state === "connected");
        return d ? d.name : "";
    }
    // Last minute of per-second samples from the shared system sampler.
    readonly property var rxHist: view.rateIface !== "" ? NetworkData.history(view.rateIface, 60).rx : []
    readonly property var txHist: view.rateIface !== "" ? NetworkData.history(view.rateIface, 60).tx : []

    // ------------------------------------------------------------ actions
    property string wiredArm: ""
    property string forgetArm: ""
    property string autoArm: ""

    Timer {
        id: armTimer

        interval: 3000
        onTriggered: {
            view.wiredArm = "";
            view.forgetArm = "";
            view.autoArm = "";
        }
    }

    // one nmcli job at a time (connect / disconnect of wired and VPN)
    Process {
        id: cmdProc

        property string key: ""
        property string okText: ""
        property string failText: ""

        stderr: StdioCollector {
            id: cmdErr
        }
        onExited: code => {
            if (code === 0) {
                if (cmdProc.okText !== "")
                    view.toast(cmdProc.okText);
            } else {
                const line = cmdErr.text.trim().split("\n")[0].replace(/^Error: /, "");
                view.toast(cmdProc.failText + (line !== "" ? ": " + line : ""));
            }
            cmdProc.key = "";
            view.refreshSoon();
        }
    }
    function runNm(key, args, okText, failText) {
        if (!view.live) {
            view.nm(args);
            return;
        }
        if (cmdProc.running) {
            view.toast("Busy, try again in a moment");
            return;
        }
        cmdProc.key = key;
        cmdProc.okText = okText;
        cmdProc.failText = failText;
        cmdProc.command = [view.nmcliBin, "--wait", "30"].concat(args);
        cmdProc.running = true;
    }

    function activate() {
        const r = view.selected;
        if (!r || view.pskTarget || view.adding)
            return;
        if (view.rowBusy(r))
            return;
        if (r.type === "wired") {
            if (view.rowConnected(r)) {
                // the wired link may be the only way out: ask twice
                if (view.wiredArm !== r.key) {
                    view.wiredArm = r.key;
                    armTimer.restart();
                    view.toast("Press Enter again to disconnect " + r.dev.name);
                    return;
                }
                view.wiredArm = "";
                view.runNm(r.key, ["device", "disconnect", r.dev.name], "Disconnected " + r.dev.name, "Couldn't disconnect");
            } else {
                view.runNm(r.key, ["device", "connect", r.dev.name], "Connected " + r.dev.name, "Couldn't connect " + r.dev.name);
            }
        } else if (r.type === "vpn") {
            const up = !r.saved.active;
            view.runNm(r.key, ["connection", up ? "up" : "down", "uuid", r.saved.uuid], (up ? "Connected " : "Disconnected ") + r.saved.id, "Couldn't " + (up ? "connect " : "disconnect ") + r.saved.id);
        } else if (r.type === "wifi") {
            view.activateWifi(r);
        }
    }

    function activateWifi(r) {
        const n = r.net;
        if (!n) {
            view.toast(r.ssid + " is not in range");
            return;
        }
        if (n.connected) {
            view.call(n, "disconnect");
            return;
        }
        const label = view.secLabel(n);
        if (r.known || view.isOpen(label)) {
            view.call(n, "connect");
        } else if (label === "Enterprise" || label === "LEAP") {
            view.toast(label + " networks need a profile (nm-connection-editor)");
        } else {
            view.openPsk(r);
        }
    }

    function toggleAutoconnect() {
        const r = view.selected;
        const sv = r ? r.saved : null;
        if (!r || (r.type === "wifi" && !r.known) || !sv) {
            view.toast("Not a saved connection");
            return;
        }
        // Switching autoconnect OFF on the wired profile means no network after the
        // next boot or cable replug until someone connects by hand: ask twice.
        if (r.type === "wired" && sv.autoconnect && view.autoArm !== r.key) {
            view.autoArm = r.key;
            armTimer.restart();
            view.toast("Press a again: without autoconnect there is no network after a reboot or replug");
            return;
        }
        view.autoArm = "";
        view.nm(["connection", "modify", "uuid", sv.uuid, "connection.autoconnect", sv.autoconnect ? "no" : "yes"]);
        view.toast((sv.autoconnect ? "Autoconnect off for " : "Autoconnect on for ") + (r.type === "wifi" ? r.ssid : sv.id));
        view.refreshSoon();
    }

    function forget() {
        const r = view.selected;
        if (!r || r.type !== "wifi") {
            view.toast(r && r.type === "vpn" ? "Delete VPN profiles in nm-connection-editor" : "Only Wi-Fi networks can be forgotten here");
            return;
        }
        if (!r.known) {
            view.toast(r.ssid + " is not saved");
            return;
        }
        if (view.forgetArm !== r.key) {
            view.forgetArm = r.key;
            armTimer.restart();
            view.toast("Press f again to forget " + r.ssid);
            return;
        }
        view.forgetArm = "";
        if (r.net && typeof r.net.forget === "function")
            r.net.forget();
        else if (r.saved)
            view.nm(["connection", "delete", "uuid", r.saved.uuid]);
        else
            view.call(r.net, "forget");
        view.toast("Forgot " + r.ssid);
        view.refreshSoon();
    }

    function rescan() {
        view.nm(["device", "wifi", "rescan"]);
        view.scanUntil = Date.now() + 6000;
        view.toast("Scanning…");
        scanTimer.restart();
        view.refreshSoon();
    }
    property double scanUntil: 0
    readonly property bool scanning: view.scanTick >= 0 && Date.now() < view.scanUntil
    property int scanTick: 0
    Timer {
        id: scanTimer

        interval: 1000
        repeat: true
        onTriggered: {
            view.scanTick++;
            if (Date.now() >= view.scanUntil)
                stop();
        }
    }

    function toggleWifi() {
        if (!view.hasWifiDev) {
            view.toast("No Wi-Fi adapter");
            return;
        }
        if (!view.wifiHw) {
            view.toast("Wi-Fi is switched off by a hardware switch (rfkill)");
            return;
        }
        view.nm(["radio", "wifi", view.wifiOn ? "off" : "on"]);
        view.refreshSoon();
    }

    function copyIp() {
        const ip = view.selected ? view.ipOf(view.selected) : "";
        if (ip === "") {
            view.toast("No address to copy");
            return;
        }
        if (view.live)
            Quickshell.execDetached(["wl-copy", ip]);
        else
            console.warn("NETVIEW-ACTION copy " + ip);
        view.toast("Copied " + ip);
    }

    function openEditor() {
        if (view.live && !Dependencies.has("nm-connection-editor")) {
            view.toast("nm-connection-editor is not installed");
            return;
        }
        if (view.live)
            Quickshell.execDetached(["nm-connection-editor"]);
        else
            console.warn("NETVIEW-ACTION editor");
        // the editor is a normal window: get the launcher out of its way
        view.leaveRequested();
    }

    function openLogin() {
        if (view.connectivity !== "portal") {
            view.toast("No login page needed");
            return;
        }
        if (view.live)
            Quickshell.execDetached(["xdg-open", "http://nmcheck.gnome.org/"]);
        else
            console.warn("NETVIEW-ACTION open-login");
    }

    // -------------------------------------------- password prompt (join)
    property var pskTarget: null   // the row
    property string pskText: ""
    property string pskError: ""
    property bool pskShow: false

    function openPsk(r) {
        view.pskTarget = r.net;
        view.pskText = "";
        view.pskError = "";
        view.pskShow = false;
    }
    function closePsk() {
        view.pskTarget = null;
        view.pskText = "";
        view.pskError = "";
    }
    function submitPsk() {
        if (view.pskText.length < 8) {
            view.pskError = "At least 8 characters";
            return;
        }
        view.pskError = "";
        view.call(view.pskTarget, "connectWithPsk", view.pskText);
        view.toast("Connecting to " + view.pskTarget.name + "…");
    }

    // ------------------------------------------- add (hidden) network
    property bool adding: false
    property string addSsid: ""
    property int addSec: 0          // index into secOptions
    property string addPass: ""
    property int addField: 0        // 0 ssid, 1 security, 2 password
    property bool addShow: false
    property string addError: ""
    property bool addBusy: false
    readonly property var secOptions: [{ id: "wpa-psk", label: "WPA / WPA2 / WPA3 Personal" }, { id: "sae", label: "WPA3 only (SAE)" }, { id: "open", label: "Open (no password)" }]
    readonly property bool addNeedsPass: view.secOptions[view.addSec].id !== "open"

    function openAdd() {
        if (!view.hasWifiDev || !view.wifiOn) {
            view.toast("Turn Wi-Fi on first (w)");
            return;
        }
        view.addSsid = "";
        view.addPass = "";
        view.addSec = 0;
        view.addField = 0;
        view.addShow = false;
        view.addError = "";
        view.addBusy = false;
        view.adding = true;
    }
    function closeAdd() {
        view.adding = false;
        view.addPass = "";
    }
    function submitAdd() {
        if (view.addBusy)
            return;
        if (view.addSsid.trim() === "") {
            view.addError = "Network name is required";
            view.addField = 0;
            return;
        }
        if (view.addNeedsPass && view.addPass.length < 8) {
            view.addError = "WPA passwords are at least 8 characters";
            view.addField = 2;
            return;
        }
        view.addError = "";
        if (!view.live) {
            view.actionLog = view.actionLog.concat(["connect-new:" + view.addSsid + ":" + view.secOptions[view.addSec].id]);
            console.warn("NETVIEW-ACTION connect-new " + view.addSsid + " " + view.secOptions[view.addSec].id);
            view.closeAdd();
            return;
        }
        view.addBusy = true;
        addProc.command = view.envPrefix.concat(["python3", "-I", view.helper, "connect-new", view.addSsid.trim(), view.secOptions[view.addSec].id]);
        addProc.running = true;
    }
    Process {
        id: addProc

        stdinEnabled: true
        stderr: StdioCollector {
            id: addErr
        }
        onRunningChanged: if (running && view.addNeedsPass)
            write(view.addPass + "\n")
        onExited: code => {
            view.addBusy = false;
            if (code === 0) {
                const s = view.addSsid.trim();
                view.closeAdd();
                view.toast("Connected to " + s);
                view.refreshSoon();
            } else {
                const line = addErr.text.trim().split("\n").pop().replace(/^Error: /, "");
                view.addError = line !== "" ? line : "Couldn't connect";
            }
        }
    }

    // --------------------------------- saved password + QR (secrets)
    property string shownPsk: ""
    property string shownPskKey: ""
    property var qrRows: []
    property string qrKey: ""

    function hidePrivate() {
        view.shownPsk = "";
        view.shownPskKey = "";
        view.qrRows = [];
        view.qrKey = "";
        privateTimer.stop();
    }
    Timer {
        id: privateTimer

        interval: 20000
        onTriggered: view.hidePrivate()
    }
    function pskable(r) {
        return r && r.type === "wifi" && r.saved && (r.saved.keyMgmt === "wpa-psk" || r.saved.keyMgmt === "sae");
    }
    function showPassword() {
        const r = view.selected;
        if (!r || r.type !== "wifi") {
            view.toast("Select a Wi-Fi network");
            return;
        }
        if (!view.pskable(r)) {
            view.toast(r.saved ? "This network has no stored password" : r.ssid + " is not saved");
            return;
        }
        if (view.shownPskKey === r.key) {
            view.hidePrivate();
            return;
        }
        pskProc.key = r.key;
        pskProc.command = view.envPrefix.concat(["python3", "-I", view.helper, "psk", r.saved.uuid]);
        pskProc.running = true;
    }
    Process {
        id: pskProc

        property string key: ""

        stdout: StdioCollector {
            id: pskOut
        }
        onExited: code => {
            const v = pskOut.text.replace(/\n$/, "");
            if (code !== 0 || v === "") {
                view.toast("No password stored (the secret agent keeps it)");
                return;
            }
            view.shownPsk = v;
            view.shownPskKey = pskProc.key;
            privateTimer.restart();
        }
    }

    function showQr() {
        const r = view.selected;
        if (!r || r.type !== "wifi" || !r.saved) {
            view.toast(r && r.type === "wifi" ? r.ssid + " is not saved" : "Select a saved Wi-Fi network");
            return;
        }
        if (view.live && !Dependencies.has("qrencode")) {
            view.toast("qrencode is not installed");
            return;
        }
        if (view.qrKey === r.key) {
            view.hidePrivate();
            return;
        }
        qrProc.key = r.key;
        qrProc.command = view.envPrefix.concat(["python3", "-I", view.helper, "qr", r.saved.uuid]);
        qrProc.running = true;
    }
    Process {
        id: qrProc

        property string key: ""

        stdout: StdioCollector {
            id: qrOut
        }
        onExited: code => {
            try {
                const o = JSON.parse(qrOut.text);
                if (o.rows) {
                    view.qrRows = o.rows;
                    view.qrKey = qrProc.key;
                    privateTimer.restart();
                    return;
                }
                view.toast("No QR code: " + (o.error ?? "failed"));
            } catch (e) {
                view.toast("No QR code (" + code + ")");
            }
        }
    }

    // ------------------------------------------------------------- keys
    function handleEscape() {
        if (view.pskTarget) {
            view.closePsk();
            return true;
        }
        if (view.adding) {
            view.closeAdd();
            return true;
        }
        if (view.searching) {
            view.searching = false;
            return true;
        }
        if (view.filter !== "") {
            view.filter = "";
            return true;
        }
        if (view.qrKey !== "" || view.shownPskKey !== "") {
            view.hidePrivate();
            return true;
        }
        return false;
    }

    function enterLabel() {
        const r = view.selected;
        if (!r)
            return "connect";
        if (view.rowBusy(r))
            return "working…";
        if (view.rowConnected(r))
            return view.wiredArm === r.key ? "sure?" : "disconnect";
        if (r.type === "wifi" && r.net && !r.known && !view.isOpen(view.secLabel(r.net)))
            return "join";
        return "connect";
    }

    readonly property var hints: {
        if (view.pskTarget)
            return [[{ keys: ["↵"], text: "connect", slot: "connect" }, { keys: ["Tab"], text: "show" }, { keys: ["Ctrl", "U"], text: "clear" }, { keys: ["Esc"], text: "cancel" }]];
        if (view.adding)
            return [[{ keys: ["Tab"], text: "next field" }, { keys: ["↵"], text: "connect" }, { keys: ["Ctrl", "S"], text: "show" }, { keys: ["Esc"], text: "cancel" }]];
        if (view.searching)
            return [[{ keys: ["↵"], text: "keep filter" }, { keys: ["Esc"], text: "stop searching" }, { keys: ["Ctrl", "U"], text: "clear" }]];
        const r = view.selected;
        const wifi = !!r && r.type === "wifi";
        const saved = wifi && r.known;
        return [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["↵"], text: view.enterLabel(), slot: "disconnect", ghost: !r || (wifi && !r.inRange) },
                { keys: ["/"], text: "filter", ghost: !view.needsFilter },
                { keys: ["r"], text: "rescan" },
                { keys: ["n"], text: "add" },
                { keys: ["e"], text: "connections" },
                { keys: ["a"], text: "autoconnect", ghost: !r || (r.type === "wifi" && !saved) },
                { keys: ["f"], text: view.forgetArm !== "" ? "forget?" : "forget", slot: "forget?", ghost: !saved },
                { keys: ["p"], text: "password", ghost: !view.pskable(r) },
                { keys: ["Q"], text: "share", ghost: !(wifi && r.saved) },
                { keys: ["w"], text: "wi-fi" },
                { keys: ["q"], text: "close" }
            ]];
    }

    function typeInto(cur, event, max) {
        if (event.key === Qt.Key_Backspace)
            return cur.slice(0, -1);
        if (event.text.length === 1 && event.text >= " " && cur.length < max)
            return cur + event.text;
        return cur;
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (view.pskTarget) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                view.submitPsk();
            else if (event.key === Qt.Key_Tab)
                view.pskShow = !view.pskShow;
            else if (ctrl && event.key === Qt.Key_U)
                view.pskText = "";
            else if (!ctrl) {
                view.pskText = view.typeInto(view.pskText, event, 63);
                view.pskError = "";
            }
            return true;
        }
        if (view.adding) {
            if (view.addBusy)
                return true;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                view.submitAdd();
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
                view.addField = (view.addField + 1) % (view.addNeedsPass ? 3 : 2);
            } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
                const n = view.addNeedsPass ? 3 : 2;
                view.addField = (view.addField + n - 1) % n;
            } else if (ctrl && event.key === Qt.Key_S) {
                view.addShow = !view.addShow;
            } else if (ctrl && event.key === Qt.Key_U) {
                if (view.addField === 0)
                    view.addSsid = "";
                else if (view.addField === 2)
                    view.addPass = "";
            } else if (view.addField === 1) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    const n = view.secOptions.length;
                    view.addSec = (view.addSec + (event.key === Qt.Key_Right ? 1 : n - 1)) % n;
                    if (!view.addNeedsPass && view.addField === 2)
                        view.addField = 1;
                }
            } else if (!ctrl) {
                if (view.addField === 0)
                    view.addSsid = view.typeInto(view.addSsid, event, 32);
                else
                    view.addPass = view.typeInto(view.addPass, event, 63);
                view.addError = "";
            }
            return true;
        }
        if (view.searching) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                view.searching = false;
            else if (ctrl && event.key === Qt.Key_U)
                view.filter = "";
            else if (event.key === Qt.Key_Down)
                view.moveSelection(1);
            else if (event.key === Qt.Key_Up)
                view.moveSelection(-1);
            else if (!ctrl)
                view.filter = view.typeInto(view.filter, event, 40);
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            view.moveSelection(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.moveSelection(-1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.moveSelection(4);
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.moveSelection(-4);
            return true;
        case Qt.Key_G:
            view.selectEdge(shift);
            return true;
        case Qt.Key_Slash:
            view.searching = true;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            view.activate();
            return true;
        case Qt.Key_R:
            view.rescan();
            return true;
        case Qt.Key_N:
            view.openAdd();
            return true;
        case Qt.Key_A:
            view.toggleAutoconnect();
            return true;
        case Qt.Key_F:
            view.forget();
            return true;
        case Qt.Key_P:
            view.showPassword();
            return true;
        case Qt.Key_Q:
            if (shift)
                view.showQr();
            else
                view.leaveRequested();
            return true;
        case Qt.Key_Y:
            view.copyIp();
            return true;
        case Qt.Key_O:
            view.openLogin();
            return true;
        case Qt.Key_E:
            view.openEditor();
            return true;
        case Qt.Key_W:
            view.toggleWifi();
            return true;
        case Qt.Key_M:
            view.showWeak = !view.showWeak;
            return true;
        }
        return false;
    }

    // ----------------------------------------------------------- layout
    readonly property int listW: 760
    readonly property int cardX: view.listW + 50
    readonly property int cardW: view.width - view.cardX
    readonly property int topY: 64
    readonly property int wifiHeaderY: view.topY + view.pinnedH + 6
    readonly property int fieldY: view.wifiHeaderY + view.headerH
    // The filter field only exists when the Wi-Fi list does not fit the panel
    // (or while it is being used), measured without the field itself so it
    // cannot toggle itself.
    readonly property int wifiAvail: view.height - (view.fieldY + 6)
    readonly property int wifiContentH: view.wifiRows.reduce((h, r) => h + (r.type === "divider" ? view.dividerH : view.rowH) + 4, 0)
    readonly property bool needsFilter: view.wifiContentH > view.wifiAvail
    readonly property bool fieldShown: view.hasBackend && view.wifiOn && view.hasWifiDev && (view.needsFilter || view.searching || view.filter !== "")
    readonly property int listY: view.fieldY + (view.fieldShown ? 52 : 6)

    Text {
        x: 0
        y: 0
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Network"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    // internet state chip (fixed slot)
    Rectangle {
        x: 200
        y: 12
        width: 190
        height: 30
        radius: 15
        color: Theme.base
        border.color: Theme.surface2
        visible: view.hasBackend

        Text {
            anchors.centerIn: parent
            text: ({ full: "internet: full", limited: "internet: limited", portal: "login required", none: "offline", unknown: "internet: unknown" })[view.connectivity]
            color: view.connectivity === "full" ? Theme.green : (view.connectivity === "none" ? Theme.red : (view.connectivity === "unknown" ? Theme.subtext1 : Theme.yellow))
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }
    }

    Text {
        x: view.width - width
        y: 0
        width: 900
        height: 52
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: view.toastText
        color: Theme.yellow
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        elide: Text.ElideLeft
        renderType: view.textRender
    }

    // shared row delegate (pinned list and Wi-Fi list)
    Component {
        id: rowDelegate

        Item {
            id: row

            required property var modelData

            readonly property string kind: modelData.type
            readonly property bool isRow: kind === "wired" || kind === "vpn" || kind === "wifi"
            readonly property bool sel: modelData.key === view.selectedKey
            readonly property bool connected: view.rowConnected(modelData)
            readonly property bool busy: view.rowBusy(modelData)
            readonly property bool away: kind === "wifi" && !modelData.inRange
            readonly property real sig: kind === "wifi" && modelData.net ? modelData.net.signalStrength : 0
            readonly property string sec: kind === "wifi" && modelData.net ? view.secLabel(modelData.net) : (kind === "wifi" && modelData.saved ? (modelData.saved.keyMgmt === "" ? "open" : "WPA") : "")

            width: ListView.view ? ListView.view.width : view.listW
            height: kind === "header" ? view.headerH : (kind === "divider" ? view.dividerH : view.rowH)

            // section header
            Item {
                visible: row.kind === "header"
                anchors.fill: parent

                Text {
                    x: 6
                    y: 12
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.title ?? ""
                    color: Theme.blue
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    renderType: view.textRender
                }
                Rectangle {
                    x: 0
                    y: parent.height - 3
                    width: parent.width - 18
                    height: 1
                    color: Theme.surface2
                }
            }

            // divider inside the Wi-Fi list
            Item {
                visible: row.kind === "divider"
                anchors.fill: parent

                Text {
                    x: 6
                    y: 8
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                    text: (modelData.title ?? "").toUpperCase()
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                    renderType: view.textRender
                }
                Rectangle {
                    x: 230
                    y: 19
                    width: parent.width - 230 - 18
                    height: 1
                    color: Theme.surface2
                }
            }

            // nothing configured: a muted placeholder (not selectable)
            Rectangle {
                visible: row.kind === "emptyvpn"
                x: 0
                width: parent.width - 18
                height: view.rowH
                radius: 14
                color: "transparent"
                border.color: Theme.surface2

                Rectangle {
                    x: 20
                    y: (parent.height - height) / 2
                    width: 38
                    height: 38
                    radius: 19
                    color: Theme.base
                    border.color: Theme.surface2

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        renderType: view.textRender
                    }
                }
                Text {
                    x: 80
                    y: 8
                    width: parent.width - 100
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    text: "No VPN profiles"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    renderType: view.textRender
                }
                Text {
                    x: 80
                    y: 34
                    width: parent.width - 100
                    height: 20
                    verticalAlignment: Text.AlignVCenter
                    text: "press e to open the connection editor"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    renderType: view.textRender
                }
            }

            // network row
            Rectangle {
                visible: row.isRow
                x: 0
                width: parent.width - 18
                height: view.rowH
                radius: 14
                color: row.sel ? Theme.surface2 : "transparent"

                Item {
                    x: 20
                    y: (parent.height - height) / 2
                    width: 38
                    height: 38
                    opacity: row.away ? 0.4 : (row.connected || row.busy ? 1 : 0.6)

                    Rectangle {
                        anchors.fill: parent
                        radius: 19
                        color: Theme.base
                    }
                    Text {
                        anchors.centerIn: parent
                        text: row.kind === "wired" ? "\u{f0200}" : (row.kind === "vpn" ? "\u{f0582}" : view.wifiGlyph(row.sig))
                        color: row.connected ? Theme.blue : Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        renderType: view.textRender
                    }
                }

                // badge: check = connected, pulsing dot = working
                Rectangle {
                    visible: row.connected || row.busy
                    x: 20 + 38 - 14
                    y: (parent.height - 38) / 2 - 5
                    width: 18
                    height: 18
                    radius: 9
                    color: row.busy ? Theme.yellow : Theme.green
                    border.color: row.sel ? Theme.surface2 : Theme.mantle
                    border.width: 2

                    Text {
                        visible: !row.busy
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.base
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        renderType: view.textRender
                    }
                    Rectangle {
                        visible: row.busy
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.base

                        SequentialAnimation on opacity {
                            running: row.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 450 }
                            NumberAnimation { to: 1; duration: 450 }
                        }
                    }
                }

                Text {
                    x: 80
                    y: 8
                    width: parent.width - 80 - 200
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    text: !row.isRow ? "" : (row.kind === "wifi" ? modelData.ssid : (row.kind === "vpn" ? modelData.saved.id : (modelData.saved ? modelData.saved.id : modelData.dev.name)))
                    color: row.sel || row.connected ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: row.sel
                    elide: Text.ElideRight
                    renderType: view.textRender
                }
                Text {
                    x: 80
                    y: 34
                    width: parent.width - 80 - 200
                    height: 20
                    verticalAlignment: Text.AlignVCenter
                    text: view.rowSub(modelData)
                    color: row.busy ? Theme.yellow : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    renderType: view.textRender
                }

                // right side: address (wired) or signal bars + lock (Wi-Fi)
                Text {
                    visible: row.kind === "wired" && row.connected
                    x: parent.width - width - 24
                    width: 180
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: row.kind === "wired" ? view.ipOf(modelData) : ""
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    renderType: view.textRender
                }
                Row {
                    visible: row.kind === "wifi"
                    x: parent.width - width - 24
                    y: (parent.height - height) / 2
                    height: 24
                    spacing: 14

                    Item {
                        opacity: row.kind === "wifi" && !row.away ? 1 : 0
                        width: 32
                        height: 24

                        Repeater {
                            model: 4

                            Rectangle {
                                required property int index

                                x: index * 8
                                y: 22 - height
                                width: 5
                                height: 6 + index * 5
                                radius: 1
                                color: index < view.barLevel(row.sig) ? (row.connected ? Theme.green : Theme.subtext1) : Theme.surface2
                            }
                        }
                    }
                    Text {
                        opacity: row.kind === "wifi" && !view.isOpen(row.sec) ? 1 : 0
                        width: 20
                        height: 24
                        verticalAlignment: Text.AlignVCenter
                        text: ""
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        renderType: view.textRender
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: view.selectedKey = modelData.key
                    onDoubleClicked: {
                        view.selectedKey = modelData.key;
                        view.activate();
                    }
                }
            }
        }
    }

    // ---- pinned: wired + VPN
    ListView {
        id: pinnedList

        visible: view.hasBackend
        x: 0
        y: view.topY
        width: view.listW
        height: view.pinnedH
        interactive: false
        spacing: 4
        model: view.pinnedRows
        delegate: rowDelegate
    }

    // ---- Wi-Fi header + filter field
    Item {
        visible: view.hasBackend
        x: 0
        y: view.wifiHeaderY
        width: view.listW - 18
        height: view.headerH

        Text {
            id: wifiTitle

            x: 6
            y: 12
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: "Wi-Fi"
            color: Theme.blue
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            renderType: view.textRender
        }
        Text {
            id: wifiIfaceText

            x: wifiTitle.x + wifiTitle.width + 10
            y: 12
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: view.wifiIface
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }
        Row {
            visible: view.scanning
            x: wifiIfaceText.x + wifiIfaceText.width + 16
            y: 12
            height: 30
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.yellow

                SequentialAnimation on opacity {
                    running: view.scanning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "scanning"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                renderType: view.textRender
            }
        }
        Text {
            x: parent.width - width
            y: 12
            width: 420
            height: 30
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: {
                if (!view.wifiOn || !view.hasWifiDev)
                    return "";
                if (view.filter.trim() !== "")
                    return (view.wifiRows.filter(r => r.type === "wifi").length) + " of " + (view.wifiTotal + view.savedAway) + " networks";
                return view.wifiTotal + (view.wifiTotal === 1 ? " network" : " networks") + (view.weakHidden > 0 ? " · " + view.weakHidden + " weak hidden (m)" : "");
            }
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }
        Rectangle {
            x: 0
            y: parent.height - 3
            width: parent.width
            height: 1
            color: Theme.surface2
        }
    }

    Rectangle {
        visible: view.fieldShown
        x: 0
        y: view.fieldY
        width: view.listW - 18
        height: 40
        radius: 12
        color: Theme.base
        border.width: view.searching ? 2 : 1
        border.color: view.searching ? Theme.blue : Theme.surface2

        Text {
            x: 14
            width: 24
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: ""
            color: view.searching ? Theme.blue : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            renderType: view.textRender
        }
        Text {
            x: 46
            width: parent.width - 60
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: view.filter !== "" ? view.filter + (view.searching ? "▏" : "") : (view.searching ? "▏" : "Press / to filter")
            color: view.filter !== "" ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            elide: Text.ElideLeft
            renderType: view.textRender
        }
    }

    ListView {
        id: wifiList

        visible: view.hasBackend && view.wifiOn && view.hasWifiDev
        x: 0
        y: view.listY
        width: view.listW
        height: view.height - view.listY
        clip: true
        spacing: 4
        model: view.wifiRows
        delegate: rowDelegate
        currentIndex: view.wifiRows.findIndex(r => r.key === view.selectedKey)
        onCurrentIndexChanged: if (wifiList.currentIndex >= 0)
            wifiList.positionViewAtIndex(wifiList.currentIndex, ListView.Contain)

        Rectangle {
            // scrollbar
            visible: wifiList.contentHeight > wifiList.height
            x: wifiList.width - 10
            y: wifiList.height * (wifiList.contentY / wifiList.contentHeight)
            width: 4
            height: Math.max(30, wifiList.height * wifiList.height / wifiList.contentHeight)
            radius: 2
            color: Theme.subtext1
        }
    }

    EmptyState {
        visible: view.hasBackend && (!view.wifiOn || !view.hasWifiDev)
        x: 0
        y: view.fieldY
        width: view.listW - 18
        height: view.height - view.fieldY
        imageSize: 140
        titleSize: Theme.fontSize + 5
        hintSize: Theme.fontSize
        illustration: "network.svg"
        title: !view.hasWifiDev ? "No Wi-Fi adapter" : (!view.wifiHw ? "Wi-Fi is blocked" : "Wi-Fi is off")
        hint: !view.hasWifiDev ? "Wired and VPN still work" : (!view.wifiHw ? "A hardware switch (rfkill) turns it off" : "Press w to turn it on")
        textRender: view.textRender
    }

    EmptyState {
        visible: view.hasBackend && view.wifiOn && view.hasWifiDev && view.wifiRows.length === 0
        x: 0
        y: view.listY
        width: view.listW - 18
        height: view.height - view.listY
        imageSize: 140
        titleSize: Theme.fontSize + 5
        hintSize: Theme.fontSize
        illustration: "network.svg"
        title: view.filter.trim() !== "" ? "No matching networks" : "No networks found"
        hint: view.filter.trim() !== "" ? "Esc clears the filter" : (view.scanning ? "Scanning…" : "Press r to scan again")
        textRender: view.textRender
    }

    EmptyState {
        visible: !view.hasBackend
        x: 0
        y: view.topY
        width: view.width
        height: view.height - view.topY
        illustration: "network.svg"
        title: "NetworkManager is not running"
        hint: "Start NetworkManager.service to manage connections here"
        textRender: view.textRender
    }

    // ---------------------------------------------------- detail card
    readonly property var card: view.buildCard()
    readonly property bool qrVisible: view.qrRows.length > 0 && view.qrKey === view.selectedKey
    readonly property int detailW: view.qrVisible ? 520 : 760

    // IPv6 rows: global addresses (link-local only when there is nothing else)
    function v6rows(d) {
        if (!d || !d.ip6 || d.ip6.length === 0)
            return [];
        const glob = d.ip6.filter(a => !a.toLowerCase().startsWith("fe80"));
        const rows = [["IPv6", (glob.length > 0 ? glob : d.ip6).join(", ")]];
        if (d.gateway6)
            rows.push(["IPv6 gateway", d.gateway6]);
        if (d.dns6 && d.dns6.length > 0)
            rows.push(["IPv6 DNS", d.dns6.join(", ")]);
        return rows;
    }

    function dash(v) {
        return v === undefined || v === null || v === "" ? "–" : v;
    }
    function since(ts) {
        if (!ts || ts <= 0)
            return "never";
        const sec = Math.max(0, (view.now / 1000) - ts);
        if (sec < 90)
            return "just now";
        const min = Math.floor(sec / 60);
        if (min < 60)
            return min + " min";
        const h = Math.floor(min / 60);
        if (h < 24)
            return h + " h " + (min % 60) + " min";
        return Math.floor(h / 24) + " d " + (h % 24) + " h";
    }
    function dateOf(ts) {
        return ts > 0 ? new Date(ts * 1000).toLocaleDateString(Qt.locale(), "yyyy-MM-dd") : "never";
    }

    function buildCard() {
        const r = view.selected;
        if (!r)
            return null;
        const c = { glyph: "", title: "", sub: "", subColor: Theme.subtext1, connected: view.rowConnected(r), rows: [], graph: false, actions: [] };
        const yn = b => b ? "yes" : "no";
        if (r.type === "wired") {
            const d = r.dev;
            c.glyph = "\u{f0200}";
            c.title = r.saved ? r.saved.id : d.name;
            c.sub = c.connected ? "connected · " + d.name + (d.speed && d.speed !== "unknown" ? " · " + view.speedLabel(d.speed) : "") : "not connected · " + d.name;
            c.subColor = c.connected ? Theme.green : Theme.subtext1;
            c.graph = c.connected;
            if (c.connected)
                c.rows = [["Address", view.dash(d.ip4.join(", "))], ["Gateway", view.dash(d.gateway)], ["DNS", view.dash(d.dns.join(", "))]].concat(view.v6rows(d)).concat([["MAC", view.dash(d.hwaddr)], ["Autoconnect", r.saved ? yn(r.saved.autoconnect) : "–"]]);
            else
                c.rows = [["MAC", view.dash(d.hwaddr)], ["Autoconnect", r.saved ? yn(r.saved.autoconnect) : "–"]];
            c.actions = [c.connected ? "↵ disconnect" : "↵ connect", "a autoconnect"].concat(c.connected ? ["y copy IP"] : []);
        } else if (r.type === "vpn") {
            const s = r.saved;
            c.glyph = "\u{f0582}";
            c.title = s.id;
            c.sub = c.connected ? "connected · " + view.since(s.timestamp) : "not connected";
            c.subColor = c.connected ? Theme.green : Theme.subtext1;
            c.graph = c.connected && !!s.device;
            c.rows = [["Type", view.typeLabel(s.serviceType)], ["Interface", view.dash(s.device)]];
            if (c.connected && s.rx !== undefined && s.rx !== null)
                c.rows.push(["Traffic", "↓ " + Fmt.bytes(s.rx) + "    ↑ " + Fmt.bytes(s.tx)]);
            if (!c.connected)
                c.rows.push(["Last connected", view.dateOf(s.timestamp)]);
            c.rows.push(["Autoconnect", yn(s.autoconnect)]);
            c.actions = [c.connected ? "↵ disconnect" : "↵ connect", "a autoconnect"];
        } else {
            const n = r.net;
            const sv = r.saved;
            c.glyph = view.wifiGlyph(n ? n.signalStrength : 0);
            c.title = r.ssid;
            if (!r.inRange) {
                c.sub = "saved · not in range";
                c.rows = [["Security", sv.keyMgmt === "" ? "open" : (sv.keyMgmt === "sae" ? "WPA3" : "WPA / WPA2")], ["Last connected", view.dateOf(sv.timestamp)], ["Autoconnect", yn(sv.autoconnect)]];
            } else {
                const label = view.secLabel(n);
                const ap = r.ap ? r.ap.best : null;
                const dev = view.info.devices.find(x => x.type === "wifi" && x.state === "connected");
                c.sub = c.connected ? "connected · " + label : "not connected · " + label;
                c.subColor = c.connected ? Theme.green : Theme.subtext1;
                c.graph = c.connected && view.live;
                c.rows.push(["Signal", Math.round(n.signalStrength * 100) + " %"]);
                if (c.connected && view.wifiIface !== "")
                    c.rows.push(["Interface", view.wifiIface]);
                if (c.connected && dev)
                    c.rows = c.rows.concat([["Address", view.dash(dev.ip4.join(", "))], ["Gateway", view.dash(dev.gateway)], ["DNS", view.dash(dev.dns.join(", "))]], view.v6rows(dev));
                else
                    c.rows.push(["Security", label]);
                c.rows.push(["Band", ap ? ap.band + " · channel " + ap.chan : "–"]);
                if (!c.connected)
                    c.rows.push(["Access points", r.ap ? String(r.ap.count) : "–"]);
                c.rows.push(["Saved", yn(r.known)]);
                c.rows.push(["Autoconnect", sv ? yn(sv.autoconnect) : "–"]);
            }
            if (view.pskable(r))
                c.rows.push(["Password", view.shownPskKey === r.key ? view.shownPsk : "••••••••   (p shows)"]);
            const acts = [];
            if (r.inRange)
                acts.push(c.connected ? "↵ disconnect" : (r.known || view.isOpen(view.secLabel(n)) ? "↵ connect" : "↵ join"));
            if (r.known)
                acts.push("a autoconnect");
            if (r.saved)
                acts.push("Q share QR");
            if (r.known)
                acts.push("f forget");
            if (c.connected)
                acts.push("y copy IP");
            c.actions = acts;
        }
        return c;
    }

    Rectangle {
        id: cardBox

        visible: view.hasBackend
        x: view.cardX
        y: view.topY
        width: view.cardW
        height: view.height - view.topY
        radius: 14
        color: Theme.base
        border.color: Theme.surface2

        // ----- normal detail
        Item {
            id: detail

            visible: view.card !== null && !view.pskTarget && !view.adding
            anchors.fill: parent

            // The throughput graph gives way to the detail rows: 150 px when the card is tall (1040 px box).
            // On a 1080p laptop (816 px box) a connected Wi-Fi network has 12 rows and the action buttons sit 70 px
            // above the bottom, so the rows tighten from 34 to 30 px and the graph shrinks (60..150 px).
            readonly property int rowCount: view.card ? view.card.rows.length : 0
            readonly property int roomBelowGraph: height - 82 - 170
            readonly property int rowPitch: detail.rowCount * 34 <= detail.roomBelowGraph - 110 ? 34 : 30
            readonly property int graphH: Math.max(60, Math.min(150, detail.roomBelowGraph - detail.rowCount * detail.rowPitch))
            readonly property int graphEnd: 140 + detail.graphH

            Rectangle {
                x: 36
                y: 30
                width: 56
                height: 56
                radius: 28
                color: Theme.mantle

                Text {
                    anchors.centerIn: parent
                    text: view.card ? view.card.glyph : ""
                    color: view.card && view.card.connected ? Theme.blue : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: 30
                    renderType: view.textRender
                }
            }
            Text {
                x: 112
                y: 28
                width: parent.width - 112 - 30
                height: 32
                verticalAlignment: Text.AlignVCenter
                text: view.card ? view.card.title : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 8
                font.bold: true
                elide: Text.ElideRight
                renderType: view.textRender
            }
            Text {
                x: 112
                y: 62
                width: parent.width - 112 - 30
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: view.card ? view.card.sub : ""
                color: view.card ? view.card.subColor : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                elide: Text.ElideRight
                renderType: view.textRender
            }

            // throughput
            Text {
                visible: view.card !== null && view.card.graph
                x: 36
                y: 116
                text: "Throughput"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                renderType: view.textRender
            }
            Text {
                visible: view.card !== null && view.card.graph
                x: parent.width - width - 36
                y: 116
                width: 420
                horizontalAlignment: Text.AlignRight
                text: view.rxHist.length > 0 ? "↓ " + Fmt.rate(view.rxHist[view.rxHist.length - 1]) + "     ↑ " + Fmt.rate(view.txHist[view.txHist.length - 1]) : ""
                color: Theme.teal
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                renderType: view.textRender
            }
            LineGraph {
                visible: view.card !== null && view.card.graph
                x: 30
                y: 140
                width: parent.width - 60
                height: detail.graphH
                series: [{ values: view.rxHist, color: Theme.teal }, { values: view.txHist, color: Theme.blue }]
                maxValue: 0
                unit: "rate"
                samples: 60
                textRender: view.textRender
            }

            // detail rows
            Column {
                x: 36
                y: view.card !== null && view.card.graph ? detail.graphEnd + 30 : 130
                width: view.detailW

                Repeater {
                    model: view.card ? view.card.rows : []

                    Item {
                        required property var modelData

                        width: view.detailW
                        height: detail.rowPitch

                        Text {
                            width: 190
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData[0]
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 1
                            renderType: view.textRender
                        }
                        Text {
                            x: 190
                            width: parent.width - 190
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData[1]
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 2
                            elide: Text.ElideRight
                            renderType: view.textRender
                        }
                    }
                }
            }

            // QR code to share the selected saved network
            Rectangle {
                visible: view.qrRows.length > 0 && view.qrKey === view.selectedKey
                x: parent.width - 36 - 250
                y: view.card !== null && view.card.graph ? detail.graphEnd + 20 : 120
                width: 250
                height: 250
                radius: 12
                color: "#ffffff"

                Canvas {
                    id: qrCanvas

                    anchors.fill: parent
                    anchors.margins: 12
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const rows = view.qrRows;
                        const n = rows.length;
                        if (n === 0)
                            return;
                        const cell = Math.floor(Math.min(width, height) / n);
                        const off = Math.floor((width - cell * n) / 2);
                        ctx.fillStyle = "#000000";
                        for (let y = 0; y < n; y++)
                            for (let x = 0; x < rows[y].length; x++)
                                if (rows[y][x] === "1")
                                    ctx.fillRect(off + x * cell, off + y * cell, cell, cell);
                    }
                    Connections {
                        target: view

                        function onQrRowsChanged() {
                            qrCanvas.requestPaint();
                        }
                    }
                }
            }
            Text {
                visible: view.qrRows.length > 0 && view.qrKey === view.selectedKey
                x: parent.width - 36 - 250
                y: (view.card !== null && view.card.graph ? detail.graphEnd + 20 : 120) + 256
                width: 250
                horizontalAlignment: Text.AlignHCenter
                text: "Scan to join · Esc hides"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                renderType: view.textRender
            }

            // captive portal notice
            Rectangle {
                visible: view.connectivity === "portal"
                x: 36
                y: parent.height - 170
                width: parent.width - 72
                height: 80
                radius: 12
                color: Theme.mantle
                border.color: Theme.yellow

                Text {
                    x: 20
                    y: 12
                    text: "This network wants a login (captive portal)"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    renderType: view.textRender
                }
                Text {
                    x: 20
                    y: 44
                    text: "Press o to open the login page in your browser"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    renderType: view.textRender
                }
            }

            // action pills
            Row {
                x: 36
                y: parent.height - 70
                spacing: 10

                Repeater {
                    model: view.card ? view.card.actions : []

                    Rectangle {
                        required property string modelData

                        width: pillText.implicitWidth + 28
                        height: 32
                        radius: 16
                        color: Theme.base
                        border.color: Theme.surface2

                        Text {
                            id: pillText

                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            renderType: view.textRender
                        }
                    }
                }
            }
        }

        // ----- join a secured network: password prompt
        Item {
            visible: view.pskTarget !== null
            anchors.fill: parent

            Text {
                x: 36
                y: 40
                width: parent.width - 72
                text: view.pskTarget ? "Password for " + view.pskTarget.name : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 8
                font.bold: true
                elide: Text.ElideRight
                renderType: view.textRender
            }
            Text {
                x: 36
                y: 84
                text: view.pskTarget ? view.secLabel(view.pskTarget) + " · type it, then press Enter" : ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                renderType: view.textRender
            }
            Rectangle {
                x: 36
                y: 150
                width: parent.width - 72
                height: 64
                radius: 14
                color: Theme.mantle
                border.color: view.pskError !== "" ? Theme.red : Theme.blue
                border.width: 2

                Text {
                    x: 20
                    width: parent.width - 100
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: (view.pskShow ? view.pskText : "•".repeat(view.pskText.length)) + "▏"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 10
                    font.bold: true
                    elide: Text.ElideLeft
                    renderType: view.textRender
                }
                Text {
                    x: parent.width - 56
                    width: 36
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: view.pskShow ? "\uf070" : "\uf06e"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 6
                    renderType: view.textRender

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.pskShow = !view.pskShow
                    }
                }
            }
            Text {
                x: 36
                y: 230
                width: parent.width - 72
                height: 26
                text: view.pskError !== "" ? view.pskError : view.pskText.length + " characters"
                color: view.pskError !== "" ? Theme.red : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                renderType: view.textRender
            }
        }

        // ----- add a (hidden) network
        Item {
            visible: view.adding
            anchors.fill: parent

            Text {
                x: 36
                y: 40
                text: "Add network"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 8
                font.bold: true
                renderType: view.textRender
            }
            Text {
                x: 36
                y: 84
                text: "Connect to a network that does not show up in the list"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                renderType: view.textRender
            }

            Repeater {
                model: [{ label: "Network name (SSID)", f: 0 }, { label: "Security", f: 1 }, { label: "Password", f: 2 }]

                Item {
                    id: fld

                    required property var modelData

                    visible: modelData.f !== 2 || view.addNeedsPass
                    x: 36
                    y: 140 + modelData.f * 104
                    width: cardBox.width - 72
                    height: 96

                    Text {
                        text: fld.modelData.label
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: view.textRender
                    }
                    Rectangle {
                        y: 28
                        width: parent.width
                        height: 54
                        radius: 12
                        color: Theme.mantle
                        border.width: view.addField === fld.modelData.f ? 2 : 1
                        border.color: view.addField === fld.modelData.f ? Theme.blue : Theme.surface2

                        Text {
                            x: 18
                            width: fld.modelData.f === 2 ? parent.width - 100 : parent.width - 36
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: {
                                const cur = view.addField === fld.modelData.f ? "▏" : "";
                                if (fld.modelData.f === 0)
                                    return view.addSsid + cur;
                                if (fld.modelData.f === 1)
                                    return view.secOptions[view.addSec].label + (view.addField === 1 ? "      ← →" : "");
                                return (view.addShow ? view.addPass : "•".repeat(view.addPass.length)) + cur;
                            }
                            color: fld.modelData.f === 2 ? Theme.yellow : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 5
                            elide: Text.ElideLeft
                            renderType: view.textRender
                        }
                        Text {
                            visible: fld.modelData.f === 2
                            x: parent.width - 56
                            width: 36
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: view.addShow ? "\uf070" : "\uf06e"
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 6
                            renderType: view.textRender

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.addShow = !view.addShow
                            }
                        }
                    }
                }
            }

            Text {
                x: 36
                y: 140 + 3 * 104 + 6
                width: parent.width - 72
                height: 26
                text: view.addBusy ? "Connecting…" : (view.addError !== "" ? view.addError : "")
                color: view.addBusy ? Theme.yellow : Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                elide: Text.ElideRight
                renderType: view.textRender
            }
        }
    }
}
