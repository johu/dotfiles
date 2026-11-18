import QtQuick
import "GentooParse.js" as P

// Updates page: security box, dependency-conflict box, pending list from the pretend run.
Item {
    id: page

    property var view

    readonly property var pr: view.pretend
    readonly property var gl: view.glsaD.affected
    readonly property bool hasSec: gl.length > 0
    readonly property bool hasConf: pr.hasConflict
    readonly property string note: (pr.resolveSeconds > 0 ? "pretend run " + Math.round(pr.resolveSeconds) + " s · " : "") + (view.glsaD.tookSeconds ? "glsa-check " + Math.round(view.glsaD.tookSeconds) + " s · " : "") + (view.pretendBusy ? "checking…" : (view.pretendEpoch > 0 ? "checked " + view.ageText(view.pretendEpoch) : "not checked yet"))

    property int cur: 0
    property bool expanded: false
    // "portage" | "live" | "flatpak" (Tab cycles)
    property string section: "portage"

    readonly property var live: view.liveD.items
    readonly property var fp: view.flatpakD
    readonly property var sections: [
        { id: "portage", title: "Portage", count: pr.pending.length },
        { id: "live", title: "Live ebuilds", count: live.length, extra: view.liveD.changed > 0 ? " (" + view.liveD.changed + " changed)" : "" },
        { id: "flatpak", title: "Flatpak", count: fp.updates.length }
    ]

    readonly property var rows: {
        if (section === "live")
            return live.map(i => ({
                    name: i.cat + "/" + i.name,
                    c2: i.installed !== "" ? i.installed : i.version,
                    c3: i.upstream !== "" ? i.upstream : "–",
                    c3color: i.state === "changed" ? Theme.yellow : Theme.subtext1,
                    c4: i.state === "changed" ? "changed upstream" : (i.state === "current" ? "up to date" : (i.state === "error" ? "check failed" : "not checked")),
                    c4color: i.state === "changed" ? Theme.yellow : (i.state === "current" ? Theme.green : view.dim),
                    detail: (i.url !== "" ? i.url + " [" + i.ref + "] · " : "") + "built " + view.ageText(i.builtEpoch) + " · " + i.repo,
                    sec: false
                }));
        if (section === "flatpak")
            return fp.updates.map(u => ({ name: u.name, c2: u.runtime ? "runtime" : "app", c3: u.origin, c3color: Theme.teal, c4: u.size.replace(/\u00a0/g, " ") + " installed size", detail: u.app, sec: false }));
        return pr.pending.map(p => ({ name: p.cat + "/" + p.name, c2: p.version, c3: p.repo, c3color: GentooStyle.repoColor(p.repo), c4: page.fixesAdvisory(p) ? "fixes a security advisory" : p.why, detail: (p.slot !== "" ? "slot " + p.slot + " · " : "") + p.use, sec: page.fixesAdvisory(p) }));
    }
    readonly property var columns: section === "live" ? ["PACKAGE", "INSTALLED", "UPSTREAM", "STATUS"] : (section === "flatpak" ? ["NAME", "KIND", "ORIGIN", "SIZE"] : ["PACKAGE", "VERSION", "REPO", "WHY"])

    readonly property int secH: hasSec ? 98 : 0
    readonly property int confH: hasConf ? 44 + Math.max(1, Math.min(2, pr.conflicts.length)) * 22 + 34 : 0
    readonly property int listTop: (hasSec ? secH + 16 : 0) + (hasConf ? confH + 16 : 0) + 4

    // packages whose update fixes an advisory
    function fixesAdvisory(p) {
        const id = p.cat + "/" + p.name;
        return page.gl.some(g => g.packages.indexOf(id) >= 0);
    }

    readonly property var hints: [[
            { keys: ["j", "k"], text: "move" },
            { keys: ["↵"], text: "package details" },
            { keys: ["x"], text: "conflict", ghost: !page.hasConf },
            { keys: ["g"], text: "security", ghost: !page.hasSec },
            { keys: ["Tab"], text: "section" },
            { keys: ["e"], text: page.section === "flatpak" ? "flatpak update" : (page.section === "live" ? "update live" : "emerge in terminal") },
            { keys: ["r"], text: "re-check" },
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
        const n = page.rows.length;
        const ctrl = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.cur = Math.min(n - 1, page.cur + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.cur = Math.max(0, page.cur - 1);
            return true;
        case Qt.Key_D:
            if (ctrl) {
                page.cur = Math.min(n - 1, page.cur + 8);
                return true;
            }
            return false;
        case Qt.Key_U:
            if (ctrl) {
                page.cur = Math.max(0, page.cur - 8);
                return true;
            }
            return false;
        case Qt.Key_Home:
            page.cur = 0;
            return true;
        case Qt.Key_End:
            page.cur = Math.max(0, n - 1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            page.expanded = !page.expanded;
            return true;
        case Qt.Key_X:
            if (page.hasConf)
                view.openRaw("conflict", "Dependency conflict", page.pr.conflictRaw);
            return true;
        case Qt.Key_G:
            if (page.hasSec)
                view.openText("security", "GLSA " + page.gl[0].id, ["glsa-text", page.gl[0].id]);
            return true;
        case Qt.Key_Tab:
            page.section = page.sections[(page.sections.findIndex(x => x.id === page.section) + 1) % page.sections.length].id;
            page.cur = 0;
            return true;
        case Qt.Key_E:
            if (page.section === "flatpak")
                view.inTerminal("flatpak update");
            else if (page.section === "live")
                view.inTerminal(Dependencies.has("smart-live-rebuild") ? "sudo smart-live-rebuild -- --ask --verbose" : "sudo emerge --ask --verbose @live-rebuild");
            else
                view.inTerminal("sudo emerge --ask --verbose --update --deep --newuse @world");
            return true;
        case Qt.Key_R:
            if (!view.fixture)
                PortageUpdates.check();
            view.refresh();
            return true;
        }
        return false;
    }

    onCurChanged: {
        page.expanded = false;
        list.positionViewAtIndex(page.cur, ListView.Contain);
    }

    // ---- security box ----
    Rectangle {
        visible: page.hasSec
        x: 0
        y: 0
        width: page.width
        height: page.secH
        radius: 12
        color: Theme.base
        border.width: 1
        border.color: Theme.red

        GentooIcon {
            x: 18
            y: 14
            size: 22
            kind: "error"
        }

        GText {
            x: 50
            y: 12
            width: parent.width - 70
            height: 26
            text: "Security: " + page.gl.length + (page.gl.length === 1 ? " advisory affects" : " advisories affect") + " installed packages"
            color: Theme.red
            strong: true
        }

        GText {
            x: 18
            y: 44
            width: parent.width - 36
            height: 22
            text: page.gl.length > 0 ? "GLSA " + page.gl[0].id + "  " + page.gl[0].packages.join(", ") + (page.gl[0].vulnerable !== "" ? " " + page.gl[0].vulnerable : "") + (page.gl[0].fixed !== "" ? "  fixed in " + page.gl[0].fixed : "") + (page.gl.length > 1 ? "  (+" + (page.gl.length - 1) + " more)" : "") : ""
            size: Theme.fontSize
        }

        GText {
            x: 18
            y: 66
            width: parent.width - 36
            height: 20
            text: "A package marked in the list below is fixed by the pending update.   g advisory text"
            color: view.dim
            size: Theme.fontSize - 1
        }
    }

    // ---- conflict box ----
    Rectangle {
        visible: page.hasConf
        x: 0
        y: page.hasSec ? page.secH + 16 : 0
        width: page.width
        height: page.confH
        radius: 12
        color: Theme.base
        border.width: 1
        border.color: Theme.yellow

        GText {
            x: 18
            y: 8
            width: parent.width - 36
            height: 26
            text: page.pr.conflicts.length > 0 ? "Skipped: dependency conflict" : "The update check reported a problem"
            color: Theme.yellow
            strong: true
        }

        Column {
            x: 18
            y: 38
            width: parent.width - 36

            Repeater {
                model: page.pr.conflicts.slice(0, 2)

                GText {
                    required property var modelData

                    width: parent.width
                    height: 22
                    size: Theme.fontSize
                    text: {
                        const a = P.splitAtom(modelData.candidate);
                        const who = modelData.requiredBy.slice(0, 3).join(", ") + (modelData.requiredBy.length > 3 ? ", …" : "");
                        return (a.cat ? a.cat + "/" + a.name + "-" + a.version : modelData.pkg) + " conflicts with " + modelData.requiredBy.length + " installed " + (modelData.requiredBy.length === 1 ? "package" : "packages") + " (" + who + ")";
                    }
                }
            }

            GText {
                visible: page.pr.conflicts.length === 0
                width: parent.width
                height: 22
                size: Theme.fontSize
                text: view.pretendText.split("\n").find(l => l.indexOf("!!!") === 0) ?? ""
            }
        }

        GText {
            x: 18
            y: parent.height - 26
            width: parent.width - 36
            height: 20
            text: "portage's own text, no suggested fix   x details"
            color: view.dim
            size: Theme.fontSize - 1
        }
    }

    // ---- pending ----
    Row {
        x: 0
        y: page.listTop
        height: 28
        spacing: 28

        Repeater {
            model: page.sections

            GText {
                required property var modelData

                height: 28
                text: modelData.title + " " + modelData.count + (modelData.extra ?? "")
                color: modelData.id === page.section ? Theme.blue : view.dim
                strong: modelData.id === page.section
                size: Theme.fontSize + 3
            }
        }
    }

    GText {
        x: Math.round(page.width * 0.35)
        y: page.listTop
        width: Math.round(page.width * 0.65)
        height: 28
        horizontalAlignment: Text.AlignRight
        text: page.section === "portage" ? (page.pr.parsed ? page.pr.rebuilds + " rebuilds · " + page.pr.newVersions + " new versions · " + page.pr.downloadText + " to download" : "") : (page.section === "live" ? (view.liveD.toolAvailable ? "upstream hashes via smart-live-rebuild" + (view.liveD.checkedEpoch ? ", checked " + view.ageText(view.liveD.checkedEpoch) : "") : "install smart-live-rebuild to compare upstream") : (page.fp.available ? "checked " + view.ageText(page.fp.checkedEpoch) : "flatpak is not installed"))
        color: view.dim
        size: Theme.fontSize - 1
    }

    Rectangle {
        x: 0
        y: page.listTop + 32
        width: page.width
        height: 1
        color: Theme.surface2
    }

    Repeater {
        model: page.columns.map((t, i) => ({ t: t, x: [32, 640, 940, 1100][i] }))

        GText {
            required property var modelData

            x: modelData.x
            y: page.listTop + 38
            height: 22
            text: modelData.t
            color: GentooStyle.faint
            size: Theme.fontSize - 3
            font.letterSpacing: 1
        }
    }

    ListView {
        id: list

        readonly property int visibleRows: Math.floor(height / 36)

        x: 0
        y: page.listTop + 64
        width: page.width
        height: page.height - y
        clip: true
        interactive: false
        model: page.rows

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool sel: index === page.cur
            readonly property bool open: sel && page.expanded
            readonly property bool secFix: modelData.sec

            width: ListView.view.width
            height: open ? 64 : 36

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: row.sel ? GentooStyle.rowSelected : "transparent"
            }

            Rectangle {
                visible: row.secFix
                x: 12
                y: 13
                width: 10
                height: 10
                radius: 5
                color: Theme.red
            }

            GText {
                x: 32
                width: 590
                height: 36
                text: modelData.name
                strong: row.sel
            }

            GText {
                x: 640
                width: 290
                height: 36
                text: modelData.c2
                color: row.sel ? Theme.text : Theme.subtext1
            }

            GText {
                x: 940
                width: 150
                height: 36
                text: modelData.c3
                color: modelData.c3color
            }

            GText {
                x: 1100
                width: parent.width - 1120
                height: 36
                text: modelData.c4
                color: row.secFix ? Theme.red : (modelData.c4color ?? view.dim)
                size: Theme.fontSize
            }

            GText {
                visible: row.open
                x: 32
                y: 36
                width: parent.width - 64
                height: 24
                text: modelData.detail
                color: view.dim
                size: Theme.fontSize - 1
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.cur = row.index
            }
        }
    }

    GText {
        visible: page.rows.length === 0 && (page.section !== "portage" || !page.pr.parsed || !page.hasConf)
        x: 0
        y: page.listTop + 90
        width: page.width
        height: 40
        horizontalAlignment: Text.AlignHCenter
        text: page.section === "live" ? "no live ebuilds installed" : (page.section === "flatpak" ? (page.fp.available ? "all flatpaks are up to date" : "flatpak is not installed") : (!page.pr.parsed ? (view.pretendBusy ? "checking for updates, this takes about a minute…" : "not checked yet, press r") : "the system is up to date"))
        color: view.dim
        size: Theme.fontSize + 3
    }
}
