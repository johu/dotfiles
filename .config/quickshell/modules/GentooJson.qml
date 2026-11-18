import QtQuick
import Quickshell.Io

// Runs scripts/gentoo.py <args> and keeps the parsed JSON in `data`.
Item {
    id: j

    // extra arguments after the helper path (subcommand and flags)
    property var args: []
    property var base: []
    property var data: null
    property bool loaded: false
    readonly property bool busy: proc.running
    signal done

    // A reload asked for while the helper still runs (a slow check at view open, then `r`) is not dropped:
    // it runs right after, with the latest arguments.
    property var queued: null

    function reload(extra) {
        if (proc.running) {
            j.queued = extra ?? [];
            return;
        }
        proc.extra = extra ?? [];
        proc.running = true;
    }

    Process {
        id: proc

        property var extra: []

        command: j.base.concat(j.args, proc.extra)
        onExited: {
            if (j.queued !== null) {
                proc.extra = j.queued;
                j.queued = null;
                proc.running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    j.data = JSON.parse(this.text);
                    j.loaded = true;
                    j.done();
                } catch (e) {
                    console.warn("gentoo helper output unreadable: " + j.args.join(" "));
                }
            }
        }
    }
}
