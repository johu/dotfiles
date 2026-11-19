import QtQuick
import "GentooParse.js" as P

// News page: item list on the left, the selected item's text on the right. The state
// lives in /var/lib/gentoo/news (read / unread lists, group-writable, no root needed);
// "hidden" items are known to portage but not in eselect's list (purged).
Item {
    id: page

    property var view

    property bool showHidden: false
    property bool confirmPurge: false
    property int cur: 0
    property string curId: ""

    readonly property var all: view.newsD.items
    readonly property var items: showHidden ? all : all.filter(i => i.state !== "hidden")
    readonly property var sel: items.length > 0 ? items[Math.min(cur, items.length - 1)] : null
    readonly property string note: "items that apply to installed packages · " + (view.newsD.read + view.newsD.unread) + " items, " + view.newsD.unread + " unread" + (view.newsD.hidden > 0 ? " · " + view.newsD.hidden + " hidden" : "")

    readonly property var hints: confirmPurge ? [[
                { keys: ["y"], text: "purge" },
                { keys: ["Esc"], text: "cancel" }
            ]] : [[
                { keys: ["j", "k"], text: "move" },
                { keys: ["PgDn"], text: "scroll text" },
                { keys: ["m"], text: "read / unread" },
                { keys: ["A"], text: "all read" },
                { keys: ["d"], text: "hide item", ghost: !sel || sel.state !== "read" },
                { keys: ["P"], text: "purge read" },
                { keys: ["h"], text: showHidden ? "hide hidden" : "show hidden" },
                { keys: ["Esc"], text: "back" }
            ]]

    onItemsChanged: {
        const i = page.items.findIndex(x => x.id === page.curId);
        page.cur = i >= 0 ? i : Math.min(page.cur, Math.max(0, page.items.length - 1));
        page.curId = page.items.length > 0 ? page.items[page.cur].id : "";
    }

    onCurChanged: {
        if (page.sel)
            page.curId = page.sel.id;
        list.positionViewAtIndex(page.cur, ListView.Contain);
        flick.contentY = 0;
    }

    function scrollBy(dy) {
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + dy));
    }

    function handleEscape() {
        if (page.confirmPurge) {
            page.confirmPurge = false;
            return true;
        }
        return false;
    }

    function handleKey(event) {
        const shift = event.modifiers & Qt.ShiftModifier;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (page.confirmPurge) {
            if (event.key === Qt.Key_Y) {
                view.markNews("purgeall", []);
                page.confirmPurge = false;
            }
            return true;
        }
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.cur = Math.min(page.items.length - 1, page.cur + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.cur = Math.max(0, page.cur - 1);
            return true;
        case Qt.Key_PageDown:
            page.scrollBy(flick.height * 0.8);
            return true;
        case Qt.Key_PageUp:
            page.scrollBy(-flick.height * 0.8);
            return true;
        case Qt.Key_D:
            if (ctrl) {
                page.scrollBy(flick.height / 2);
                return true;
            }
            if (page.sel && page.sel.state === "read")
                view.markNews("purge", [page.sel.id]);
            return true;
        case Qt.Key_U:
            if (ctrl) {
                page.scrollBy(-flick.height / 2);
                return true;
            }
            return false;
        case Qt.Key_M:
            if (page.sel)
                view.markNews(page.sel.state === "read" ? "unread" : "read", [page.sel.id]);
            return true;
        case Qt.Key_A:
            if (shift && view.newsD.unread > 0)
                view.markNews("allread", []);
            return true;
        case Qt.Key_P:
            if (shift && view.newsD.read > 0)
                page.confirmPurge = true;
            return true;
        case Qt.Key_H:
            page.showHidden = !page.showHidden;
            return true;
        case Qt.Key_G:
            page.cur = shift ? Math.max(0, page.items.length - 1) : 0;
            return true;
        }
        return false;
    }

    // ---- list ----
    GText {
        x: 0
        y: 0
        height: 24
        text: "RECENT"
        color: GentooStyle.faint
        size: Theme.fontSize - 3
        font.letterSpacing: 1
    }

    Rectangle {
        x: 0
        y: 28
        width: Math.round(page.width * 0.4)
        height: 1
        color: Theme.surface2
    }

    ListView {
        id: list

        x: 0
        y: 36
        width: Math.round(page.width * 0.4)
        height: page.height - 36
        clip: true
        interactive: false
        model: page.items

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool isSel: index === page.cur

            width: ListView.view.width
            height: 56

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: row.isSel ? GentooStyle.rowSelected : "transparent"
            }

            Rectangle {
                x: 14
                y: 24
                width: 10
                height: 10
                radius: 5
                color: modelData.state === "unread" ? Theme.mauve : (modelData.state === "read" ? Theme.surface2 : "transparent")
                border.width: modelData.state === "hidden" ? 1 : 0
                border.color: GentooStyle.faint
            }

            GText {
                x: 40
                y: 4
                width: parent.width - 56
                height: 20
                text: modelData.posted + (modelData.repo !== "gentoo" ? " · " + modelData.repo : "")
                color: view.dim
                size: Theme.fontSize - 2
            }

            GText {
                x: 40
                y: 24
                width: parent.width - 56
                height: 28
                text: modelData.title
                strong: modelData.state === "unread" || row.isSel
                color: modelData.state === "hidden" ? view.dim : Theme.text
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.cur = row.index
            }
        }
    }

    EmptyState {
        visible: page.items.length === 0
        x: 0
        y: 36
        width: Math.round(page.width * 0.4)
        height: page.height - 36
        illustration: "news.svg"
        imageSize: 150
        title: "No news"
        hint: view.newsD.hidden > 0 ? "h shows " + view.newsD.hidden + " hidden items" : "nothing applies to this system"
        textRender: view.textRender
    }

    // ---- reader ----
    Rectangle {
        id: reader

        x: Math.round(page.width * 0.4 + 40)
        y: 0
        width: page.width - x
        height: page.height
        radius: 16
        color: GentooStyle.cardColor
        border.width: 1
        border.color: Theme.surface2

        GText {
            x: 30
            y: 16
            width: parent.width - 60
            height: 36
            text: page.sel ? page.sel.title : ""
            strong: true
            size: Theme.fontSize + 6
        }

        GText {
            x: 30
            y: 54
            width: parent.width - 60
            height: 24
            color: view.dim
            size: Theme.fontSize - 1
            text: page.sel ? page.sel.author.replace(/\s*<.*>/, "") + " · posted " + page.sel.posted + (page.sel.revision !== "" ? " · revision " + page.sel.revision : "") + " · " + page.sel.state : ""
        }

        Rectangle {
            x: 30
            y: 88
            width: parent.width - 60
            height: 1
            color: Theme.surface2
        }

        Flickable {
            id: flick

            x: 30
            y: 100
            width: parent.width - 60
            height: parent.height - 130
            clip: true
            contentWidth: width
            contentHeight: bodyCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: bodyCol

                width: flick.width

                Repeater {
                    model: page.sel ? P.newsLines(page.sel.body) : []

                    GText {
                        required property var modelData

                        width: parent.width
                        height: 24
                        text: modelData.text === "" ? " " : modelData.text
                        color: modelData.heading ? Theme.blue : Theme.text
                        strong: modelData.heading
                        elide: Text.ElideNone
                        size: Theme.fontSize + 1
                    }
                }
            }
        }

        Rectangle {
            visible: page.confirmPurge
            x: 30
            y: parent.height - 110
            width: parent.width - 60
            height: 88
            radius: 12
            color: Theme.base
            border.width: 1
            border.color: Theme.yellow

            GText {
                x: 18
                y: 8
                width: parent.width - 36
                height: 26
                text: "Purge " + view.newsD.read + " read news items?"
                color: Theme.yellow
                strong: true
            }

            GText {
                x: 18
                y: 34
                width: parent.width - 36
                height: 46
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                size: Theme.fontSize - 1
                color: view.dim
                text: "Like `eselect news purge`: read items leave the list (they stay known to portage, h shows them). Unread items stay.   y confirm   Esc cancel"
            }
        }
    }
}
