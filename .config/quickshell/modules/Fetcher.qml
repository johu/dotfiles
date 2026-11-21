import QtQuick
import Quickshell.Io

// One-shot command runner with parse, freshness, periodic refresh and retry.
// Owned by a domain singleton; views never use it directly.
//
// Vocabulary (see docs/plans/shared-data-sources.md):
//   loaded    - produced at least one good result; never reset by a failure
//   loading   - a run is in flight
//   error     - last failure, "" when the latest attempt worked
//   updatedAt - Date.now() of the last good result
//   value     - last good parse() result
//
// Success = exit code 0 AND parse() did not throw. Process.exited and
// StdioCollector.streamFinished are not ordered relative to each other, so
// a run is finalized by whichever of the two fires last (a non-zero exit
// finalizes immediately: there is nothing worth waiting for).
Item {
    id: root

    visible: false

    property var command: []
    property bool active: true
    property int interval: 0
    property int staleAfter: 0
    property var retryBackoff: [20000, 60000]
    property var parse: text => JSON.parse(text)
    // Applied via an `env` argv prefix: Process.environment does not reach
    // the child here (see SysMonCollector.qml).
    property var env: ({})
    property string failureText: "Could not load data"

    readonly property bool loaded: state_.loaded
    readonly property bool loading: state_.loading
    readonly property string error: state_.error
    readonly property real updatedAt: state_.updatedAt
    readonly property var value: state_.value

    signal fetched(var value)

    QtObject {
        id: state_
        property bool loaded: false
        property bool loading: false
        property string error: ""
        property real updatedAt: 0
        property var value: null
        property int retryIndex: 0
        // Per-run bookkeeping.
        property bool exited: false
        property bool streamDone: false
        property int exitCode: 0
        property string out: ""
    }

    readonly property var argv_: {
        const cmd = root.command || [];
        if (cmd.length === 0)
            return [];
        const keys = Object.keys(root.env || {});
        if (keys.length === 0)
            return cmd;
        return ["env"].concat(keys.map(k => k + "=" + root.env[k]), cmd);
    }

    function refresh(force) {
        if (state_.loading || root.argv_.length === 0)
            return;
        if (!force && state_.loaded && root.staleAfter > 0 && Date.now() - state_.updatedAt < root.staleAfter)
            return;
        state_.exited = false;
        state_.streamDone = false;
        state_.exitCode = 0;
        state_.out = "";
        state_.loading = true;
        retryTimer.stop();
        proc.running = true;
    }

    function finish_() {
        if (!state_.loading)
            return;
        state_.loading = false;
        let ok = state_.exitCode === 0 && state_.out.length > 0;
        let result = null;
        if (ok) {
            try {
                result = root.parse(state_.out);
            } catch (e) {
                ok = false;
            }
        }
        if (ok) {
            state_.value = result;
            state_.loaded = true;
            state_.error = "";
            state_.updatedAt = Date.now();
            state_.retryIndex = 0;
            root.fetched(result);
        } else {
            state_.error = root.failureText;
            if (!state_.loaded && root.active) {
                const b = root.retryBackoff;
                retryTimer.interval = b[Math.min(state_.retryIndex, b.length - 1)];
                state_.retryIndex++;
                retryTimer.restart();
            }
        }
    }

    Process {
        id: proc
        command: root.argv_
        stdout: StdioCollector {
            onStreamFinished: {
                state_.out = this.text;
                state_.streamDone = true;
                if (state_.exited)
                    root.finish_();
            }
        }
        onExited: (code, status) => {
            state_.exitCode = code;
            state_.exited = true;
            if (code !== 0 || state_.streamDone)
                root.finish_();
        }
    }

    Timer {
        id: retryTimer
        onTriggered: if (root.active) root.refresh(true)
    }

    Timer {
        interval: root.interval > 0 ? root.interval : 1000
        running: root.active && root.interval > 0
        repeat: true
        onTriggered: root.refresh(true)
    }

    onActiveChanged: {
        if (root.active)
            root.refresh(false);
        else
            retryTimer.stop();
    }

    // A command that appears (or changes) while idle and nothing was loaded
    // yet starts the first fetch.
    onArgv_Changed: if (root.active && !state_.loaded) root.refresh(false)

    Component.onCompleted: if (root.active) root.refresh(false)
}
