import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

// Notifications view of the launcher: the inbox (open popups and history) as
// a list on the left, the selected notification in full on the right, all
// keyboard driven. Same contract as LauncherCalendarView.qml: `hints`,
// handleKey(event), closeRequested(), leaveRequested(), textRender.
// Geometry is fixed (explicit x / y) so panes never shift with the content.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property int listWidth: 600
    readonly property int rowHeight: 84

    // Newest first: open popups and queued ones, then history.
    readonly property var entries: Notifications.notifications

    // Selection follows the notification's key, so new arrivals do not move it.
    // Keys are numbers: a string property would never match with ===.
    property var selectedKey: null
    readonly property int selectedIndex: {
        const i = view.entries.findIndex(e => e.key === view.selectedKey);
        return i >= 0 ? i : (view.entries.length > 0 ? 0 : -1);
    }
    readonly property var selected: view.selectedIndex >= 0 ? view.entries[view.selectedIndex] : null
    readonly property bool live: !!view.selected && !view.selected.closed
    readonly property var actions: view.selected ? view.selected.actions.filter(a => a.identifier !== "default") : []
    readonly property bool hasDefault: view.selected ? view.selected.actions.some(a => a.identifier === "default") : false

    readonly property var hints: [[
            { keys: ["j", "k"], text: "move" },
            { keys: ["g", "G"], text: "first / last" },
            { keys: ["d"], text: "remove" },
            { keys: ["D"], text: "clear all" }
        ].concat(view.live && (view.actions.length > 0 || view.hasDefault) ? [{ keys: ["↵"], text: "default" }] : []).concat(view.live && view.actions.length > 0 ? [{ keys: ["1-9"], text: "action" }] : []).concat([
            { keys: ["m"], text: Notifications.dnd ? "\uf1f7" : "\uf0a2", width: 28 },
            { keys: ["q"], text: "back" }
        ])]

    Component.onCompleted: Notifications.markSeen()

    function urgencyColor(n) {
        return n.urgency === NotificationUrgency.Critical ? Theme.red : (n.urgency === NotificationUrgency.Low ? Theme.subtext1 : Theme.blue);
    }

    function plain(html) {
        return (html || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    function whenLabel(ms) {
        return Qt.formatDateTime(new Date(ms), "ddd d MMM, HH:mm");
    }

    function select(index) {
        if (view.entries.length === 0)
            return;
        view.selectedKey = view.entries[Math.max(0, Math.min(index, view.entries.length - 1))].key;
    }

    function removeSelected() {
        const s = view.selected;
        if (!s)
            return;
        const i = view.selectedIndex;
        const next = view.entries[i + 1] ?? view.entries[i - 1] ?? null;
        view.selectedKey = next ? next.key : null;
        Notifications.removeHistory(s.key);
    }

    function invoke(identifier) {
        if (!view.live)
            return;
        Notifications.invokeAction(view.selected.key, identifier);
        view.closeRequested();
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !ctrl) {
            const a = view.actions[event.key - Qt.Key_1];
            if (a)
                view.invoke(a.identifier);
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
        case Qt.Key_G:
            view.select(shift ? view.entries.length - 1 : 0);
            return true;
        case Qt.Key_Home:
            view.select(0);
            return true;
        case Qt.Key_End:
            view.select(view.entries.length - 1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.select(view.selectedIndex + 8);
            else if (shift)
                Notifications.clearHistory();
            else
                view.removeSelected();
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.select(view.selectedIndex - 8);
            return true;
        case Qt.Key_M:
            Notifications.setDndSilently(!Notifications.dnd);
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (view.hasDefault)
                view.invoke("default");
            else if (view.actions.length > 0)
                view.invoke(view.actions[0].identifier);
            return true;
        }
        return false;
    }

    // ---- header ----
    Text {
        x: 0
        y: 0
        width: view.listWidth
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Notifications"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    Text {
        x: 0
        y: 54
        width: view.listWidth
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: view.entries.length === 0 ? "Nothing here" : view.entries.length + (view.entries.length === 1 ? " notification" : " notifications")
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        renderType: view.textRender
    }

    // Do Not Disturb state: bell-slash in red when on, plain bell when off.
    Text {
        x: view.listWidth - 44
        y: 6
        width: 44
        height: 52
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: Notifications.dnd ? "\uf1f7" : "\uf0a2"
        color: Notifications.dnd ? Theme.red : Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        renderType: view.textRender
    }

    // ---- list ----
    ListView {
        id: list

        x: 0
        y: 92
        width: view.listWidth
        height: parent.height - 92
        clip: true
        spacing: 6
        model: view.entries
        currentIndex: view.selectedIndex
        onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            readonly property bool current: row.index === view.selectedIndex

            width: list.width
            height: view.rowHeight - 6
            radius: 12
            color: row.current ? Theme.surface2 : "transparent"
            border.width: 1
            border.color: row.current ? Theme.blue : Theme.surface2

            Rectangle {
                x: 0
                y: 10
                width: 4
                height: parent.height - 20
                radius: 2
                color: view.urgencyColor(row.modelData)
                opacity: row.modelData.closed ? 0.35 : 1
            }

            ResolvedIcon {
                x: 18
                y: (parent.height - 36) / 2
                iconSource: row.modelData.iconSource
                size: 36
            }

            Text {
                x: 70
                y: 10
                width: parent.width - 70 - 90
                height: 20
                text: row.modelData.appName || "Notification"
                elide: Text.ElideRight
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                renderType: view.textRender
            }

            Text {
                x: parent.width - 80
                y: 10
                width: 68
                height: 20
                horizontalAlignment: Text.AlignRight
                text: (row.modelData.closed ? "" : "● ") + Notifications.relativeTime(row.modelData.time)
                color: row.modelData.closed ? Theme.subtext1 : Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                renderType: view.textRender
            }

            Text {
                x: 70
                y: 32
                width: parent.width - 70 - 14
                height: 22
                text: row.modelData.summary || "(no title)"
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                renderType: view.textRender
            }

            Text {
                x: 70
                y: 56
                width: parent.width - 70 - 14
                height: 18
                text: view.plain(row.modelData.body)
                elide: Text.ElideRight
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                renderType: view.textRender
            }

            MouseArea {
                anchors.fill: parent
                onClicked: view.selectedKey = row.modelData.key
            }
        }
    }

    Text {
        visible: view.entries.length === 0
        x: 0
        y: 120
        width: view.listWidth
        text: "No notifications"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        renderType: view.textRender
    }

    // ---- separator + detail ----
    Rectangle {
        x: view.listWidth + 20
        width: 1
        height: parent.height
        color: Theme.surface2
    }

    Item {
        id: detail

        visible: !!view.selected
        anchors.left: parent.left
        anchors.leftMargin: view.listWidth + 40
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        ResolvedIcon {
            x: 0
            y: 4
            iconSource: view.selected ? view.selected.iconSource : ""
            size: 56
        }

        Text {
            x: 76
            y: 4
            width: parent.width - 76
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: view.selected ? (view.selected.appName || "Notification") : ""
            elide: Text.ElideRight
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            renderType: view.textRender
        }

        Text {
            x: 76
            y: 32
            width: parent.width - 76
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: view.selected ? view.whenLabel(view.selected.time) + (view.live ? " · open" : "") + (view.selected.urgency === NotificationUrgency.Critical ? " · critical" : "") : ""
            color: view.selected ? view.urgencyColor(view.selected) : Theme.blue
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: view.textRender
        }

        Text {
            x: 0
            y: 76
            width: parent.width
            text: view.selected ? (view.selected.summary || "(no title)") : ""
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 6
            font.bold: true
            renderType: view.textRender
        }

        Flickable {
            id: bodyFlick

            x: 0
            y: 76 + 90
            width: parent.width
            height: detail.height - (76 + 90) - actionsBox.height - 12
            contentWidth: width
            contentHeight: bodyColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: bodyColumn

                width: bodyFlick.width
                spacing: 12

                Text {
                    width: parent.width
                    text: view.selected ? view.selected.richBody : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    renderType: view.textRender
                }

                Image {
                    visible: !!view.selected && view.selected.previewImage.length > 0
                    width: parent.width
                    height: visible ? 240 : 0
                    source: visible ? view.selected.previewImage : ""
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignLeft
                    asynchronous: true
                }
            }
        }

        // ---- actions (only open notifications can still be invoked) ----
        Column {
            id: actionsBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 6

            Text {
                visible: !view.live && !!view.selected && view.selected.actions.length > 0
                width: parent.width
                text: "Actions are only available while a notification is open."
                wrapMode: Text.Wrap
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.italic: true
                renderType: view.textRender
            }

            Repeater {
                model: view.live ? view.actions.slice(0, 9) : []

                Rectangle {
                    required property var modelData
                    required property int index

                    width: actionsBox.width
                    height: 36
                    radius: 10
                    color: Theme.surface2

                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: (index + 1) + "   " + modelData.text
                        elide: Text.ElideRight
                        width: parent.width - 24
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        renderType: view.textRender
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: view.invoke(modelData.identifier)
                    }
                }
            }
        }
    }
}
