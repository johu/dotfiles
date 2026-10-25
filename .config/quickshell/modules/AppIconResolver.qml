pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Resolves a process binary name (e.g. "Discord", "firefox") to a
// hicolor icon theme name by matching it against installed .desktop
// files, for callers (AppVolumeRow.qml) that want an app's real icon
// instead of whatever application.icon-name PipeWire happens to report -
// several apps (notably Discord/Electron ones) don't set that property
// at all. Memoized per binary name; lookups run one at a time through a
// single Process, queued, since Quickshell.Io.Process has no per-call
// invocation API.
Singleton {
    id: root

    // binary -> icon name. "" means looked up already, nothing found -
    // still cached so callers don't repeat the Process round-trip.
    property var cache: ({})
    property var queue: []

    readonly property string lookupScript: "
        b=\"$1\"
        dirs=\"$HOME/.local/share/applications /usr/share/applications /usr/local/share/applications\"
        for d in $dirs; do
            f=\"$d/$b.desktop\"
            if [ -f \"$f\" ]; then
                grep -m1 '^Icon=' \"$f\" | cut -d= -f2-
                exit 0
            fi
        done
        for d in $dirs; do
            f=$(find \"$d\" -maxdepth 1 -iname \"$b.desktop\" 2>/dev/null | head -1)
            if [ -n \"$f\" ]; then
                grep -m1 '^Icon=' \"$f\" | cut -d= -f2-
                exit 0
            fi
        done
        f=$(grep -ril \"Exec=.*$b\" $dirs 2>/dev/null | head -1)
        if [ -n \"$f\" ]; then
            grep -m1 '^Icon=' \"$f\" | cut -d= -f2-
        fi
    "

    // Returns the cached icon name (possibly "") and kicks off a lookup
    // if this binary hasn't been seen before. Reading `root.cache` here
    // makes any binding that calls this re-evaluate once the lookup
    // completes and `cache` is reassigned below.
    function iconNameForBinary(binary) {
        if (!binary)
            return "";
        if (binary in root.cache)
            return root.cache[binary];
        if (root.queue.indexOf(binary) === -1) {
            root.queue.push(binary);
            root.processNext();
        }
        return "";
    }

    function processNext() {
        if (lookupProc.running || root.queue.length === 0)
            return;
        lookupProc.binaryName = root.queue.shift();
        lookupProc.running = true;
    }

    Process {
        id: lookupProc

        property string binaryName: ""

        command: ["sh", "-c", root.lookupScript, "sh", lookupProc.binaryName]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = this.text.trim();
                // Reassign (not mutate in place) so the `cache` property
                // itself changes identity and notifies bindings.
                const next = Object.assign({}, root.cache);
                next[lookupProc.binaryName] = found;
                root.cache = next;
                root.processNext();
            }
        }
    }
}
