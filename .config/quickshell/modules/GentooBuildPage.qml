import QtQuick
import Quickshell
import "GentooParse.js" as P

// Build page: while emerge merges, the queue, progress, ETA and the tail of build.log;
// otherwise the recent builds from emerge.log (qlop).
Item {
    id: page

    property var view

    readonly property var b: view.buildD
    readonly property bool live: b.running && b.current !== null
    readonly property string note: live ? "live, refreshed every 3 s" : "from emerge.log (qlop)"

    property int cur: 0
    // The selection follows the package being built until the user moves it.
    property bool follow: true

    readonly property int runIndex: queue.findIndex(q => q.state === "run")

    onRunIndexChanged: if (follow && live && runIndex >= 0) cur = runIndex

    onCurChanged: {
        if (live)
            queueList.positionViewAtIndex(Math.max(0, Math.min(cur, queue.length - 1)), ListView.Contain);
        else
            recentList.positionViewAtIndex(Math.max(0, Math.min(cur, b.recent.length - 1)), ListView.Contain);
    }

    onLiveChanged: {
        follow = true;
        cur = live && runIndex >= 0 ? runIndex : 0;
    }

    Component.onCompleted: if (live && runIndex >= 0) cur = runIndex

    function plain(atom) {
        const a = P.splitAtom(atom);
        return a.cat ? a.cat + "/" + a.name : atom;
    }

    readonly property int nowSec: b.now ?? Math.floor(view.nowMs / 1000)
    readonly property real frac: {
        if (!b.current)
            return 0;
        const avg = b.average.seconds ?? 0;
        if (avg <= 0)
            return 0.5;
        return Math.min(0.95, Math.max(0, (nowSec - b.current.start) / avg));
    }
    readonly property real progress: b.current ? Math.min(1, (b.current.i - 1 + frac) / Math.max(1, b.current.n)) : 0
    readonly property int eta: view.fixture ? (b.eta ?? 0) : PortageUpdates.emergeEtaSeconds
    readonly property string phase: {
        for (let i = b.logTail.length - 1; i >= 0; i--) {
            const m = b.logTail[i].match(/^>>> (.*)$/);
            if (m)
                return m[1].replace(/\.\.\.$/, "").replace(/ \(.*$/, "");
        }
        return b.logPath !== "" ? "building" : "starting";
    }

    readonly property var queue: {
        if (!b.current)
            return [];
        const out = b.session.map(s => ({ atom: page.plain(s.atom), state: s.end ? "done" : "run", secs: s.end ? s.end - s.start : 0 }));
        const seen = {};
        for (const o of out)
            seen[o.atom] = true;
        const fut = view.pretend.pending.map(p => p.cat + "/" + p.name).filter(a => !seen[a]);
        const need = Math.max(0, b.current.n - b.session.length);
        for (let i = 0; i < Math.min(need, fut.length); i++)
            out.push({ atom: fut[i], state: "wait", secs: 0 });
        if (need > fut.length)
            out.push({ atom: "… " + (need - fut.length) + " more", state: "more", secs: 0 });
        return out;
    }

    readonly property var hints: live ? [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["g", "G"], text: "current / end" },
                { keys: ["e"], text: "attach to terminal" },
                { keys: ["Esc"], text: "back" }
            ]] : [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["↵"], text: "build log", ghost: b.recent.length === 0 },
                { keys: ["r"], text: "refresh" },
                { keys: ["Esc"], text: "back" }
            ]]

    function handleKey(event) {
        const n = page.live ? page.queue.length : b.recent.length;
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.follow = false;
            page.cur = Math.min(n - 1, page.cur + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.follow = false;
            page.cur = Math.max(0, page.cur - 1);
            return true;
        case Qt.Key_G:
            page.follow = (event.modifiers & Qt.ShiftModifier) ? false : true;
            page.cur = (event.modifiers & Qt.ShiftModifier) ? Math.max(0, n - 1) : (page.live && page.runIndex >= 0 ? page.runIndex : 0);
            return true;
        case Qt.Key_E:
            if (page.live) {
                if (view.fixture)
                    console.log("GENTOO-ACTION attach");
                else
                    Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })' && herdr workspace focus w3 && herdr tab focus w3:t1"]);
                view.closeRequested();
            }
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!page.live && b.recent.length > 0) {
                const r = b.recent[Math.min(page.cur, b.recent.length - 1)];
                view.openText("buildlog", "Build log · " + r.atom, ["build-log", r.atom]);
            }
            return true;
        }
        return false;
    }

    // =============== running ===============
    Item {
        visible: page.live
        anchors.fill: parent

        GText {
            id: ofText

            x: 0
            y: 0
            height: 56
            text: page.b.current ? page.b.current.i + " of " + page.b.current.n : ""
            size: 38
            strong: true
            elide: Text.ElideNone
        }

        GText {
            x: ofText.implicitWidth + 16
            y: 12
            width: parent.width - ofText.implicitWidth - 16
            height: 40
            text: page.b.current ? page.b.current.atom : ""
            color: Theme.yellow
            size: Theme.fontSize + 4
        }

        Rectangle {
            x: 0
            y: 66
            width: parent.width
            height: 22
            radius: 11
            color: Theme.surface2

            Rectangle {
                width: parent.width * page.progress
                height: parent.height
                radius: 11
                color: Theme.yellow
            }
        }

        GText {
            x: 0
            y: 94
            height: 26
            text: Math.round(page.progress * 100) + " %"
            color: view.dim
        }

        GText {
            x: Math.round(parent.width / 2)
            y: 94
            width: Math.round(parent.width / 2)
            height: 26
            horizontalAlignment: Text.AlignRight
            color: view.dim
            text: (page.eta > 0 ? "ETA " + P.durationText(page.eta) + " · " : "") + "running " + P.durationText(Math.max(0, page.nowSec - page.b.sessionStart)) + " · load " + page.b.load.toFixed(1)
        }

        GText {
            x: 0
            y: 134
            height: 28
            text: "Queue"
            color: Theme.blue
            strong: true
            size: Theme.fontSize + 3
        }

        Rectangle {
            x: 0
            y: 166
            width: Math.round(parent.width * 0.42)
            height: 1
            color: Theme.surface2
        }

        ListView {
            id: queueList

            x: 0
            y: 174
            width: Math.round(parent.width * 0.42)
            height: parent.height - 174
            clip: true
            interactive: false
            model: page.queue

            delegate: Item {
                id: qrow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: index === page.cur ? GentooStyle.rowSelected : "transparent"
                }

                GentooIcon {
                    visible: modelData.state !== "more"
                    x: 8
                    y: 5
                    size: 24
                    kind: modelData.state === "done" ? "ok" : (modelData.state === "run" ? "active" : "idle")
                }

                GText {
                    x: 44
                    width: parent.width - 230
                    height: parent.height
                    text: modelData.atom
                    color: modelData.state === "wait" ? view.dim : (modelData.state === "more" ? GentooStyle.faint : Theme.text)
                    size: Theme.fontSize
                }

                GText {
                    x: parent.width - 170
                    width: 160
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    text: modelData.state === "done" ? P.longDuration(modelData.secs) : (modelData.state === "run" ? "building" : "")
                    color: view.dim
                    size: Theme.fontSize - 1
                }
            }
        }

        Rectangle {
            x: Math.round(parent.width * 0.42 + 40)
            y: 134
            width: parent.width - x
            height: parent.height - 134
            radius: 16
            color: GentooStyle.cardColor
            border.width: 1
            border.color: Theme.surface2

            GText {
                x: 24
                y: 16
                width: parent.width - 48
                height: 30
                text: page.b.current ? page.b.current.atom : ""
                strong: true
                size: Theme.fontSize + 3
            }

            Column {
                x: 24
                y: 56
                width: parent.width - 48

                GentooKV {
                    label: "Phase"
                    value: page.phase
                }

                GentooKV {
                    label: "Average build"
                    value: page.b.average.seconds ? P.durationText(page.b.average.seconds) + " (" + page.b.average.count + (page.b.average.count === 1 ? " build)" : " builds)") : "no earlier build"
                }

                GentooKV {
                    label: "Jobs"
                    value: (page.b.makeopts !== "" ? page.b.makeopts + " · " : "") + page.b.emergeProcs + (page.b.emergeProcs === 1 ? " emerge job" : " emerge jobs")
                }
            }

            GText {
                x: 24
                y: 160
                width: parent.width - 48
                height: 24
                text: page.b.logPath !== "" ? "build.log (last lines)" : "no readable build log yet"
                color: view.dim
                size: Theme.fontSize - 1
            }

            Rectangle {
                x: 24
                y: 186
                width: parent.width - 48
                height: 1
                color: Theme.surface2
            }

            Column {
                x: 24
                y: 194
                width: parent.width - 48

                Repeater {
                    model: page.b.logTail.slice(-Math.max(4, Math.floor((parent.parent.height - 210) / 22)))

                    GText {
                        required property string modelData

                        width: parent.width
                        height: 22
                        text: modelData
                        size: Theme.fontSize - 1
                    }
                }
            }
        }
    }

    // =============== idle ===============
    Item {
        visible: !page.live
        anchors.fill: parent

        GText {
            id: idleText

            x: 0
            y: 0
            height: 56
            text: page.b.running ? "preparing" : "idle"
            size: 38
            strong: true
            color: Theme.subtext1
            elide: Text.ElideNone
        }

        GText {
            visible: page.b.recent.length > 0
            x: idleText.implicitWidth + 28
            y: 12
            width: parent.width - idleText.implicitWidth - 28
            height: 40
            color: view.dim
            text: page.b.recent.length > 0 ? "last build " + page.plain(page.b.recent[0].atom) + " · " + P.durationText(page.b.recent[0].seconds) + " · " + P.whenText(page.b.recent[0].endEpoch, view.nowMs) : ""
        }

        GText {
            x: 0
            y: 78
            height: 28
            text: "Recent builds"
            color: Theme.blue
            strong: true
            size: Theme.fontSize + 3
        }

        GText {
            x: Math.round(parent.width * 0.4)
            y: 78
            width: Math.round(parent.width * 0.6)
            height: 28
            horizontalAlignment: Text.AlignRight
            text: page.b.todayCount > 0 ? page.b.todayCount + (page.b.todayCount === 1 ? " package" : " packages") + " rebuilt today between " + P.clock(page.b.todaySince) + " and " + P.clock(page.b.recent[0].endEpoch) : ""
            color: view.dim
            size: Theme.fontSize - 1
        }

        Rectangle {
            x: 0
            y: 110
            width: parent.width
            height: 1
            color: Theme.surface2
        }

        ListView {
            id: recentList

            x: 0
            y: 120
            width: parent.width
            height: parent.height - 120
            clip: true
            interactive: false
            model: page.b.recent

            delegate: Item {
                id: rrow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: index === page.cur ? GentooStyle.rowSelected : "transparent"
                }

                GentooIcon {
                    x: 8
                    y: 6
                    size: 24
                    kind: "ok"
                }

                GText {
                    x: 44
                    width: 230
                    height: parent.height
                    text: P.whenText(modelData.endEpoch, view.nowMs)
                    size: Theme.fontSize
                }

                GText {
                    x: 280
                    width: 520
                    height: parent.height
                    text: page.plain(modelData.atom)
                    size: Theme.fontSize
                }

                GText {
                    x: 820
                    width: 140
                    height: parent.height
                    text: P.durationText(modelData.seconds)
                    color: view.dim
                    size: Theme.fontSize - 1
                }
            }
        }

        GText {
            visible: page.b.recent.length === 0
            x: 0
            y: 160
            width: parent.width
            height: 40
            horizontalAlignment: Text.AlignHCenter
            text: Dependencies.has("qlop") ? "no builds in emerge.log" : Dependencies.why("qlop")
            color: view.dim
            size: Theme.fontSize + 3
        }
    }
}
