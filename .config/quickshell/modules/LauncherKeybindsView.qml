import QtQuick
import Quickshell
import Quickshell.Io

// Keybindings cheat sheet of the launcher: every shortcut in one overview,
// grouped by category and flowed into two columns, with a live `/` filter.
//
// Data model (what a page is, so more sources can be added later):
//   page    { id, title, sections }
//   section { title, color, rows }
//   row     { keys: ["Super", "Shift", "H J K L"], text: "Move window left/down/up/right" }
// `pages` holds one page per source. Today there is one (Hyprland, read from
// `hyprctl binds -j`; descriptions come from `desc =` in keybinds.lua). A
// second source, e.g. the keys of the launcher views, is one more entry in
// `pages` (via `extraPages`; Tab then switches pages); nothing else in the
// view changes.
// Content that does not fit on one screen continues on further screens
// (j / k, PgDn / PgUp), so more rows never break the layout.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1700
    readonly property int preferredHeight: 1050

    // ---- Hyprland source ----
    property var hyprBinds: []
    property bool loaded: false
    property bool failed: false

    Process {
        id: bindsProc

        command: ["hyprctl", "binds", "-j"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    view.hyprBinds = JSON.parse(this.text);
                } catch (e) {
                    view.failed = true;
                }
                view.loaded = true;
            }
        }
        onExited: code => {
            if (code !== 0) {
                view.failed = true;
                view.loaded = true;
            }
        }
    }

    readonly property var modNames: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    readonly property var xf86: ({
            AudioRaiseVolume: "Vol +",
            AudioLowerVolume: "Vol −",
            AudioMute: "Mute",
            AudioMicMute: "Mic mute",
            AudioPlay: "Play",
            AudioPause: "Pause",
            AudioNext: "Next",
            AudioPrev: "Prev",
            MonBrightnessUp: "Bright +",
            MonBrightnessDown: "Bright −"
        })

    function keyLabel(k) {
        if (k.startsWith("XF86")) {
            const n = k.slice(4);
            return view.xf86[n] ?? n.replace(/([a-z])([A-Z])/g, "$1 $2");
        }
        switch (k) {
        case "mouse:272":
            return "Left mouse";
        case "mouse:273":
            return "Right mouse";
        case "mouse:274":
            return "Middle mouse";
        case "mouse_down":
            return "Wheel ↓";
        case "mouse_up":
            return "Wheel ↑";
        }
        if (k.length === 1)
            return k.toUpperCase();
        // "PRINT" -> "Print"; mixed case ("Return") stays
        return k === k.toUpperCase() ? k.charAt(0) + k.slice(1).toLowerCase() : k;
    }

    // Category: an explicit "Name: text" prefix wins, then keywords.
    readonly property var categoryOrder: ["Apps", "Windows", "Workspaces", "Capture", "Media & hardware"]
    readonly property var categoryColor: ({
            "Apps": Theme.mauve,
            "Windows": Theme.blue,
            "Workspaces": Theme.green,
            "Capture": Theme.yellow,
            "Media & hardware": Theme.teal,
            "Other": Theme.subtext1
        })
    readonly property var extraColors: [Theme.maroon, Theme.pink, Theme.lavender]

    function categorize(desc) {
        const m = desc.match(/^([A-Za-z0-9][A-Za-z0-9 &]{1,17}): (.+)$/);
        if (m)
            return { cat: m[1], text: m[2] };
        const d = desc.toLowerCase();
        let cat = "Other";
        if (/discord/.test(d))
            cat = "Apps";
        else if (/workspace/.test(d))
            cat = "Workspaces";
        else if (/screenshot|record|ocr|qr code|annotate|capture/.test(d))
            cat = "Capture";
        else if (/volume|mute|brightness|^play|^pause|^next|^previous|mic/.test(d))
            cat = "Media & hardware";
        else if (/window|float|fullscreen|split|focus|minimi|resize|drag/.test(d))
            cat = "Windows";
        else if (/launcher|terminal|clipboard|file manager|logout|lock|keybind|waybar|discord/.test(d))
            cat = "Apps";
        return { cat: cat, text: desc };
    }

    function modsOf(mask) {
        return view.modNames.filter(m => (mask & m[0]) !== 0).map(m => m[1]);
    }

    // Folds "Focus window left/down/up/right" and "Go to workspace 1..10"
    // (same modifiers, same text but the last word, three or more binds) into
    // one row; smaller groups stay separate rows.
    function collapse(binds) {
        const out = [];
        const groups = {};
        const dirs = ["left", "down", "up", "right"];
        for (const b of binds) {
            const desc = b.description || "(no description)";
            const words = desc.split(" ");
            const last = words[words.length - 1];
            const stem = words.slice(0, -1).join(" ");
            const numeric = /^\d+$/.test(last);
            if (stem === "" || !(numeric || dirs.includes(last))) {
                out.push({ b: b, desc: desc });
                continue;
            }
            const gk = b.modmask + "|" + stem + "|" + (numeric ? "n" : "d");
            if (!groups[gk]) {
                groups[gk] = { fold: true, b: b, stem: stem, numeric: numeric, members: [] };
                out.push(groups[gk]);
            }
            groups[gk].members.push({ b: b, desc: desc, last: last, key: view.keyLabel(b.key) });
        }
        const res = [];
        for (const e of out) {
            if (!e.fold) {
                res.push(e);
            } else if (e.members.length >= 3) {
                e.last = e.members.map(m => m.last);
                e.keys = e.members.map(m => m.key);
                res.push(e);
            } else {
                for (const m of e.members)
                    res.push({ b: m.b, desc: m.desc });
            }
        }
        return res;
    }

    // Rough width of a key-cap group, to decide whether two equal-rank
    // alternatives fit in the key column.
    function capsWidth(keys) {
        return keys.reduce((w, k) => w + k.length * 9 + 20, 0) + (keys.length - 1) * 22;
    }

    function buildHyprPage() {
        const byCat = {};
        for (const r of view.collapse(view.hyprBinds)) {
            const b = r.b;
            let keys, desc;
            if (r.fold && r.keys) {
                keys = view.modsOf(b.modmask).concat([r.numeric ? r.keys[0] + " … " + r.keys[r.keys.length - 1] : r.keys.join(" ")]);
                desc = r.stem + " " + (r.numeric ? r.last[0] + "–" + r.last[r.last.length - 1] : r.last.join("/"));
            } else {
                keys = view.modsOf(b.modmask).concat([view.keyLabel(b.key)]);
                desc = r.desc;
            }
            const c = view.categorize(desc);
            const list = (byCat[c.cat] = byCat[c.cat] ?? []);
            // Two bindings for one action: show the Super one only; if
            // neither or both use Super, show both as "a / b" when they fit.
            const same = list.find(x => x.text === c.text && x.alts.length === 1);
            const isSuper = k => k[0] === "Super";
            if (same && isSuper(keys) && !isSuper(same.alts[0])) {
                same.alts = [keys];
                same.keys = keys;
            } else if (same && isSuper(same.alts[0]) && !isSuper(keys)) {
                // keep the Super binding
            } else if (same && view.capsWidth(same.alts[0]) + view.capsWidth(keys) + 40 <= 340) {
                same.alts.push(keys);
            } else {
                list.push({ keys: keys, alts: [keys], text: c.text });
            }
        }
        // Rows that start with the same word ("Screenshot ...", "Record ...")
        // sit together; a group appears where its first row was and keeps the
        // order of the config inside.
        for (const n in byCat) {
            const order = [], groups = {};
            for (const r of byCat[n]) {
                const w = r.text.split(" ")[0];
                if (!groups[w]) {
                    groups[w] = [];
                    order.push(w);
                }
                groups[w].push(r);
            }
            byCat[n] = order.reduce((acc, w) => acc.concat(groups[w]), []); // no flatMap in this Qt's JS engine
        }
        const names = Object.keys(byCat);
        const ordered = view.categoryOrder.filter(n => byCat[n]).concat(names.filter(n => !view.categoryOrder.includes(n) && n !== "Other").sort()).concat(byCat["Other"] ? ["Other"] : []);
        let extra = 0;
        return {
            id: "hyprland",
            title: "Hyprland",
            sections: ordered.map(n => ({
                        title: n,
                        color: view.categoryColor[n] ?? view.extraColors[extra++ % view.extraColors.length],
                        rows: byCat[n]
                    }))
        };
    }

    // One entry per source; add the launcher-views page here later.
    // Further pages (same shape as buildHyprPage() returns), e.g. the keys of
    // the launcher views; set by whoever hosts the view.
    property var extraPages: []
    readonly property var pages: view.loaded && !view.failed ? [view.buildHyprPage()].concat(view.extraPages) : []
    property int pageIndex: 0
    readonly property var page: view.pages.length > 0 ? view.pages[Math.min(view.pageIndex, view.pages.length - 1)] : null

    // ---- filter ----
    property string filter: ""
    property bool searching: false

    function rowKeysText(r) {
        return r.alts.map(a => a.join(" ")).join(" ").toLowerCase();
    }

    readonly property var shownSections: {
        if (!view.page)
            return [];
        const q = view.filter.trim().toLowerCase();
        if (q === "")
            return view.page.sections;
        const words = q.split(/\s+/);
        const out = [];
        for (const s of view.page.sections) {
            const rows = s.rows.filter(r => {
                const hay = (r.text + " " + view.rowKeysText(r) + " " + s.title).toLowerCase();
                return words.every(w => hay.indexOf(w) >= 0);
            });
            if (rows.length > 0)
                out.push({ title: s.title, color: s.color, rows: rows });
        }
        return out;
    }
    readonly property int shownCount: view.shownSections.reduce((n, s) => n + s.rows.length, 0)

    // ---- layout: flow sections into two columns, continue on further screens ----
    readonly property int rowH: 32
    readonly property int headerH: 38
    readonly property int sectionGap: 14
    readonly property int topH: view.pages.length > 1 ? 112 : 70
    readonly property int availH: view.height - view.topH
    readonly property int colGap: 60
    readonly property int colW: Math.floor((view.width - view.colGap) / 2)

    function flow(sections, limit, allowSplit) {
        // returns { screens: [[col0, col1], ...], ok } ; items are
        // { header: true, title, color, cont } or { row }
        const screens = [];
        let cur = [[], []], c = 0, used = 0;
        let ok = true;
        const next = () => {
            c++;
            used = 0;
            if (c > 1) {
                screens.push(cur);
                cur = [[], []];
                c = 0;
            }
        };
        for (const s of sections) {
            const need = view.headerH + Math.min(2, s.rows.length) * view.rowH;
            if (used > 0 && used + need > limit)
                next();
            if (!allowSplit && used + view.headerH + s.rows.length * view.rowH > limit && used > 0)
                ok = false;
            cur[c].push({ header: true, title: s.title, color: s.color, cont: false });
            used += view.headerH;
            for (const r of s.rows) {
                if (used + view.rowH > limit) {
                    if (!allowSplit)
                        ok = false;
                    next();
                    cur[c].push({ header: true, title: s.title, color: s.color, cont: true });
                    used += view.headerH;
                }
                cur[c].push({ header: false, row: r, color: s.color, title: s.title });
                used += view.rowH;
            }
            used += view.sectionGap;
        }
        if (cur[0].length > 0 || cur[1].length > 0)
            screens.push(cur);
        return { screens: screens, ok: ok };
    }

    readonly property var screens: {
        const secs = view.shownSections;
        if (secs.length === 0)
            return [];
        const total = secs.reduce((n, s) => n + view.headerH + s.rows.length * view.rowH + view.sectionGap, 0);
        // Prefer balanced columns without splitting a section; otherwise fill
        // the columns to the full height and split.
        for (let L = Math.ceil(total / 2); L <= view.availH; L += view.rowH) {
            const f = view.flow(secs, L, false);
            if (f.ok && f.screens.length === 1)
                return f.screens;
        }
        const full = view.flow(secs, view.availH, true).screens;
        if (full.length > 1)
            full[full.length - 1] = view.balance(full[full.length - 1]);
        return full;
    }

    // Splits the items of the last screen evenly over the two columns (the
    // flow fills the first column completely, which leaves the last screen
    // lopsided). A section cut in the middle gets a "(continued)" header.
    function balance(screen) {
        const items = screen[0].concat(screen[1]);
        const h = it => it.header ? view.headerH : view.rowH;
        const total = items.reduce((n, it) => n + h(it), 0);
        let cum = 0, cut = items.length;
        for (let i = 0; i < items.length; i++) {
            cum += h(items[i]);
            if (cum >= total / 2) {
                cut = i + 1;
                break;
            }
        }
        // never end a column on a header, and keep something in both columns
        if (cut > 0 && cut < items.length && items[cut - 1].header)
            cut--;
        if (cut <= 0 || cut >= items.length)
            return screen;
        const second = items.slice(cut);
        if (!second[0].header)
            second.unshift({ header: true, title: items[cut].title, color: items[cut].color, cont: true });
        return [items.slice(0, cut), second];
    }

    property int screenIndex: 0
    readonly property int screenCount: view.screens.length
    onScreenCountChanged: view.screenIndex = Math.min(view.screenIndex, Math.max(0, view.screenCount - 1))
    onFilterChanged: view.screenIndex = 0

    function page_(delta) {
        view.screenIndex = Math.max(0, Math.min(view.screenCount - 1, view.screenIndex + delta));
    }

    // ---- keys ----
    function handleEscape() {
        if (view.searching) {
            view.searching = false;
            return true;
        }
        if (view.filter !== "") {
            view.filter = "";
            return true;
        }
        return false;
    }

    readonly property var hints: {
        if (view.searching)
            return [[{ keys: ["↵"], text: "keep filter" }, { keys: ["Esc"], text: "stop searching" }, { keys: ["Ctrl", "U"], text: "clear" }]];
        const row = [{ keys: ["/"], text: "filter" }, { keys: ["j", "k"], text: "next screen", ghost: view.screenCount < 2 }];
        if (view.pages.length > 1)
            row.push({ keys: ["Tab"], text: "page" });
        row.push({ keys: ["q"], text: "close" });
        return [row];
    }

    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (view.searching) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                view.searching = false;
            else if (event.key === Qt.Key_Backspace)
                view.filter = view.filter.slice(0, -1);
            else if (ctrl && event.key === Qt.Key_U)
                view.filter = "";
            else if (!ctrl && event.text.length === 1 && event.text >= " ")
                view.filter += event.text;
            return true;
        }
        switch (event.key) {
        case Qt.Key_Slash:
            view.searching = true;
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
        case Qt.Key_Right:
        case Qt.Key_PageDown:
        case Qt.Key_Space:
            view.page_(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
        case Qt.Key_Left:
        case Qt.Key_PageUp:
            view.page_(-1);
            return true;
        case Qt.Key_G:
            view.screenIndex = 0;
            return true;
        case Qt.Key_Tab:
            if (view.pages.length > 1) {
                view.pageIndex = (view.pageIndex + 1) % view.pages.length;
                view.screenIndex = 0;
            }
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    // ---- rendering helpers ----
    function esc(t) {
        return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function highlight(text) {
        const q = view.filter.trim().toLowerCase();
        if (q === "")
            return view.esc(text);
        let out = view.esc(text);
        // highlight the first matching word occurrence of each filter word
        for (const w of q.split(/\s+/)) {
            const i = text.toLowerCase().indexOf(w);
            if (i < 0)
                continue;
            const a = view.esc(text.slice(0, i)), m = view.esc(text.slice(i, i + w.length)), z = view.esc(text.slice(i + w.length));
            out = a + "<font color=\"" + Theme.yellow + "\"><b>" + m + "</b></font>" + z;
            break;
        }
        return out;
    }

    component KeyCap: Rectangle {
        id: cap

        property string label: ""

        width: capText.implicitWidth + 20
        height: 28
        radius: 7
        color: Theme.surface2
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Text {
            id: capText

            anchors.centerIn: parent
            text: cap.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            renderType: view.textRender
        }
    }

    // ---- header: title, page tabs, filter field ----
    Text {
        x: 0
        y: 0
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Keybindings"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    Rectangle {
        id: field

        x: 270
        y: 4
        width: view.width - 270
        height: 44
        radius: 14
        color: Theme.base
        border.width: view.searching ? 2 : 1
        border.color: view.searching ? Theme.blue : Theme.surface2

        Text {
            x: 16
            width: 24
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: ""
            color: view.searching ? Theme.blue : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            renderType: view.textRender
        }

        Text {
            x: 50
            width: parent.width - 230
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: view.filter !== "" ? view.filter + (view.searching ? "▏" : "") : (view.searching ? "▏" : "Press / to filter")
            color: view.filter !== "" ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            elide: Text.ElideLeft
            renderType: view.textRender
        }

        // fixed slot: count, and the screen number when there is more than one
        Text {
            x: parent.width - 200
            width: 184
            height: parent.height
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: view.loaded && !view.failed ? view.shownCount + (view.shownCount === 1 ? " shortcut" : " shortcuts") + (view.screenCount > 1 ? "  ·  " + (view.screenIndex + 1) + "/" + view.screenCount : "") : ""
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }
    }

    // page tabs: only when there is more than one source
    Row {
        visible: view.pages.length > 1
        x: 0
        y: 56
        height: 30
        spacing: 8

        Repeater {
            model: view.pages

            Rectangle {
                required property var modelData
                required property int index

                width: tabText.implicitWidth + 24
                height: 30
                radius: 15
                color: index === view.pageIndex ? Theme.surface2 : "transparent"
                border.color: Theme.surface2

                Text {
                    id: tabText

                    anchors.centerIn: parent
                    text: modelData.title
                    color: index === view.pageIndex ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: view.textRender
                }
            }
        }
    }

    // ---- the two columns ----
    Item {
        id: sheet

        x: 0
        y: view.topH
        width: view.width
        height: view.availH
        clip: true

        Repeater {
            model: view.screens.length > 0 ? view.screens[Math.min(view.screenIndex, view.screens.length - 1)] : []

            Column {
                id: col

                required property var modelData
                required property int index

                x: index * (view.colW + view.colGap)
                width: view.colW
                spacing: 0

                Repeater {
                    model: col.modelData

                    Item {
                        id: item

                        required property var modelData

                        width: view.colW
                        height: modelData.header ? view.headerH : view.rowH

                        // section header
                        Item {
                            visible: item.modelData.header
                            anchors.fill: parent

                            Text {
                                x: 4
                                y: 0
                                height: 28
                                verticalAlignment: Text.AlignVCenter
                                text: item.modelData.header ? item.modelData.title + (item.modelData.cont ? "  (continued)" : "") : ""
                                color: item.modelData.color ?? Theme.blue
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 3
                                font.bold: true
                                renderType: view.textRender
                            }

                            Rectangle {
                                x: 0
                                y: 30
                                width: parent.width
                                height: 1
                                color: Theme.surface2
                            }
                        }

                        // shortcut row: key caps left, description at a fixed x
                        Item {
                            visible: !item.modelData.header
                            anchors.fill: parent

                            Row {
                                x: 4
                                y: 2
                                spacing: 8

                                Repeater {
                                    model: item.modelData.header ? [] : item.modelData.row.alts

                                    Row {
                                        id: altRow

                                        required property var modelData
                                        required property int index

                                        spacing: 8

                                        Text {
                                            visible: altRow.index > 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "/"
                                            color: Theme.subtext1
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize + 2
                                            renderType: view.textRender
                                        }

                                        Row {
                                            spacing: 6

                                            Repeater {
                                                model: altRow.modelData

                                                Row {
                                                    id: capRow

                                                    required property string modelData
                                                    required property int index

                                                    spacing: 6

                                                    Text {
                                                        visible: capRow.index > 0
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "+"
                                                        color: Theme.subtext1
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSize
                                                        renderType: view.textRender
                                                    }

                                                    KeyCap {
                                                        label: capRow.modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                x: 380
                                width: parent.width - 380
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                textFormat: Text.StyledText
                                text: item.modelData.header ? "" : view.highlight(item.modelData.row.text)
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 2
                                elide: Text.ElideRight
                                renderType: view.textRender
                            }
                        }
                    }
                }
            }
        }
    }

    EmptyState {
        visible: view.loaded && (view.failed || view.shownCount === 0)
        x: 0
        y: view.topH
        width: view.width
        height: view.availH
        illustration: "keys.svg"
        title: view.failed ? "Couldn't read the keybindings" : "No keybindings match"
        hint: view.failed ? "hyprctl binds -j failed" : "Esc clears the filter"
        textRender: view.textRender
    }
}
