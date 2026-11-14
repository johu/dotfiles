pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polls `emerge -pvuDN @world` on a long interval and exposes the "Total: N
// packages" count for Logo.qml's badge. Skipped in game mode (see
// NightLight.qml), as dependency resolution is too heavy.
Singleton {
    id: root

    readonly property int pollInterval: 4 * 60 * 60 * 1000
    property int pendingCount: 0
    property bool gameModeActive: false
    // Set when the pretend run yields no "Total" line (blocked/masked dep or
    // USE conflict, not just zero updates). conflictSummary is the first "!!!"
    // line, for the tooltip.
    property bool hasConflict: false
    property string conflictSummary: ""

    // Live build state, polled every statusInterval (cheap: pgrep, a stat and
    // an awk pass over emerge.log).
    readonly property int statusInterval: 5000
    property bool emergeRunning: false
    property int lastSyncEpoch: 0
    property int emergeCurrent: 0
    property int emergeTotal: 0
    property string emergeAtom: ""
    property int emergeEtaSeconds: 0
    // Fires a recheck when a build ends instead of waiting up to pollInterval
    // (4h) for the badge to catch up.
    property bool wasEmergeRunning: false
    // True once the current emerge was seen merging ("(N of M)" line). A sync
    // also counts as emergeRunning but never merges, which tells them apart.
    property bool sawRealBuild: false
    // emerge running without merge progress: a sync, or a build still fetching.
    readonly property bool syncOrIdle: emergeRunning && emergeTotal === 0

    // PORT_LOGDIR is set in make.conf (not the distro default); ask portage
    // once at startup instead of hardcoding.
    property string emergeLogPath: ""

    readonly property string resolveLogPathScript: "portageq envvar PORT_LOGDIR 2>/dev/null || echo /var/log"

    // pgrep -x emerge also matches our own pretend check, so exclude that exact
    // invocation or the badge flashes "running" on every poll.
    //
    // Progress is scoped to the current emerge.log session: the latest
    // "(N of M)" in the whole log can be stale from a finished build and showed
    // a fake "Emerging" state. The awk resets on each "Started emerge on:" and
    // keeps `prog` only while the session is still open.
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
        // Merge stderr: blockers and USE conflicts print as "!!!" lines, needed to
        // tell a conflict from "0 updates".
        command: ["sh", "-c", "emerge -pvuDN @world 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/Total:\s*(\d+)\s*packages?/);
                if (match) {
                    root.pendingCount = parseInt(match[1], 10);
                    root.hasConflict = false;
                    root.conflictSummary = "";
                } else {
                    root.pendingCount = 0;
                    const conflictLine = this.text.match(/^!!!.*$/m);
                    root.hasConflict = conflictLine !== null;
                    root.conflictSummary = conflictLine ? conflictLine[0].replace(/^!!!\s*/, "") : "";
                }
            }
        }
    }

    // Desktop notification when an emerge run ends.
    Process {
        id: notifyDone
        command: ["notify-send", "-a", "Portage", "-i", Quickshell.shellPath("assets/gentoo-logo.svg"),
                  "Emerge finished", "The emerge process has completed."]
    }

    Process {
        id: notifySyncDone
        command: ["notify-send", "-a", "Portage", "-i", Quickshell.shellPath("assets/gentoo-logo.svg"),
                  "Sync finished", "The portage tree sync has completed."]
    }

    Process {
        id: statusCheck
        command: ["sh", "-c", root.statusScript, "sh", root.emergeLogPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("\u001f");
                root.emergeRunning = parts[0] === "1";
                // The eix cache mtime moves when a sync finishes (eix-update runs last).
                // Skip the first poll (previous == 0).
                const newSyncEpoch = parseInt(parts[1], 10) || 0;
                if (root.lastSyncEpoch > 0 && newSyncEpoch > root.lastSyncEpoch)
                    notifySyncDone.running = true;
                root.lastSyncEpoch = newSyncEpoch;

                const match = root.emergeRunning
                    ? parts[2].match(/\((\d+) of (\d+)\)\s+\S+\s+\(([^:]+)::/)
                    : null;
                root.emergeCurrent = match ? parseInt(match[1], 10) : 0;
                root.emergeTotal = match ? parseInt(match[2], 10) : 0;
                root.emergeAtom = match ? match[3] : "";
                // qlop -rp predicts from past merges: 0 or absent if never built, negative
                // if already overrun; nothing sensible to show either way.
                const etaSeconds = root.emergeRunning ? parseInt(parts[3], 10) || 0 : 0;
                root.emergeEtaSeconds = etaSeconds > 0 ? etaSeconds : 0;

                if (root.emergeRunning && root.emergeTotal > 0)
                    root.sawRealBuild = true;

                if (root.wasEmergeRunning && !root.emergeRunning) {
                    root.check();
                    // Only notify for a real build, not a sync.
                    if (root.sawRealBuild)
                        notifyDone.running = true;
                    root.sawRealBuild = false;
                }
                root.wasEmergeRunning = root.emergeRunning;
            }
        }
    }
}
