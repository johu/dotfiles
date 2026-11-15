import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard view of the launcher: the cliphist history (plus pinned snippets)
// as a searchable list on the left and a full preview of the selected entry on
// the right (text, image, color, link). Enter copies the entry and closes the
// launcher; the target window still gets a manual paste (no wtype / ydotool
// here). Same contract as the other views; fixed geometry.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1700
    readonly property int preferredHeight: 1000

    readonly property string monoFont: "JetBrainsMono Nerd Font Mono"
    readonly property string homeDir: Quickshell.env("HOME")

    // ---- data ----
    property var entries: []      // cliphist: { key, id, preview, kind, label }
    property var pins: []         // pinned texts (strings), newest first
    property bool loaded: false
    property string filter: ""
    property bool searching: false
    property bool confirmClear: false
    property string selectedKey: ""
    property string toastText: ""

    function kindOf(preview) {
        const t = preview.trim();
        if (/^https?:\/\/\S+$/.test(t))
            return "url";
        if (/^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t) || /^rgba?\([^)]*\)$/.test(t))
            return "color";
        if (/^(\/|~\/)[^\s]*$/.test(t))
            return "path";
        return "text";
    }

    // One line for the list: images get a readable label instead of the raw
    // "[[ binary data ... ]]" cliphist writes.
    function parseEntry(id, preview) {
        const img = preview.match(/^\[\[ binary data ([^ ]+ [^ ]+) (\w+) (\d+x\d+) \]\]$/);
        if (img) {
            const ext = img[2].toLowerCase();
            if (["png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff"].includes(ext))
                return { key: "c" + id, id: id, preview: preview, kind: "image", ext: ext, label: "Image  ·  " + img[1] + "  ·  " + ext + " " + img[3] };
            return { key: "c" + id, id: id, preview: preview, kind: "binary", label: preview.replace(/^\[\[ | \]\]$/g, "") };
        }
        return { key: "c" + id, id: id, preview: preview, kind: view.kindOf(preview), label: preview };
    }

    function pinRow(text, index) {
        const first = text.split("\n").find(l => l.trim() !== "") ?? "";
        return { key: "p" + index, pinned: true, pinIndex: index, text: text, preview: first.trim(), kind: view.kindOf(first), label: first.trim() };
    }

    readonly property var rows: {
        const needle = view.filter.toLowerCase();
        const pinned = view.pins.map((t, i) => view.pinRow(t, i)).filter(r => needle === "" || r.text.toLowerCase().includes(needle));
        const rest = needle === "" ? view.entries : view.entries.filter(e => e.preview.toLowerCase().includes(needle));
        return pinned.concat(rest);
    }

    readonly property int selectedIndex: view.rows.findIndex(r => r.key === view.selectedKey)
    readonly property var selected: view.selectedIndex >= 0 ? view.rows[view.selectedIndex] : null
    property int lastIndex: 0

    onSelectedIndexChanged: if (view.selectedIndex >= 0)
        view.lastIndex = view.selectedIndex

    onRowsChanged: {
        if (view.selected)
            return;
        // The selection vanished (deleted, filtered out): keep the position.
        view.selectedKey = view.rows.length > 0 ? view.rows[Math.min(view.lastIndex, view.rows.length - 1)].key : "";
    }

    function select(i) {
        if (view.rows.length > 0)
            view.selectedKey = view.rows[Math.max(0, Math.min(view.rows.length - 1, i))].key;
    }

    function reload() {
        listProc.running = true;
    }

    Component.onCompleted: view.reload()

    // The image preview leaves a decoded copy of the clipboard image in the
    // cache; do not keep it around once the view is closed.
    Component.onDestruction: Quickshell.execDetached(["sh", "-c", "rm -f \"$HOME\"/.cache/quickshell/clip-preview.*"])

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const m = line.match(/^(\d+)\t(.*)$/);
                    if (m)
                        out.push(view.parseEntry(m[1], m[2]));
                }
                view.entries = out;
                view.loaded = true;
            }
        }
    }

    // ---- pinned snippets (text only), kept across sessions ----
    FileView {
        id: pinFile

        path: Quickshell.env("HOME") + "/.local/state/quickshell/clipboard-pins.json"
        printErrors: false
        onLoaded: view.pins = view.strings(pinAdapter.pins)

        JsonAdapter {
            id: pinAdapter

            property var pins: []
        }
    }

    // JsonAdapter lists are not real arrays; normalise through JSON.
    function strings(v) {
        if (v === null || v === undefined)
            return [];
        const a = JSON.parse(JSON.stringify(v));
        return Array.isArray(a) ? a.filter(x => typeof x === "string" && x !== "") : [];
    }

    function savePins(list) {
        view.pins = list;
        pinAdapter.pins = list;
        pinFile.writeAdapter();
    }

    // ---- preview of the selected entry ----
    property string previewText: ""
    property string previewImage: ""
    property bool previewBusy: false
    property string _wantId: ""
    property string _gotId: ""

    readonly property var wantEntry: view.selected && !view.selected.pinned ? view.selected : null

    onWantEntryChanged: previewTimer.restart()

    Timer {
        id: previewTimer

        interval: 90
        onTriggered: view.startPreview()
    }

    function startPreview() {
        const e = view.wantEntry;
        view.previewImage = "";
        if (!e || e.kind === "binary") {
            view.previewText = "";
            view._wantId = "";
            return;
        }
        view._wantId = e.id;
        if (previewProc.running || imageProc.running)
            return; // picked up again when the running one ends
        view.runPreview(e);
    }

    function runPreview(e) {
        view._gotId = e.id;
        view.previewText = "";
        view.previewBusy = true;
        if (e.kind === "image") {
            imageProc.entry = e;
            imageProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s\\t\\n' \"$1\" | cliphist decode > \"$2\"", "sh", e.id, view.homeDir + "/.cache/quickshell/clip-preview." + e.ext];
            imageProc.running = true;
        } else {
            previewProc.command = ["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist decode | head -c 40000", "sh", e.id];
            previewProc.running = true;
        }
    }

    function previewDone() {
        view.previewBusy = false;
        // The selection moved while this one was running.
        if (view._wantId !== "" && view._wantId !== view._gotId && view.wantEntry)
            view.runPreview(view.wantEntry);
    }

    Process {
        id: previewProc

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (view._gotId === view._wantId)
                    view.previewText = this.text;
                view.previewDone();
            }
        }
    }

    Process {
        id: imageProc

        property var entry: null

        onExited: {
            if (view._gotId === view._wantId && entry)
                view.previewImage = "file://" + view.homeDir + "/.cache/quickshell/clip-preview." + entry.ext + "?" + entry.id;
            view.previewDone();
        }
    }

    readonly property string fullText: view.selected ? (view.selected.pinned ? view.selected.text : view.previewText) : ""
    readonly property string kind: view.selected ? view.selected.kind : ""

    readonly property string metaText: {
        if (!view.selected)
            return "";
        if (view.kind === "image")
            return view.selected.label.replace(/^Image\s+·\s+/, "");
        if (view.kind === "binary")
            return view.selected.label;
        const t = view.fullText;
        const lines = t === "" ? 0 : t.split("\n").length;
        const more = !view.selected.pinned && t.length >= 40000 ? "+" : "";
        return t.length + more + " characters  ·  " + lines + (lines === 1 ? " line" : " lines");
    }

    // ---- actions ----
    function toast(text) {
        view.toastText = text;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer

        interval: 2200
        onTriggered: view.toastText = ""
    }

    // Copy must finish before the view (and this process) goes away.
    property bool closeAfterCopy: false

    // The id goes in through a shell pipe, not Process stdin: a Process keeps
    // stdin open, and cliphist (delete in particular) waits for end of input.
    Process {
        id: copyProc

        onExited: view.copyDone()
    }

    Process {
        id: copyPinProc

        onExited: view.copyDone()
    }

    function copyDone() {
        if (view.closeAfterCopy)
            view.closeRequested();
        else
            view.toast("Copied");
    }

    function copySelected(close) {
        const r = view.selected;
        if (!r || r.kind === "binary")
            return;
        view.closeAfterCopy = close;
        if (r.pinned) {
            copyPinProc.command = ["wl-copy", "--", r.text];
            copyPinProc.running = true;
        } else {
            copyProc.command = ["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist decode | wl-copy", "sh", r.id];
            copyProc.running = true;
        }
    }

    Process {
        id: deleteProc
    }

    // Before a row disappears: move the selection to the entry that follows
    // (or the one before when it was the last) and keep the scroll position;
    // replacing the list's model otherwise resets it to the top.
    function keepPlaceAfterRemoval() {
        const i = view.selectedIndex;
        const next = view.rows[i + 1] ?? view.rows[i - 1];
        const y = list.contentY;
        if (next)
            view.selectedKey = next.key;
        Qt.callLater(() => list.contentY = Math.min(y, Math.max(0, list.contentHeight - list.height)));
    }

    function deleteSelected() {
        const r = view.selected;
        if (!r)
            return;
        view.keepPlaceAfterRemoval();
        if (r.pinned) {
            view.savePins(view.pins.filter((_, i) => i !== r.pinIndex));
            view.toast("Unpinned");
            return;
        }
        deleteProc.command = ["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", r.id];
        deleteProc.running = true;
        view.entries = view.entries.filter(e => e.id !== r.id);
        view.toast("Deleted");
    }

    function togglePin() {
        const r = view.selected;
        if (!r)
            return;
        if (r.pinned) {
            view.keepPlaceAfterRemoval();
            view.savePins(view.pins.filter((_, i) => i !== r.pinIndex));
            view.toast("Unpinned");
            return;
        }
        if (r.kind === "image" || r.kind === "binary") {
            view.toast("Only text can be pinned");
            return;
        }
        // The full text, not the one-line list preview.
        const text = view.previewText !== "" ? view.previewText : r.preview;
        if (view.pins.includes(text)) {
            view.toast("Already pinned");
            return;
        }
        view.savePins([text].concat(view.pins));
        view.toast("Pinned");
    }

    function openLink() {
        const t = view.fullText.trim();
        if (view.kind === "url" && /^https?:\/\/\S+$/.test(t)) {
            Quickshell.execDetached(["xdg-open", t]);
            view.closeRequested();
        }
    }

    Process {
        id: wipeProc

        command: ["cliphist", "wipe"]
        onExited: {
            view.reload();
            view.toast("History cleared");
        }
    }

    // ---- keys ----
    function handleEscape() {
        if (view.confirmClear) {
            view.confirmClear = false;
            return true;
        }
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
        if (view.confirmClear)
            return [[{ keys: ["y"], text: "clear the whole history" }, { keys: ["Esc"], text: "cancel" }]];
        if (view.searching)
            return [[{ keys: ["↵"], text: "keep filter" }, { keys: ["Esc"], text: "stop searching" }, { keys: ["Ctrl", "U"], text: "clear" }]];
        if (view.loaded && view.rows.length === 0 && view.filter === "")
            return [[{ keys: ["q"], text: "close" }]];
        const pinned = view.selected ? view.selected.pinned === true : false;
        return [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["↵"], text: "copy & close" },
                { keys: ["y"], text: "copy" },
                { keys: ["p"], text: pinned ? "unpin" : "pin", slot: "unpin" },
                { keys: ["d"], text: "delete" },
                { keys: ["/"], text: "search" },
                { keys: ["PgUp", "PgDn"], text: "scroll" },
                { keys: ["D"], text: "clear all" },
                { keys: ["q"], text: "close" },
                { keys: ["o"], text: "open", ghost: view.kind !== "url" }
            ]];
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (view.confirmClear) {
            if (event.key === Qt.Key_Y) {
                view.confirmClear = false;
                wipeProc.running = true;
            } else {
                view.confirmClear = false;
            }
            return true;
        }
        if (view.searching) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                view.searching = false;
            else if (event.key === Qt.Key_Backspace)
                view.filter = view.filter.slice(0, -1);
            else if (ctrl && event.key === Qt.Key_U)
                view.filter = "";
            else if (event.key === Qt.Key_Down)
                view.select(view.selectedIndex + 1);
            else if (event.key === Qt.Key_Up)
                view.select(view.selectedIndex - 1);
            else if (!ctrl && event.text.length === 1 && event.text >= " ")
                view.filter += event.text;
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            view.select(view.selectedIndex + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.select(view.selectedIndex - 1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.select(view.selectedIndex + 8);
            else if (!shift)
                view.deleteSelected();
            else
                view.confirmClear = true;
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.select(view.selectedIndex - 8);
            return true;
        case Qt.Key_G:
            view.select(shift ? view.rows.length - 1 : 0);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            view.copySelected(true);
            return true;
        case Qt.Key_Y:
            view.copySelected(false);
            return true;
        case Qt.Key_P:
            view.togglePin();
            return true;
        case Qt.Key_Slash:
            view.searching = true;
            return true;
        case Qt.Key_O:
            view.openLink();
            return true;
        case Qt.Key_R:
            view.reload();
            return true;
        case Qt.Key_PageDown:
            view.scrollPreview(1);
            return true;
        case Qt.Key_PageUp:
            view.scrollPreview(-1);
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    function scrollPreview(dir) {
        const max = Math.max(0, previewFlick.contentHeight - previewFlick.height);
        previewFlick.contentY = Math.max(0, Math.min(max, previewFlick.contentY + dir * previewFlick.height * 0.8));
    }

    // ---- layout ----
    readonly property int listW: 720
    readonly property int rightX: view.listW + 40
    readonly property int rightW: view.width - view.rightX
    readonly property int rowH: 52

    function glyph(kind, pinned) {
        if (pinned)
            return "\uf08d";
        switch (kind) {
        case "url":
            return "\uf0c1";
        case "image":
            return "\uf03e";
        case "color":
            return "\uf1fc";
        case "path":
            return "\uf07b";
        case "binary":
            return "\uf1c6";
        }
        return "\uf15c";
    }

    function kindColor(kind, pinned) {
        if (pinned)
            return Theme.yellow;
        switch (kind) {
        case "url":
            return Theme.blue;
        case "image":
            return Theme.green;
        case "color":
            return Theme.mauve;
        case "path":
            return Theme.teal;
        }
        return Theme.subtext1;
    }

    Text {
        x: 0
        y: 0
        width: view.listW
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Clipboard"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    Text {
        x: view.width - width
        y: 0
        width: 600
        height: 52
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: view.toastText
        color: Theme.yellow
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        renderType: view.textRender
    }

    // search field (drawn here: a view has no text input of its own)
    Rectangle {
        x: 0
        y: 58
        width: view.listW
        height: 44
        radius: 12
        color: Theme.surface2
        border.width: view.searching ? 2 : 0
        border.color: Theme.blue

        Text {
            x: 16
            width: 24
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: "\uf002"
            color: view.searching ? Theme.blue : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            renderType: view.textRender
        }

        Text {
            x: 50
            width: parent.width - 120
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: view.filter !== "" ? view.filter + (view.searching ? "▏" : "") : (view.searching ? "▏" : "Press / to search")
            color: view.filter !== "" ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            elide: Text.ElideLeft
            renderType: view.textRender
        }

        Text {
            x: parent.width - 100
            width: 86
            height: parent.height
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: view.loaded ? view.rows.length + (view.rows.length === 1 ? " entry" : " entries") : ""
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }
    }

    ListView {
        id: list

        visible: view.rows.length > 0
        x: 0
        y: 116
        width: view.listW
        height: view.height - 116
        clip: true
        spacing: 4
        model: view.rows
        currentIndex: view.selectedIndex
        onCurrentIndexChanged: if (list.currentIndex >= 0)
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool sel: modelData.key === view.selectedKey

            width: list.width
            height: view.rowH
            radius: 12
            color: row.sel ? Theme.surface2 : "transparent"

            Text {
                x: 14
                width: 34
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: view.glyph(modelData.kind, modelData.pinned === true)
                color: view.kindColor(modelData.kind, modelData.pinned === true)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 6
                renderType: view.textRender
            }

            Text {
                x: 62
                width: parent.width - 80
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: modelData.label
                color: row.sel ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                font.bold: row.sel
                elide: Text.ElideRight
                maximumLineCount: 1
                renderType: view.textRender
            }

            MouseArea {
                anchors.fill: parent
                onClicked: view.selectedKey = modelData.key
                onDoubleClicked: {
                    view.selectedKey = modelData.key;
                    view.copySelected(true);
                }
            }
        }
    }

    // no history / no match
    EmptyState {
        visible: view.loaded && view.rows.length === 0 && view.filter === ""
        x: 0
        y: 116
        width: view.width
        height: view.height - 116
        illustration: "clipboard.svg"
        title: "Clipboard is empty"
        hint: "Copied text and images show up here"
        textRender: view.textRender
    }

    Text {
        visible: view.rows.length === 0 && view.filter !== ""
        x: 0
        y: 130
        width: view.listW
        horizontalAlignment: Text.AlignHCenter
        text: "No entry contains \"" + view.filter + "\""
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 3
        font.italic: true
        elide: Text.ElideRight
        renderType: view.textRender
    }

    // ---- separator + preview ----
    Rectangle {
        visible: view.rows.length > 0
        x: view.listW + 20
        width: 1
        height: parent.height
        color: Theme.surface2
    }

    Item {
        id: pane

        visible: !!view.selected
        x: view.rightX
        y: 0
        width: view.rightW
        height: view.height

        Text {
            x: 0
            y: 0
            width: 80
            height: 52
            verticalAlignment: Text.AlignVCenter
            text: view.glyph(view.kind, view.selected && view.selected.pinned === true)
            color: view.kindColor(view.kind, view.selected && view.selected.pinned === true)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 14
            renderType: view.textRender
        }

        Text {
            x: 54
            y: 0
            width: pane.width - 54
            height: 52
            verticalAlignment: Text.AlignVCenter
            text: view.selected ? ((view.selected.pinned ? "Pinned " : "") + ({ url: "link", image: "image", color: "color", path: "path", binary: "binary data", text: "text" })[view.kind]) : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 8
            font.bold: true
            renderType: view.textRender
        }

        Text {
            x: 0
            y: 54
            width: pane.width
            height: 28
            verticalAlignment: Text.AlignVCenter
            text: view.metaText + (view.previewBusy ? "  ·  loading…" : "")
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            elide: Text.ElideRight
            renderType: view.textRender
        }

        // color swatch
        Rectangle {
            visible: view.kind === "color"
            x: 0
            y: 100
            width: 220
            height: 120
            radius: 16
            color: view.kind === "color" ? view.fullText.trim() : "transparent"
            border.width: 1
            border.color: Theme.surface2
        }

        Flickable {
            id: previewFlick

            visible: view.kind !== "image" && view.kind !== "binary"
            x: 0
            y: view.kind === "color" ? 240 : 100
            width: pane.width
            height: pane.height - y
            clip: true
            contentWidth: width
            contentHeight: previewText.height

            Text {
                id: previewText

                width: previewFlick.width - 10
                text: view.fullText
                color: Theme.text
                font.family: view.monoFont
                font.pixelSize: Theme.fontSize + 2
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                lineHeight: 1.2
                renderType: view.textRender
            }
        }

        Image {
            visible: view.kind === "image"
            x: 0
            y: 100
            width: pane.width
            height: pane.height - 100
            source: view.previewImage
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
            sourceSize: Qt.size(pane.width, pane.height)
        }

        Text {
            visible: view.kind === "binary"
            x: 0
            y: 110
            width: pane.width
            text: "This entry is not text or a known image, so it can't be previewed or copied from here."
            wrapMode: Text.Wrap
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.italic: true
            renderType: view.textRender
        }
    }
}
