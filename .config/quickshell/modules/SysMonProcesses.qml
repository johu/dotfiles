import QtQuick
import Quickshell
import "SysMonFormat.js" as Fmt

// Processes page of the system view: a table grouped by application (one row
// per app with a count; Enter expands it), sortable, filterable, with a kill
// action (own processes only, after a confirmation). cpu is a percentage of
// ONE core (like top), memory is resident memory (a group sums its members,
// so shared pages count more than once).
Item {
    id: page

    property var col
    property int textRender: Text.NativeRendering

    property string sortKey: "cpu"
    property bool sortDesc: true
    property string filter: ""
    property bool searching: false
    property bool grouped: true
    property bool mineOnly: false
    property var expanded: ({})
    property string selectedKey: ""
    property int lastIndex: 0
    property var pendingKill: null
    property string toastText: ""

    readonly property var columns: [
        { id: "name", title: "Name" },
        { id: "pid", title: "PID" },
        { id: "user", title: "User" },
        { id: "cpu", title: "CPU" },
        { id: "mem", title: "Memory" },
        { id: "threads", title: "Threads" },
        { id: "io", title: "Disk" }
    ]

    // column geometry (fractions of the page width)
    readonly property var colX: ({ name: 0.045, pid: 0.36, user: 0.445, cpu: 0.545, mem: 0.70, threads: 0.80, io: 0.90 })
    readonly property var colW: ({ name: 0.31, pid: 0.065, user: 0.09, cpu: 0.15, mem: 0.09, threads: 0.07, io: 0.10 })

    function sortValue(r, k) {
        switch (k) {
        case "name":
            return r.name.toLowerCase();
        case "user":
            return r.user.toLowerCase();
        case "pid":
            return r.kind === "group" ? -1 : r.pid;
        }
        return r[k];
    }

    function compare(a, b) {
        const va = page.sortValue(a, page.sortKey), vb = page.sortValue(b, page.sortKey);
        const c = typeof va === "string" ? va.localeCompare(vb) : va - vb;
        return page.sortDesc ? -c : c;
    }

    function procRow(p, depth) {
        return { key: "p:" + p.pid, kind: depth > 0 ? "child" : "proc", depth: depth, name: p.exe || p.name, label: p.exe && p.exe !== p.name ? p.exe : p.name, pid: p.pid, user: p.user, cpu: p.cpu, mem: p.mem, threads: p.threads, io: p.io, pids: [p.pid], own: p.uid === page.col.s.uid, cmd: p.cmd, iconKey: p.exe || p.name };
    }

    function buildRows(procs, filter, grouped, mineOnly, sortKey, sortDesc, expanded) {
        const needle = filter.toLowerCase();
        const uid = page.col.s.uid;
        const list = procs.filter(p => !p.kernel && (!mineOnly || p.uid === uid) && (needle === "" || (p.name + " " + p.exe + " " + p.user + " " + p.pid + " " + p.cmd).toLowerCase().includes(needle)));
        if (!grouped)
            return list.map(p => page.procRow(p, 0)).sort((a, b) => page.compare(a, b));
        const groups = {};
        for (const p of list) {
            const k = p.exe || p.name;
            (groups[k] = groups[k] ?? []).push(p);
        }
        const rows = [];
        for (const k of Object.keys(groups)) {
            const m = groups[k];
            if (m.length === 1) {
                rows.push(page.procRow(m[0], 0));
                continue;
            }
            const users = Array.from(new Set(m.map(p => p.user)));
            rows.push({ key: "g:" + k, kind: "group", depth: 0, name: k, label: k + "  (" + m.length + ")", pid: m.length, user: users.length === 1 ? users[0] : "several", cpu: m.reduce((a, p) => a + p.cpu, 0), mem: m.reduce((a, p) => a + p.mem, 0), threads: m.reduce((a, p) => a + p.threads, 0), io: m.reduce((a, p) => a + p.io, 0), pids: m.map(p => p.pid), own: m.every(p => p.uid === uid), members: m, iconKey: k });
        }
        rows.sort((a, b) => page.compare(a, b));
        const out = [];
        for (const r of rows) {
            out.push(r);
            if (r.kind === "group" && expanded[r.key])
                out.push(...r.members.map(p => page.procRow(p, 1)).sort((a, b) => page.compare(a, b)));
        }
        return out;
    }

    readonly property var rows: page.col ? page.buildRows(page.col.procs, page.filter, page.grouped, page.mineOnly, page.sortKey, page.sortDesc, page.expanded) : []
    readonly property int selectedIndex: page.rows.findIndex(r => r.key === page.selectedKey)
    readonly property var selected: page.selectedIndex >= 0 ? page.rows[page.selectedIndex] : null

    onSelectedIndexChanged: if (page.selectedIndex >= 0)
        page.lastIndex = page.selectedIndex

    onRowsChanged: {
        if (page.selected || page.rows.length === 0)
            return;
        // The row vanished (process ended, filtered out): keep the position.
        page.selectedKey = page.rows[Math.min(page.lastIndex, page.rows.length - 1)].key;
    }

    function select(i) {
        if (page.rows.length > 0)
            page.selectedKey = page.rows[Math.max(0, Math.min(page.rows.length - 1, i))].key;
    }

    // From the performance page: sort by cpu or memory, descending.
    function sortBy(k) {
        page.sortKey = k;
        page.sortDesc = true;
        page.select(0);
    }

    function toast(t) {
        page.toastText = t;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer

        interval: 2500
        onTriggered: page.toastText = ""
    }

    function askKill() {
        const r = page.selected;
        if (!r)
            return;
        if (!r.own) {
            page.toast("Not your process (owned by " + r.user + ")");
            return;
        }
        page.pendingKill = { label: r.kind === "group" ? r.name + " (" + r.pids.length + " processes)" : r.label + " (PID " + r.pid + ")", pids: r.pids };
    }

    function sendKill(signal) {
        const k = page.pendingKill;
        page.pendingKill = null;
        if (!k)
            return;
        Quickshell.execDetached(["kill", "-" + signal].concat(k.pids.map(String)));
        page.toast((signal === "KILL" ? "Killed " : "Terminated ") + k.label);
    }

    function toggleExpand() {
        const r = page.selected;
        if (!r || r.kind !== "group")
            return;
        const e = Object.assign({}, page.expanded);
        if (e[r.key])
            delete e[r.key];
        else
            e[r.key] = true;
        page.expanded = e;
    }

    function handleEscape() {
        if (page.pendingKill) {
            page.pendingKill = null;
            return true;
        }
        if (page.searching) {
            page.searching = false;
            return true;
        }
        if (page.filter !== "") {
            page.filter = "";
            return true;
        }
        return false;
    }

    readonly property var hints: {
        if (page.pendingKill)
            return [[{ keys: ["y"], text: "terminate (SIGTERM)" }, { keys: ["k"], text: "kill (SIGKILL)" }, { keys: ["Esc"], text: "cancel" }]];
        if (page.searching)
            return [[{ keys: ["↵"], text: "keep filter" }, { keys: ["Esc"], text: "stop searching" }, { keys: ["Ctrl", "U"], text: "clear" }]];
        return [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["h", "l"], text: "sort column" },
                { keys: ["s"], text: "reverse" },
                { keys: ["g"], text: page.grouped ? "ungroup" : "group", slot: "ungroup" },
                { keys: ["m"], text: page.mineOnly ? "all users" : "mine only", slot: "all users" },
                { keys: ["/"], text: "filter" },
                { keys: ["↵"], text: "expand", ghost: !page.selected || page.selected.kind !== "group" },
                { keys: ["K"], text: "kill" },
                { keys: ["Tab"], text: "performance" },
                { keys: ["q"], text: "close" }
            ]];
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (page.pendingKill) {
            if (event.key === Qt.Key_Y)
                page.sendKill("TERM");
            else if (event.key === Qt.Key_K)
                page.sendKill("KILL");
            else
                page.pendingKill = null;
            return true;
        }
        if (page.searching) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                page.searching = false;
            else if (event.key === Qt.Key_Backspace)
                page.filter = page.filter.slice(0, -1);
            else if (ctrl && event.key === Qt.Key_U)
                page.filter = "";
            else if (event.key === Qt.Key_Down)
                page.select(page.selectedIndex + 1);
            else if (event.key === Qt.Key_Up)
                page.select(page.selectedIndex - 1);
            else if (!ctrl && event.text.length === 1 && event.text >= " ")
                page.filter += event.text;
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.select(page.selectedIndex + 1);
            return true;
        case Qt.Key_K:
            if (shift)
                page.askKill();
            else
                page.select(page.selectedIndex - 1);
            return true;
        case Qt.Key_Up:
            page.select(page.selectedIndex - 1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                page.select(page.selectedIndex + 10);
            return true;
        case Qt.Key_U:
            if (ctrl)
                page.select(page.selectedIndex - 10);
            return true;
        case Qt.Key_Home:
            page.select(0);
            return true;
        case Qt.Key_End:
            page.select(page.rows.length - 1);
            return true;
        case Qt.Key_G:
            if (shift)
                page.select(page.rows.length - 1);
            else {
                page.grouped = !page.grouped;
            }
            return true;
        case Qt.Key_H:
        case Qt.Key_Left:
            page.moveSortColumn(-1);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            page.moveSortColumn(1);
            return true;
        case Qt.Key_S:
            page.sortDesc = !page.sortDesc;
            return true;
        case Qt.Key_M:
            page.mineOnly = !page.mineOnly;
            return true;
        case Qt.Key_Slash:
            page.searching = true;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            page.toggleExpand();
            return true;
        }
        return false;
    }

    function moveSortColumn(delta) {
        const ids = page.columns.map(c => c.id);
        const i = ids.indexOf(page.sortKey);
        const next = ids[Math.max(0, Math.min(ids.length - 1, i + delta))];
        if (next !== page.sortKey) {
            page.sortKey = next;
            page.sortDesc = next === "cpu" || next === "mem" || next === "threads" || next === "io";
        }
    }

    // ---- top bar: filter field, toggles, count ----
    Rectangle {
        x: 0
        y: 0
        width: 560
        height: 44
        radius: 12
        color: Theme.surface2
        border.width: page.searching ? 2 : 0
        border.color: Theme.blue

        Text {
            x: 16
            width: 24
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: "\uf002"
            color: page.searching ? Theme.blue : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            renderType: page.textRender
        }

        Text {
            x: 50
            width: parent.width - 60
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: page.filter !== "" ? page.filter + (page.searching ? "▏" : "") : (page.searching ? "▏" : "Press / to filter")
            color: page.filter !== "" ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            elide: Text.ElideLeft
            renderType: page.textRender
        }
    }

    Row {
        x: 590
        y: 0
        spacing: 12

        Repeater {
            model: [{ label: "grouped by app", on: page.grouped }, { label: "mine only", on: page.mineOnly }]

            Rectangle {
                required property var modelData

                width: 200
                height: 44
                radius: 12
                color: modelData.on ? Theme.surface2 : "transparent"
                border.width: 1
                border.color: Theme.surface2

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: modelData.on ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    renderType: page.textRender
                }
            }
        }
    }

    Text {
        x: page.width - width
        y: 0
        width: 700
        height: 44
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: page.toastText !== "" ? page.toastText : page.rows.length + " rows  ·  CPU: 100 % = one core"
        color: page.toastText !== "" ? Theme.yellow : Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
        elide: Text.ElideLeft
        renderType: page.textRender
    }

    // ---- header ----
    Rectangle {
        x: 0
        y: 60
        width: page.width
        height: 40
        radius: 10
        color: Theme.surface1

        Repeater {
            model: page.columns

            Text {
                required property var modelData

                readonly property bool rightAligned: modelData.id !== "name" && modelData.id !== "user"

                x: page.width * page.colX[modelData.id]
                width: page.width * page.colW[modelData.id]
                height: parent.height
                horizontalAlignment: rightAligned ? Text.AlignRight : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                text: modelData.title + (page.sortKey === modelData.id ? (page.sortDesc ? " ▼" : " ▲") : "")
                color: page.sortKey === modelData.id ? Theme.yellow : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                renderType: page.textRender

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (page.sortKey === modelData.id)
                            page.sortDesc = !page.sortDesc;
                        else {
                            page.sortKey = modelData.id;
                            page.sortDesc = modelData.id !== "name" && modelData.id !== "user" && modelData.id !== "pid";
                        }
                    }
                }
            }
        }
    }

    // ---- rows ----
    ListView {
        id: list

        x: 0
        y: 108
        width: page.width
        height: page.height - 108
        clip: true
        spacing: 2
        model: page.rows
        currentIndex: page.selectedIndex
        onCurrentIndexChanged: if (list.currentIndex >= 0)
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool sel: modelData.key === page.selectedKey
            readonly property string iconName: AppIconResolver.iconNameForBinary(modelData.iconKey ?? "")

            width: list.width
            height: 46
            radius: 10
            color: row.sel ? Theme.surface2 : "transparent"

            // expander / indent + icon
            Text {
                x: modelData.depth * 28 + 8
                width: 24
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                visible: modelData.kind === "group"
                text: page.expanded[modelData.key] ? "\uf107" : "\uf105"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 4
                renderType: page.textRender
            }

            ResolvedIcon {
                x: modelData.depth * 28 + 40
                y: (parent.height - height) / 2
                size: 28
                visible: row.iconName !== ""
                iconSource: row.iconName !== "" ? "image://icon/" + row.iconName : ""
            }

            Text {
                x: modelData.depth * 28 + 78
                width: page.width * page.colW.name - modelData.depth * 28 - 40
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: modelData.label
                color: row.sel ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                font.bold: row.sel || modelData.kind === "group"
                elide: Text.ElideRight
                renderType: page.textRender
            }

            Text {
                x: page.width * page.colX.pid
                width: page.width * page.colW.pid
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: modelData.kind === "group" ? "×" + modelData.pid : String(modelData.pid)
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                renderType: page.textRender
            }

            Text {
                x: page.width * page.colX.user
                width: page.width * page.colW.user
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: modelData.user
                color: modelData.own ? Theme.subtext1 : Theme.maroon
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                elide: Text.ElideRight
                renderType: page.textRender
            }

            // CPU: bar (capped at one core) and the value
            Rectangle {
                x: page.width * page.colX.cpu
                y: 17
                width: page.width * (page.colW.cpu - 0.07)
                height: 12
                radius: 6
                color: Theme.surface1

                Rectangle {
                    width: parent.width * Math.min(100, modelData.cpu) / 100
                    height: parent.height
                    radius: 6
                    color: modelData.cpu > 80 ? Theme.red : (modelData.cpu > 40 ? Theme.yellow : Theme.blue)
                }
            }

            Text {
                x: page.width * (page.colX.cpu + page.colW.cpu - 0.07)
                width: page.width * 0.07
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: modelData.cpu.toFixed(1)
                color: row.sel ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                renderType: page.textRender
            }

            Text {
                x: page.width * page.colX.mem
                width: page.width * page.colW.mem
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: Fmt.bytes(modelData.mem)
                color: row.sel ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                renderType: page.textRender
            }

            Text {
                x: page.width * page.colX.threads
                width: page.width * page.colW.threads
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: String(modelData.threads)
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                renderType: page.textRender
            }

            Text {
                x: page.width * page.colX.io
                width: page.width * page.colW.io
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: modelData.io > 0 ? Fmt.rate(modelData.io) : "–"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                renderType: page.textRender
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.selectedKey = modelData.key
                onDoubleClicked: {
                    page.selectedKey = modelData.key;
                    page.toggleExpand();
                }
            }
        }
    }

    // ---- kill confirmation ----
    Rectangle {
        visible: page.pendingKill !== null
        anchors.fill: parent
        color: Theme.surface1
        opacity: 0.85
    }

    Rectangle {
        visible: page.pendingKill !== null
        width: 1000
        height: 130
        x: (page.width - width) / 2
        y: (page.height - height) / 2
        radius: 18
        color: Theme.mantle
        border.width: 2
        border.color: Theme.red

        Text {
            x: 24
            y: 22
            width: parent.width - 48
            height: 40
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: page.pendingKill ? "Terminate " + page.pendingKill.label + "?" : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 8
            font.bold: true
            elide: Text.ElideRight
            renderType: page.textRender
        }

        Text {
            x: 24
            y: 76
            width: parent.width - 48
            height: 32
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "y  terminate (SIGTERM)        k  kill (SIGKILL)        any other key  cancel"
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
            renderType: page.textRender
        }
    }
}
