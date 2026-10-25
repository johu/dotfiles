pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Resolves a PID to a Steam library icon file, for games launched through
// Proton - their audio stream's binary (e.g. "wine64-preloader",
// "D2R.exe") has no .desktop entry at all (see AppIconResolver.qml,
// which only covers native-Linux installed apps). A Proton game's actual
// process is several forks deep under Steam's own `reaper` launcher,
// whose command line is the one place the Steam AppID shows up
// (`SteamLaunch AppId=<id> -- ...`, confirmed via /proc/<pid>/cmdline on
// a running Diablo II: Resurrected session) - walk up the process tree
// looking for it, then read the matching 32x32 icon Steam already
// cached locally for its own library UI.
Singleton {
    id: root

    // pid -> icon file path ("" = looked up, nothing found)
    property var cache: ({})
    property var queue: []

    readonly property string lookupScript: "
        pid=\"$1\"
        depth=0
        while [ -n \"$pid\" ] && [ \"$pid\" != \"1\" ] && [ \"$depth\" -lt 12 ]; do
            cmd=$(tr '\\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
            appid=$(printf '%s' \"$cmd\" | grep -oE 'AppId=[0-9]+' | head -1 | cut -d= -f2)
            if [ -n \"$appid\" ]; then
                for base in \"$HOME/.local/share/Steam/appcache/librarycache\" \"$HOME/.steam/steam/appcache/librarycache\"; do
                    dir=\"$base/$appid\"
                    if [ -d \"$dir\" ]; then
                        icon=$(find \"$dir\" -maxdepth 1 -regextype posix-extended -iregex '.*/[0-9a-f]{40}\\.jpg' 2>/dev/null | head -1)
                        if [ -n \"$icon\" ]; then
                            echo \"$icon\"
                            exit 0
                        fi
                    fi
                done
                exit 0
            fi
            pid=$(awk '{print $4}' /proc/$pid/stat 2>/dev/null)
            depth=$((depth + 1))
        done
    "

    // Returns the cached icon path (possibly "") and kicks off a lookup
    // if this pid hasn't been seen before - same lazy-memoized shape as
    // AppIconResolver.iconNameForBinary.
    function iconPathForPid(pid) {
        if (!pid)
            return "";
        const key = String(pid);
        if (key in root.cache)
            return root.cache[key];
        if (root.queue.indexOf(key) === -1) {
            root.queue.push(key);
            root.processNext();
        }
        return "";
    }

    function processNext() {
        if (lookupProc.running || root.queue.length === 0)
            return;
        lookupProc.pidArg = root.queue.shift();
        lookupProc.running = true;
    }

    Process {
        id: lookupProc

        property string pidArg: ""

        command: ["sh", "-c", root.lookupScript, "sh", lookupProc.pidArg]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = this.text.trim();
                const next = Object.assign({}, root.cache);
                next[lookupProc.pidArg] = found;
                root.cache = next;
                root.processNext();
            }
        }
    }
}
