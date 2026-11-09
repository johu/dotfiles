pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recorder state + backend (gpu-screen-recorder). Started from
// Capture.qml's picker (IPC target `record`), stopped by the bar pill or
// IPC. SIGINT is what makes gpu-screen-recorder finalize the file.
QtObject {
    id: root

    readonly property string saveDir: Quickshell.env("HOME") + "/videos/screenrecordings"

    property bool recording: false
    property string file: ""
    property int elapsed: 0
    property double startMs: 0
    property bool stopping: false
    property var args: []

    readonly property string elapsedText: {
        const s = root.elapsed;
        const pad = n => (n < 10 ? "0" : "") + n;
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s % 60);
    }

    // target: "region" (needs region "WxH+X+Y" in logical coords) or a
    // monitor name such as "DP-1".
    function start(target, region) {
        if (root.recording)
            return;
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        root.file = root.saveDir + "/" + stamp + ".mp4";
        const w = target === "region" ? ["-w", "region", "-region", region] : ["-w", target];
        root.args = w.concat(["-k", "auto", "-f", "60", "-fm", "cfr", "-fallback-cpu-encoding", "yes", "-o", root.file]);
        root.stopping = false;
        root.elapsed = 0;
        root.startMs = Date.now();
        root.recording = true;
        mkdirProc.running = true;
    }

    function stop() {
        if (!root.recording || root.stopping)
            return;
        root.stopping = true;
        if (recProc.running)
            recProc.signal(2); // SIGINT: stop and save
        else
            root.recording = false;
    }

    function toggleScreen(monitor) {
        if (root.recording)
            root.stop();
        else
            root.start(monitor, "");
    }

    property var mkdir: Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.saveDir]
        onExited: code => {
            if (code !== 0) {
                root.recording = false;
                ToastManager.show("Cannot create recordings folder", "");
                return;
            }
            recProc.command = ["gpu-screen-recorder"].concat(root.args);
            recProc.running = true;
        }
    }

    property var rec: Process {
        id: recProc
        stderr: StdioCollector {
            id: errOut
        }
        onExited: code => {
            const wasStopping = root.stopping;
            root.recording = false;
            root.stopping = false;
            if (code === 0 && wasStopping) {
                doneProc.command = [Quickshell.shellPath("scripts/record-done.sh"), root.file];
                doneProc.running = true;
            } else {
                console.warn("gpu-screen-recorder exited " + code + ": " + errOut.text);
                ToastManager.show("Recording failed", "");
            }
        }
    }

    property var done: Process {
        id: doneProc
    }

    property var ticker: Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startMs) / 1000)
    }
}
