import QtQuick
import "GentooParse.js" as P

// Overview page of the Gentoo view: six cards, hjkl / 1-6 select, Enter opens the page.
Item {
    id: page

    property var view

    readonly property var pageNames: ["sync", "updates", "build", "news", "stats", "housekeeping"]
    readonly property string note: view.hkD.depclean.world > 0 ? view.hkD.depclean.world + " packages in world" : ""

    readonly property int gap: 22
    readonly property int topH: Math.round((height - gap) * 0.45)
    readonly property int cardW: Math.floor((width - 2 * gap) / 3)
    readonly property int sideW: Math.round(cardW * 0.8)

    readonly property var s: view.syncD
    readonly property var pr: view.pretend
    readonly property var b: view.buildD
    readonly property var hk: view.hkD
    readonly property var st: view.statsD

    readonly property var hints: [[
            { keys: ["h", "j", "k", "l"], text: "card" },
            { keys: ["↵"], text: "open" },
            { keys: ["s"], text: "sync now" },
            { keys: ["p"], text: view.paused ? "resume sync" : "pause sync" },
            { keys: ["r"], text: "refresh" },
            { keys: ["q"], text: "close" }
        ]]

    function move(dr, dc) {
        let row = Math.floor(view.sel / 3) + dr;
        let col = view.sel % 3 + dc;
        row = Math.max(0, Math.min(1, row));
        col = Math.max(0, Math.min(2, col));
        view.sel = row * 3 + col;
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            page.move(0, -1);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            page.move(0, 1);
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            page.move(1, 0);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.move(-1, 0);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            view.openPage(page.pageNames[view.sel]);
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

    // ---- derived texts ----
    readonly property string lastSyncText: page.s.lastSyncEpoch ? view.ageText(page.s.lastSyncEpoch) : "never"
    readonly property string nextText: {
        if (view.paused)
            return "automatic sync is paused";
        if (!page.s.timerActive)
            return "the timer is not active";
        if (!page.s.nextEpoch)
            return "";
        const left = page.s.nextEpoch - Math.floor(view.nowMs / 1000);
        return "next " + P.clock(page.s.nextEpoch) + (left > 0 ? " (in " + P.durationText(left) + ")" : " (due)");
    }
    readonly property string intervalText: page.s.interval !== "" ? "every " + page.s.interval.replace(/(\d)([a-z])/g, "$1 $2") : "no interval"
    readonly property var lastRun: page.s.runs.length > 0 ? page.s.runs[0] : null
    readonly property string conflictNames: page.pr.conflicts.map(c => P.splitAtom(c.pkg + "-0").name || c.pkg).join(", ")
    readonly property bool pendingKnown: view.pretendEpoch > 0 && page.pr.parsed

    // ================= top row =================
    GentooCard {
        x: 0
        y: 0
        width: page.cardW
        height: page.topH
        title: "Sync"
        accent: Theme.teal
        selected: view.sel === 0

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 0
            onDoubleClicked: view.openPage("sync")
        }

        GText {
            x: 24
            y: 50
            width: parent.width - 48
            height: 50
            text: page.lastSyncText
            size: 34
            strong: true
        }

        GText {
            x: 24
            y: 100
            width: parent.width - 48
            height: 24
            text: page.nextText
            color: view.dim
        }

        GentooIcon {
            x: 24
            y: 138
            size: 24
            kind: view.paused ? "paused" : (page.s.timerActive ? "active" : "error")
        }

        GText {
            x: 58
            y: 138
            width: parent.width - 82
            height: 24
            text: view.paused ? "paused · " + page.intervalText : (page.s.timerActive ? "timer active · " + page.intervalText : "timer not active")
        }

        Column {
            x: 24
            y: parent.height - 3 * 28 - 14
            width: parent.width - 48

            GentooKV {
                label: "Last result"
                value: page.lastRun ? (page.lastRun.result + (page.lastRun.result === "ok" ? "" : " · " + page.lastRun.detail)) : "no runs yet"
                valueColor: !page.lastRun ? view.dim : (page.lastRun.result === "ok" ? Theme.green : (page.lastRun.result === "failed" ? Theme.red : Theme.yellow))
            }

            GentooKV {
                label: "Game mode"
                value: page.s.gamemode ? "on" : "off"
                valueColor: page.s.gamemode ? Theme.yellow : Theme.subtext1
            }

            GentooKV {
                label: "Repos"
                value: String(page.s.repos.length)
                valueColor: Theme.subtext1
            }
        }
    }

    GentooCard {
        x: page.cardW + page.gap
        y: 0
        width: page.cardW
        height: page.topH
        title: "Updates"
        accent: Theme.blue
        selected: view.sel === 1

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 1
            onDoubleClicked: view.openPage("updates")
        }

        GText {
            id: pendingNum

            x: 24
            y: 44
            height: 64
            text: page.pendingKnown ? String(page.pr.total) : (view.pretendBusy ? "…" : "–")
            size: 54
            strong: true
            elide: Text.ElideNone
        }

        GText {
            x: pendingNum.x + pendingNum.implicitWidth + 14
            y: 74
            height: 30
            text: page.pendingKnown ? "pending" : (view.pretendBusy ? "checking, takes about a minute" : "not checked yet")
            color: view.dim
            size: Theme.fontSize + 3
        }

        GText {
            x: 24
            y: 108
            width: parent.width - 48
            height: 24
            text: (page.pendingKnown ? page.pr.newVersions + " new · " + page.pr.rebuilds + " rebuilds" : "") + (view.liveD.items.length > 0 ? " · " + view.liveD.items.length + " live" + (view.liveD.changed > 0 ? " (" + view.liveD.changed + " changed)" : "") : "") + (view.flatpakD.updates.length > 0 ? " · " + view.flatpakD.updates.length + " flatpak" : "")
            color: view.dim
        }

        GentooIcon {
            x: 24
            y: 138
            size: 22
            kind: view.securityAffected ? "error" : "ok"
        }

        GText {
            x: 56
            y: 137
            width: parent.width - 80
            height: 24
            text: view.securityAffected ? view.glsaD.affected.length + (view.glsaD.affected.length === 1 ? " security advisory affects you" : " security advisories affect you") : "no security advisories"
            color: view.securityAffected ? Theme.red : Theme.green
            strong: view.securityAffected
        }

        Rectangle {
            visible: page.pr.hasConflict
            x: 24
            y: 176
            width: parent.width - 48
            height: 58
            radius: 10
            color: Theme.mantle
            border.width: 1
            border.color: Theme.yellow

            GText {
                x: 14
                y: 6
                width: parent.width - 28
                height: 24
                text: page.pr.conflicts.length > 0 ? page.pr.conflicts.length + (page.pr.conflicts.length === 1 ? " update skipped: dependency conflict" : " updates skipped: dependency conflict") : "update check failed"
                color: Theme.yellow
                strong: true
            }

            GText {
                x: 14
                y: 30
                width: parent.width - 28
                height: 22
                text: page.pr.conflicts.length > 0 ? page.conflictNames : view.pretendText.split("\n").find(l => l.indexOf("!!!") === 0) ?? ""
                color: view.dim
                size: Theme.fontSize
            }
        }

        GText {
            x: 24
            y: parent.height - 38
            width: parent.width - 48
            height: 24
            text: view.pretendEpoch > 0 ? "checked " + view.ageText(view.pretendEpoch) : ""
            color: GentooStyle.faint
            size: Theme.fontSize - 1
        }
    }

    GentooCard {
        x: 2 * (page.cardW + page.gap)
        y: 0
        width: page.cardW
        height: page.topH
        title: "Build"
        accent: page.b.running && page.b.current ? Theme.yellow : view.dim
        selected: view.sel === 2

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 2
            onDoubleClicked: view.openPage("build")
        }

        // running
        Item {
            visible: page.b.running && page.b.current !== null
            anchors.fill: parent

            GText {
                x: 24
                y: 44
                height: 50
                text: page.b.current ? page.b.current.i + " of " + page.b.current.n : ""
                size: 36
                strong: true
            }

            GText {
                x: 24
                y: 96
                width: parent.width - 48
                height: 24
                text: page.b.current ? page.b.current.atom : ""
                color: Theme.yellow
            }

            Rectangle {
                x: 24
                y: 134
                width: parent.width - 48
                height: 12
                radius: 6
                color: Theme.surface2

                Rectangle {
                    width: page.b.current ? parent.width * Math.max(0, page.b.current.i - 1) / page.b.current.n + parent.width * 0.5 / page.b.current.n : 0
                    height: parent.height
                    radius: 6
                    color: Theme.yellow
                }
            }

            GText {
                x: 24
                y: 156
                width: parent.width - 48
                height: 24
                text: view.fixture ? "" : (PortageUpdates.emergeEtaSeconds > 0 ? "ETA " + P.durationText(PortageUpdates.emergeEtaSeconds) : "ETA unknown")
                color: view.dim
            }
        }

        // idle
        Item {
            visible: !(page.b.running && page.b.current !== null)
            anchors.fill: parent

            GText {
                x: 24
                y: 44
                height: 50
                text: page.b.running ? "preparing" : "idle"
                size: 34
                strong: true
                color: Theme.subtext1
            }

            GText {
                visible: page.b.recent.length > 0
                x: 24
                y: 108
                height: 20
                text: "Last build"
                color: GentooStyle.faint
                size: Theme.fontSize - 1
            }

            GText {
                visible: page.b.recent.length > 0
                x: 24
                y: 130
                width: parent.width - 48
                height: 26
                text: page.b.recent.length > 0 ? P.splitAtom(page.b.recent[0].atom).cat + "/" + P.splitAtom(page.b.recent[0].atom).name : ""
                size: Theme.fontSize + 2
            }

            GText {
                visible: page.b.recent.length > 0
                x: 24
                y: 158
                width: parent.width - 48
                height: 22
                text: page.b.recent.length > 0 ? P.durationText(page.b.recent[0].seconds) + " · " + P.whenText(page.b.recent[0].endEpoch, view.nowMs) : ""
                color: view.dim
                size: Theme.fontSize
            }

            GText {
                visible: page.b.todayCount > 0
                x: 24
                y: 200
                width: parent.width - 48
                height: 22
                text: page.b.todayCount + (page.b.todayCount === 1 ? " package" : " packages") + " rebuilt today since " + P.clock(page.b.todaySince)
                color: view.dim
                size: Theme.fontSize
            }

            GText {
                visible: !Dependencies.has("qlop")
                x: 24
                y: 200
                width: parent.width - 48
                height: 22
                text: Dependencies.why("qlop")
                color: Theme.yellow
                size: Theme.fontSize
            }
        }

        GText {
            x: 24
            y: parent.height - 38
            width: parent.width - 48
            height: 24
            text: page.b.running ? "" : "shows progress while emerge runs"
            color: GentooStyle.faint
            size: Theme.fontSize - 1
        }
    }

    // ================= bottom row =================
    GentooCard {
        x: 0
        y: page.topH + page.gap
        width: page.sideW
        height: page.height - page.topH - page.gap
        title: "News"
        accent: Theme.mauve
        selected: view.sel === 3

        readonly property var shown: view.newsD.items.filter(i => i.state !== "hidden")

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 3
            onDoubleClicked: view.openPage("news")
        }

        GText {
            id: unreadNum

            x: 24
            y: 44
            height: 64
            text: String(view.newsD.unread)
            size: 54
            strong: true
            elide: Text.ElideNone
            color: view.newsD.unread > 0 ? Theme.mauve : Theme.text
        }

        GText {
            x: unreadNum.x + unreadNum.implicitWidth + 14
            y: 74
            height: 30
            text: "unread"
            color: view.dim
            size: Theme.fontSize + 3
        }

        GText {
            x: 24
            y: 120
            height: 20
            text: "Latest"
            color: GentooStyle.faint
            size: Theme.fontSize - 1
        }

        Column {
            x: 24
            y: 144
            width: parent.width - 48

            Repeater {
                model: parent.parent.shown.slice(0, 3)

                Item {
                    required property var modelData

                    width: parent.width
                    height: 28

                    GText {
                        width: 66
                        height: parent.height
                        text: modelData.posted.slice(5)
                        color: view.dim
                        size: Theme.fontSize
                    }

                    GText {
                        x: 70
                        width: parent.width - 70
                        height: parent.height
                        text: modelData.title
                        strong: modelData.state === "unread"
                        size: Theme.fontSize
                    }
                }
            }
        }

        GText {
            visible: parent.shown.length === 0 && view.newsD.hidden > 0
            x: 24
            y: 144
            width: parent.width - 48
            height: 44
            wrapMode: Text.WordWrap
            text: view.newsD.hidden + " hidden items (already purged); h in the News page shows them"
            color: view.dim
            size: Theme.fontSize
        }

        GText {
            x: 24
            y: parent.height - 38
            width: parent.width - 48
            height: 24
            text: view.newsD.unread === 0 ? (view.newsD.read + view.newsD.unread) + " items, all read" + (view.newsD.hidden > 0 ? " · " + view.newsD.hidden + " hidden" : "") : view.newsD.unread + " of " + (view.newsD.read + view.newsD.unread) + " items unread"
            color: GentooStyle.faint
            size: Theme.fontSize - 1
        }
    }

    GentooCard {
        x: page.sideW + page.gap
        y: page.topH + page.gap
        width: page.width - 2 * page.sideW - 2 * page.gap
        height: page.height - page.topH - page.gap
        title: "Statistics"
        accent: Theme.green
        selected: view.sel === 4

        readonly property var repoSlices: page.st.treeByRepo.filter(r => r[1] > 0)
        readonly property var eapi: page.st.eapiTree
        readonly property int eapiTotal: eapi.reduce((a, e) => a + e[1], 0)
        readonly property int donutSize: Math.min(height - 90, 220)

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 4
            onDoubleClicked: view.openPage("stats")
        }

        GentooDonut {
            x: 24
            y: Math.round(56 + (parent.height - 80 - parent.donutSize) / 2)
            width: parent.donutSize
            height: parent.donutSize
            thickness: Math.round(parent.donutSize * 0.14)
            center: P.kText(page.st.treeTotal)
            caption: "ebuilds"
            slices: parent.repoSlices.map(r => ({ value: r[1], color: GentooStyle.repoColor(r[0]) }))
        }

        Item {
            x: parent.donutSize + 56
            y: 50
            width: parent.width - parent.donutSize - 80
            height: parent.height - 60

            GText {
                height: 22
                text: "Ebuilds by repository"
                color: view.dim
                size: Theme.fontSize - 1
            }

            Column {
                y: 26
                width: parent.width

                Repeater {
                    model: page.st.treeByRepo.filter(r => r[1] > 0).slice(0, 6)

                    Item {
                        required property var modelData

                        width: parent.width
                        height: 27

                        Rectangle {
                            y: 9
                            width: 10
                            height: 10
                            radius: 5
                            color: GentooStyle.repoColor(modelData[0])
                        }

                        GText {
                            x: 20
                            width: parent.width - 220
                            height: parent.height
                            text: modelData[0]
                        }

                        GText {
                            x: parent.width - 200
                            width: 110
                            height: parent.height
                            horizontalAlignment: Text.AlignRight
                            text: P.countText(modelData[1])
                            color: view.dim
                            size: Theme.fontSize - 1
                        }

                        GText {
                            x: parent.width - 80
                            width: 80
                            height: parent.height
                            horizontalAlignment: Text.AlignRight
                            text: P.pct(modelData[1], page.st.treeTotal)
                            color: GentooStyle.faint
                            size: Theme.fontSize - 1
                        }
                    }
                }
            }

            GText {
                y: parent.height - 100
                height: 22
                text: "EAPI in ::gentoo"
                color: view.dim
                size: Theme.fontSize - 1
            }

            Row {
                y: parent.height - 72
                width: parent.width
                height: 16

                Repeater {
                    model: parent.parent.parent.eapi

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: parent.width * modelData[1] / Math.max(1, parent.parent.parent.eapiTotal)
                        height: 16
                        color: [Theme.blue, Theme.surface2, Theme.green][index % 3]
                    }
                }
            }

            Row {
                y: parent.height - 46
                spacing: 24

                Repeater {
                    model: parent.parent.parent.eapi

                    Row {
                        required property var modelData
                        required property int index

                        spacing: 6

                        Rectangle {
                            y: 6
                            width: 10
                            height: 10
                            radius: 5
                            color: [Theme.blue, Theme.surface2, Theme.green][index % 3]
                        }

                        GText {
                            height: 22
                            text: modelData[0] + "  " + P.pct(modelData[1], parent.parent.parent.parent.eapiTotal)
                            color: view.dim
                            size: Theme.fontSize - 1
                        }
                    }
                }
            }
        }
    }

    GentooCard {
        x: page.width - page.sideW
        y: page.topH + page.gap
        width: page.sideW
        height: page.height - page.topH - page.gap
        title: "Housekeeping"
        accent: Theme.maroon
        selected: view.sel === 5

        readonly property var oldKernels: page.hk.kernels.list.filter(k => P.kernelRemovals(page.hk.kernels.list, page.hk.kernels.running).indexOf(k.version) >= 0)

        MouseArea {
            anchors.fill: parent
            onClicked: view.sel = 5
            onDoubleClicked: view.openPage("housekeeping")
        }

        Column {
            x: 24
            y: 54
            width: parent.width - 48

            GentooKV {
                labelWidth: 228
                label: "Config files waiting"
                value: String(page.hk.cfgCount)
                valueColor: page.hk.cfgCount > 0 ? Theme.yellow : Theme.green
            }

            GentooKV {
                labelWidth: 228
                label: "Depclean candidates"
                value: String(page.hk.depclean.remove)
                valueColor: page.hk.depclean.remove > 0 ? Theme.yellow : Theme.green
            }

            GentooKV {
                labelWidth: 228
                label: "Distfiles"
                value: P.bytesText(page.hk.distfiles.totalBytes)
                valueColor: Theme.subtext1
            }

            GentooKV {
                labelWidth: 228
                label: "Kernel running"
                value: page.hk.kernels.running.replace(/-gentoo.*$/, "")
                valueColor: Theme.subtext1
            }

            GentooKV {
                labelWidth: 228
                label: "Old kernels to remove"
                value: String(parent.parent.oldKernels.length)
                valueColor: parent.parent.oldKernels.length > 0 ? Theme.yellow : Theme.green
            }

            GentooKV {
                labelWidth: 228
                label: "Reboot needed"
                value: page.hk.kernels.reboot ? "yes" : "no"
                valueColor: page.hk.kernels.reboot ? Theme.yellow : Theme.subtext1
            }

            GentooKV {
                labelWidth: 228
                label: "Not in tree anymore"
                value: page.hk.notInTree.length + (page.hk.notInTree.length === 1 ? " pkg" : " pkgs")
                valueColor: page.hk.notInTree.length > 0 ? Theme.yellow : Theme.green
            }
        }

        GText {
            visible: !Dependencies.has("eclean-dist")
            x: 24
            y: parent.height - 38
            width: parent.width - 48
            height: 24
            text: Dependencies.why("eclean-dist")
            color: Theme.yellow
            size: Theme.fontSize - 1
        }
    }
}
