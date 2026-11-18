import QtQuick
import "GentooParse.js" as P

// Sync page: schedule, skip conditions, repository table, recent runs.
Item {
    id: page

    property var view

    readonly property var s: view.syncD
    readonly property string note: "portage-sync.timer"

    property int cur: 0
    property bool expanded: false

    readonly property var hints: [[
            { keys: ["j", "k"], text: "repo" },
            { keys: ["↵"], text: "repo details" },
            { keys: ["p"], text: view.paused ? "resume" : "pause" },
            { keys: ["s"], text: "sync now" },
            { keys: ["r"], text: "refresh" },
            { keys: ["Esc"], text: "back" }
        ]]

    function handleEscape() {
        if (page.expanded) {
            page.expanded = false;
            return true;
        }
        return false;
    }

    function handleKey(event) {
        const n = page.s.repos.length;
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.cur = Math.min(n - 1, page.cur + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.cur = Math.max(0, page.cur - 1);
            return true;
        case Qt.Key_G:
            page.cur = (event.modifiers & Qt.ShiftModifier) ? n - 1 : 0;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            page.expanded = !page.expanded;
            return true;
        case Qt.Key_S:
            view.syncNow();
            return true;
        case Qt.Key_P:
            view.togglePause();
            return true;
        }
        return false;
    }

    onCurChanged: {
        page.expanded = false;
        repoList.positionViewAtIndex(page.cur, ListView.Contain);
    }

    readonly property string lastSyncText: {
        if (!page.s.lastSyncEpoch)
            return "never";
        const r = page.s.runs.find(x => x.result === "ok");
        return P.whenText(page.s.lastSyncEpoch, view.nowMs) + (r ? " · ok" : "");
    }
    readonly property string nextText: {
        if (view.paused)
            return "paused";
        if (!page.s.timerActive || !page.s.nextEpoch)
            return "–";
        const left = page.s.nextEpoch - Math.floor(view.nowMs / 1000);
        return P.clock(page.s.nextEpoch) + (left > 0 ? " (in " + P.durationText(left) + ")" : " (due)");
    }
    readonly property bool wouldSkip: view.paused || page.s.gamemode || page.s.emergeRunning

    // ---- schedule card ----
    GentooCard {
        id: sched

        x: 0
        y: 0
        width: Math.floor((page.width - 22) / 2)
        height: 176
        title: "Schedule"
        accent: Theme.teal

        GentooIcon {
            x: 24
            y: 50
            size: 26
            kind: view.paused ? "paused" : (page.s.timerActive ? "active" : "error")
        }

        GText {
            x: 60
            y: 48
            height: 30
            text: view.paused ? "Sync paused" : (page.s.timerActive ? "Timer active" : "Timer not active")
            size: Theme.fontSize + 4
            strong: true
            color: view.paused ? Theme.yellow : (page.s.timerActive ? Theme.green : Theme.red)
        }

        Column {
            x: 24
            y: 88
            width: parent.width - 48

            GentooKV {
                label: "Interval"
                value: (page.s.interval !== "" ? "every " + page.s.interval.replace(/(\d)([a-z])/g, "$1 $2") : "–") + (page.s.first !== "" ? " (" + page.s.first.replace(/(\d)([a-z])/g, "$1 $2").replace("1 min 30 s", "90 s") + " after login)" : "")
            }

            GentooKV {
                label: "Last sync"
                value: page.lastSyncText
                valueColor: Theme.green
            }

            GentooKV {
                label: "Next sync"
                value: page.nextText
                valueColor: view.paused ? Theme.yellow : Theme.text
            }
        }
    }

    GentooCard {
        x: sched.width + 22
        y: 0
        width: page.width - sched.width - 22
        height: 176
        title: "Sync is skipped while"
        accent: Theme.yellow

        Column {
            x: 24
            y: 48
            width: parent.width - 48
            spacing: 4

            Repeater {
                model: [
                    { text: "game mode is on", on: page.s.gamemode },
                    { text: "an emerge is running", on: page.s.emergeRunning },
                    { text: "sync is paused", on: view.paused }
                ]

                Item {
                    required property var modelData

                    width: parent.width
                    height: 26

                    GentooIcon {
                        y: 2
                        size: 22
                        kind: modelData.on ? "warn" : "ok"
                    }

                    GText {
                        x: 34
                        width: parent.width - 120
                        height: parent.height
                        text: modelData.text
                    }

                    GText {
                        x: parent.width - 80
                        width: 80
                        height: parent.height
                        text: modelData.on ? "yes" : "no"
                        color: modelData.on ? Theme.yellow : Theme.green
                    }
                }
            }
        }

        GText {
            x: 24
            y: parent.height - 34
            width: parent.width - 48
            height: 22
            text: page.wouldSkip ? "the next timer run will be skipped" : "all clear: the next timer run goes through"
            color: page.wouldSkip ? Theme.yellow : view.dim
            size: Theme.fontSize - 1
        }
    }

    // ---- repositories ----
    GText {
        x: 0
        y: 198
        height: 28
        text: "Repositories"
        color: Theme.blue
        strong: true
        size: Theme.fontSize + 3
    }

    GText {
        x: Math.round(page.width * 0.4)
        y: 198
        width: Math.round(page.width * 0.6)
        height: 28
        horizontalAlignment: Text.AlignRight
        text: "last commit = newest upstream change (per-repo sync time is not recorded)"
        color: view.dim
        size: Theme.fontSize - 1
    }

    Rectangle {
        x: 0
        y: 230
        width: page.width
        height: 1
        color: Theme.surface2
    }

    readonly property var cols: [{ t: "REPO", x: 24 }, { t: "TYPE", x: 230 }, { t: "HEAD", x: 330 }, { t: "LAST COMMIT", x: 470 }, { t: "EBUILDS", x: 790 }, { t: "INSTALLED", x: 940 }]

    Repeater {
        model: page.cols

        GText {
            required property var modelData

            x: modelData.x
            y: 236
            height: 24
            text: modelData.t
            color: GentooStyle.faint
            size: Theme.fontSize - 3
            font.letterSpacing: 1
        }
    }

    ListView {
        id: repoList

        x: 0
        y: 264
        width: page.width
        height: page.height - 264 - 168
        clip: true
        model: page.s.repos
        interactive: false

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool sel: index === page.cur
            readonly property bool open: sel && page.expanded

            width: ListView.view.width
            height: open ? 64 : 34

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                radius: 8
                color: row.sel ? GentooStyle.rowSelected : "transparent"
            }

            Rectangle {
                x: 12
                y: 12
                width: 10
                height: 10
                radius: 5
                color: GentooStyle.repoColor(modelData.name)
            }

            GText {
                x: 32
                width: 190
                height: 34
                text: modelData.name
                strong: row.sel
            }

            GText {
                x: 230
                width: 90
                height: 34
                text: modelData.type
                color: view.dim
                size: Theme.fontSize
            }

            GText {
                x: 330
                width: 130
                height: 34
                text: modelData.head !== "" ? modelData.head : "–"
                color: view.dim
                size: Theme.fontSize
            }

            GText {
                x: 470
                width: 300
                height: 34
                text: modelData.type === "git" ? P.ageText(modelData.commitEpoch, view.nowMs) : "no remote"
                color: modelData.type !== "git" ? GentooStyle.faint : ((view.nowMs / 1000 - modelData.commitEpoch) < 5 * 86400 ? Theme.green : (view.nowMs / 1000 - modelData.commitEpoch) > 90 * 86400 ? Theme.yellow : Theme.subtext1)
                size: Theme.fontSize
            }

            GText {
                x: 790
                width: 140
                height: 34
                text: P.countText(modelData.ebuilds)
                size: Theme.fontSize
            }

            GText {
                x: 940
                width: 140
                height: 34
                text: P.countText(modelData.installed)
                size: Theme.fontSize
            }

            GText {
                visible: row.open
                x: 32
                y: 34
                width: parent.width - 64
                height: 26
                text: modelData.location + " · " + (modelData.sync !== "" ? "sync-type " + modelData.sync : "not synced") + " · priority " + modelData.priority + (modelData.subject !== "" ? " · " + modelData.subject : "")
                color: view.dim
                size: Theme.fontSize - 1
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.cur = row.index
            }
        }
    }

    // ---- recent runs ----
    GText {
        x: 0
        y: page.height - 160
        height: 28
        text: "Recent runs"
        color: Theme.blue
        strong: true
        size: Theme.fontSize + 3
    }

    GText {
        x: Math.round(page.width * 0.4)
        y: page.height - 160
        width: Math.round(page.width * 0.6)
        height: 28
        horizontalAlignment: Text.AlignRight
        text: "timer runs from the journal, durations from emerge.log"
        color: view.dim
        size: Theme.fontSize - 1
    }

    Rectangle {
        x: 0
        y: page.height - 128
        width: page.width
        height: 1
        color: Theme.surface2
    }

    Column {
        x: 0
        y: page.height - 122
        width: page.width

        Repeater {
            model: page.s.runs.slice(0, 4)

            Item {
                required property var modelData

                width: parent.width
                height: 28

                Rectangle {
                    x: 12
                    y: 9
                    width: 10
                    height: 10
                    radius: 5
                    color: modelData.result === "ok" ? Theme.green : (modelData.result === "failed" ? Theme.red : Theme.yellow)
                }

                GText {
                    x: 32
                    width: 220
                    height: parent.height
                    text: P.whenText(modelData.epoch, view.nowMs)
                    size: Theme.fontSize
                }

                GText {
                    x: 270
                    width: 120
                    height: parent.height
                    text: modelData.result
                    color: modelData.result === "ok" ? Theme.green : (modelData.result === "failed" ? Theme.red : Theme.yellow)
                    size: Theme.fontSize
                }

                GText {
                    x: 400
                    width: parent.width - 420
                    height: parent.height
                    text: modelData.detail
                    color: view.dim
                    size: Theme.fontSize - 1
                }
            }
        }

        GText {
            visible: page.s.runs.length === 0
            height: 28
            x: 12
            text: "no timer runs in the journal yet"
            color: view.dim
            size: Theme.fontSize
        }
    }
}
