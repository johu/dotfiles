import QtQuick
import Quickshell
import Quickshell.Io

// BlueZ pairing agent: runs scripts/bt-agent.py only while `running`, so it is
// the default agent only during a pairing flow (BlueZ has a single one).
// Quickshell.Bluetooth does scanning and device.pair(); this answers BlueZ's
// PIN / passkey / confirmation questions. Protocol: see the script header and
// docs/ideas/bluetooth.md.
Item {
    id: root

    property bool running: false
    readonly property bool ready: d.ready
    property string error: ""

    // Pending question, or null. kind: confirm | authorize | service | pin | passkey
    // Fields: id, kind, device, name, passkey (confirm), uuid (service).
    readonly property var request: d.request
    // Passive display of what to type on the device: null or
    // {name, passkey, entered} / {name, pin}.
    readonly property var display: d.display

    // Test hook: environment for the script (e.g. BT_AGENT_BUS=session).
    property var testEnv: ({})

    signal finished(string outcome) // "ok" never fires by itself; "cancel" when BlueZ withdraws

    function accept() {
        if (d.request)
            d.send({
                reply: "accept",
                id: d.request.id
            });
    }
    function reject() {
        if (d.request)
            d.send({
                reply: "reject",
                id: d.request.id
            });
    }
    // value: pin string for kind "pin", number for kind "passkey".
    function submit(value) {
        if (!d.request)
            return;
        if (d.request.kind === "pin")
            d.send({
                reply: "pin",
                id: d.request.id,
                value: String(value)
            });
        else if (d.request.kind === "passkey")
            d.send({
                reply: "passkey",
                id: d.request.id,
                value: Number(value)
            });
    }

    QtObject {
        id: d
        property bool ready: false
        property var request: null
        property var display: null

        function send(o) {
            proc.write(JSON.stringify(o) + "\n");
            d.request = null;
        }
        function consume(line) {
            let o;
            try {
                o = JSON.parse(line);
            } catch (e) {
                return;
            }
            switch (o.event) {
            case "ready":
                d.ready = true;
                root.error = "";
                break;
            case "error":
                root.error = o.msg;
                break;
            case "confirm":
            case "authorize":
            case "service":
            case "pin":
            case "passkey":
                d.display = null;
                d.request = Object.assign({
                    kind: o.event
                }, o);
                break;
            case "display":
            case "displaypin":
                d.display = o;
                break;
            case "cancel":
                d.request = null;
                d.display = null;
                root.finished("cancel");
                break;
            }
        }
    }

    Process {
        id: proc
        command: (Object.keys(root.testEnv).length > 0 ? ["env"].concat(Object.keys(root.testEnv).map(k => k + "=" + root.testEnv[k])) : []).concat(["python3", "-I", Quickshell.shellPath("scripts/bt-agent.py")])
        running: root.running
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => d.consume(data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => console.warn(data)
        }
        onRunningChanged: if (!running) {
            d.ready = false;
            d.request = null;
            d.display = null;
        }
        onExited: code => {
            if (code !== 0 && root.error === "")
                root.error = "agent exited (" + code + ")";
        }
    }
}
