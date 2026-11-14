pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Maps a process binary ("Discord", "firefox") to an icon theme name via
// installed .desktop files, as many apps (Electron) set no PipeWire
// icon-name. Memoized; lookups are queued through one Process, which has
// no per-call invocation API.
Singleton {
    id: root

    // binary -> icon name. "" = looked up, nothing found (cached to skip a
    // repeat round-trip).
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

    // Cached icon name (possibly ""); starts a lookup for unseen binaries.
    // Reading `cache` re-evaluates callers' bindings when it's reassigned.
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
                // Reassign, not mutate, so `cache` changes identity and notifies bindings.
                const next = Object.assign({}, root.cache);
                next[lookupProc.binaryName] = found;
                root.cache = next;
                root.processNext();
            }
        }
    }
}
