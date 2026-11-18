import QtQuick

// Scrollable monospace text: conflict text, advisory text, build log. One list row per
// line (a single huge Text item is clipped by the scene graph past ~16k pixels), long lines
// wrap. A build log opens at its end, where the error is; `o` opens the file in nvim.
Item {
    id: page

    property var view

    readonly property string note: view.textTitle
    readonly property var lines: view.textBody !== "" ? view.textBody.split("\n") : []
    readonly property bool isLog: view.page === "buildlog"

    readonly property var hints: [[
            { keys: ["j", "k"], text: "scroll" },
            { keys: ["Ctrl-d", "Ctrl-u"], text: "half page" },
            { keys: ["g", "G"], text: "top / end" },
            { keys: ["o"], text: "open in nvim", ghost: view.textPath === "" },
            { keys: ["Esc"], text: "back" }
        ]]

    onLinesChanged: if (page.isLog && lines.length > 0) endTimer.restart()

    Timer {
        id: endTimer

        interval: 60
        onTriggered: page.toEnd()
    }

    function toEnd() {
        flick.positionViewAtEnd();
    }

    function scrollBy(dy) {
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + dy));
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.scrollBy(48);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.scrollBy(-48);
            return true;
        case Qt.Key_D:
        case Qt.Key_PageDown:
            page.scrollBy(flick.height / 2);
            return true;
        case Qt.Key_U:
        case Qt.Key_PageUp:
            page.scrollBy(-flick.height / 2);
            return true;
        case Qt.Key_G:
            if (event.modifiers & Qt.ShiftModifier)
                page.toEnd();
            else
                flick.contentY = 0;
            return true;
        case Qt.Key_Home:
            flick.contentY = 0;
            return true;
        case Qt.Key_End:
            page.toEnd();
            return true;
        case Qt.Key_O:
            if (view.textPath !== "")
                view.openInNvim(view.textPath);
            return true;
        }
        return false;
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: GentooStyle.cardColor
        border.width: 1
        border.color: Theme.surface2
    }

    ListView {
        id: flick

        anchors.fill: parent
        anchors.margins: 24
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        model: page.lines

        delegate: GText {
            required property string modelData

            width: ListView.view.width
            text: modelData === "" ? " " : modelData
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
            verticalAlignment: Text.AlignTop
            lineHeight: 1.1
            height: implicitHeight
        }
    }

    GText {
        visible: page.lines.length === 0
        x: 24
        y: 24
        text: "loading…"
        color: view.dim
    }
}
