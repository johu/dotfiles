pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Resolves a PID to a Steam library icon and game title for Proton games,
// whose binary ("wine64-preloader", "D2R.exe") has no .desktop entry (see
// AppIconResolver.qml). The AppID appears only in the command line of
// Steam's `reaper` ancestor (`SteamLaunch AppId=<id> -- ...`), so walk up
// the process tree, then read Steam's cached 32x32 icon and the title from
// appmanifest_<id>.acf.
Singleton {
    id: root

    // pid -> { icon: "path or ''", name: "title or ''" }
    property var cache: ({})
    property var queue: []

    readonly property string lookupScript: "
        pid=\"$1\"
        depth=0
        while [ -n \"$pid\" ] && [ \"$pid\" != \"1\" ] && [ \"$depth\" -lt 12 ]; do
            cmd=$(tr '\\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
            appid=$(printf '%s' \"$cmd\" | grep -oE 'AppId=[0-9]+' | head -1 | cut -d= -f2)
            if [ -n \"$appid\" ]; then
                icon=\"\"
                name=\"\"
                for base in \"$HOME/.local/share/Steam\" \"$HOME/.steam/steam\"; do
                    cachedir=\"$base/appcache/librarycache/$appid\"
                    if [ -z \"$icon\" ] && [ -d \"$cachedir\" ]; then
                        icon=$(find \"$cachedir\" -maxdepth 1 -regextype posix-extended -iregex '.*/[0-9a-f]{40}\\.jpg' 2>/dev/null | head -1)
                    fi
                    manifest=\"$base/steamapps/appmanifest_$appid.acf\"
                    if [ -z \"$name\" ] && [ -f \"$manifest\" ]; then
                        name=$(grep -m1 '\"name\"' \"$manifest\" | sed -E 's/.*\"name\"[[:space:]]+\"([^\"]*)\".*/\\1/')
                    fi
                    vdf=\"$base/steamapps/libraryfolders.vdf\"
                    if [ -z \"$name\" ] && [ -f \"$vdf\" ]; then
                        libpaths=$(grep -oE '\"path\"[[:space:]]+\"[^\"]*\"' \"$vdf\" | sed -E 's/.*\"path\"[[:space:]]+\"([^\"]*)\".*/\\1/')
                        while IFS= read -r libpath; do
                            [ -n \"$libpath\" ] || continue
                            manifest=\"$libpath/steamapps/appmanifest_$appid.acf\"
                            if [ -f \"$manifest\" ]; then
                                name=$(grep -m1 '\"name\"' \"$manifest\" | sed -E 's/.*\"name\"[[:space:]]+\"([^\"]*)\".*/\\1/')
                                break
                            fi
                        done <<EOF
$libpaths
EOF
                    fi
                done
                echo \"$icon\"
                echo \"$name\"
                exit 0
            fi
            pid=$(awk '{print $4}' /proc/$pid/stat 2>/dev/null)
            depth=$((depth + 1))
        done
    "

    // Cached icon path (possibly ""); starts a lookup for unseen pids, as
    // AppIconResolver.iconNameForBinary.
    function iconPathForPid(pid) {
        return root.entryForPid(pid).icon;
    }

    // Cached game title (possibly "").
    function gameNameForPid(pid) {
        return root.entryForPid(pid).name;
    }

    function entryForPid(pid) {
        if (!pid)
            return { icon: "", name: "" };
        const key = String(pid);
        if (key in root.cache)
            return root.cache[key];
        if (root.queue.indexOf(key) === -1) {
            root.queue.push(key);
            root.processNext();
        }
        return { icon: "", name: "" };
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
                const lines = this.text.split("\n");
                const next = Object.assign({}, root.cache);
                next[lookupProc.pidArg] = { icon: (lines[0] || "").trim(), name: (lines[1] || "").trim() };
                root.cache = next;
                root.processNext();
            }
        }
    }
}
