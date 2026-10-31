pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polls `emerge -pvuDN @world` on a long interval and exposes the
// "Total: N packages" count from its summary line for Logo.qml's badge.
// Skipped while game mode is active (see NightLight.qml's identical
// ~/.cache/gamemode check) since the dependency resolution is too heavy
// to run alongside a game.
Singleton {
    id: root

    readonly property int pollInterval: 4 * 60 * 60 * 1000
    property int pendingCount: 0
    property bool gameModeActive: false

    // Live build state, refreshed every statusInterval regardless of
    // gameModeActive (cheap: pgrep + a stat + an awk pass over emerge.log,
    // not a dependency resolution).
    readonly property int statusInterval: 5000
    property bool emergeRunning: false
    property int lastSyncEpoch: 0
    property int emergeCurrent: 0
    property int emergeTotal: 0
    property string emergeAtom: ""
    property int emergeEtaSeconds: 0
    // Tracks emergeRunning's previous value to fire a one-off recheck the
    // moment a build ends, instead of waiting up to pollInterval (4h) for
    // the badge count to reflect the packages that just got merged.
    property bool wasEmergeRunning: false

    // PORT_LOGDIR is configurable in /etc/portage/make.conf (set here to
    // ~/.local/share/logs, not the distro default /var/log) - ask portage
    // itself instead of hardcoding a path, resolved once at startup since
    // it never changes at runtime.
    property string emergeLogPath: ""

    readonly property string resolveLogPathScript: "portageq envvar PORT_LOGDIR 2>/dev/null || echo /var/log"

    // pgrep -x emerge also matches checkProc's own `emerge -pvuDN @world`
    // pretend-only check below (same process comm name), so a real build
    // is anything left after excluding that exact invocation - otherwise
    // the badge would flash "running" every statusInterval poll.
    //
    // Progress is scoped to the *current* (still-open) emerge.log session:
    // naively grepping the whole log for the latest "(N of M)" line finds
    // stale progress from an already-terminated session (e.g. the last
    // real build finished hours ago, then a later eix-sync session opened
    // and closed with no merge lines of its own) - that showed a fake
    // "Emerging" state in the tooltip even with nothing building. The awk
    // state machine resets on each "Started emerge on:" and only keeps
    // `prog` if that session hasn't hit a terminating marker yet.
    readonly property string statusScript: "
        emerge_log=\"$1\"
        running=$(pgrep -x emerge -a 2>/dev/null | grep -v -- '-pvuDN @world' | grep -q . && echo 1 || echo 0)
        sync_epoch=$(stat -c %Y /var/cache/eix/portage.eix 2>/dev/null || echo 0)
        progress=\"\"
        eta=\"\"
        if [ \"$running\" = \"1\" ]; then
            progress=$(awk '
                /Started emerge on:/ { open=1; prog=\"\" }
                /\\*\\*\\* terminating\\.|\\*\\*\\* exiting successfully\\./ { open=0 }
                open && /=== \\([0-9]+ of [0-9]+\\) (Compiling\\/Merging|Merging|Compiling)/ { prog=$0 }
                END { if (open) print prog }
            ' \"$emerge_log\" 2>/dev/null)
            eta=$(qlop -rp -M -C 2>/dev/null | sed -n 's/.*ETA: //p' | tail -1)
        fi
        printf '%s\\x1f%s\\x1f%s\\x1f%s' \"$running\" \"$sync_epoch\" \"$progress\" \"$eta\"
    "

    function check() {
        if (root.gameModeActive || checkProc.running)
            return;
        checkProc.running = true;
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: gameModeCheck.running = true
    }

    Timer {
        interval: root.statusInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.emergeLogPath === "")
                return;
            statusCheck.running = true;
        }
    }

    Process {
        id: gameModeCheck
        command: ["sh", "-c", "test -f ~/.cache/gamemode && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.gameModeActive = this.text.trim() === "1"
        }
    }

    Process {
        id: resolveLogPath
        command: ["sh", "-c", root.resolveLogPathScript]
        stdout: StdioCollector {
            onStreamFinished: root.emergeLogPath = this.text.trim() + "/emerge.log"
        }
        Component.onCompleted: running = true
    }

    Process {
        id: checkProc
        command: ["sh", "-c", "emerge -pvuDN @world 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/Total:\s*(\d+)\s*packages?/);
                root.pendingCount = match ? parseInt(match[1], 10) : 0;
            }
        }
    }

    Process {
        id: statusCheck
        command: ["sh", "-c", root.statusScript, "sh", root.emergeLogPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("\u001f");
                root.emergeRunning = parts[0] === "1";
                root.lastSyncEpoch = parseInt(parts[1], 10) || 0;

                const match = root.emergeRunning
                    ? parts[2].match(/\((\d+) of (\d+)\)\s+\S+\s+\(([^:]+)::/)
                    : null;
                root.emergeCurrent = match ? parseInt(match[1], 10) : 0;
                root.emergeTotal = match ? parseInt(match[2], 10) : 0;
                root.emergeAtom = match ? match[3] : "";
                // qlop -rp predicts from past merge history for this exact
                // package - 0 (or absent) when it's never been built
                // before, negative when the build already overran its own
                // average; either way there's nothing sane to show.
                const etaSeconds = root.emergeRunning ? parseInt(parts[3], 10) || 0 : 0;
                root.emergeEtaSeconds = etaSeconds > 0 ? etaSeconds : 0;

                if (root.wasEmergeRunning && !root.emergeRunning)
                    root.check();
                root.wasEmergeRunning = root.emergeRunning;
            }
        }
    }
}
