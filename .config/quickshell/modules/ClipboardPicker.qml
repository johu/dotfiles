import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PopupWindow {
    id: root

    property var entries: []
    property string filterText: ""
    property bool confirmClear: false

    readonly property var filteredEntries: {
        if (!filterText)
            return entries;
        const needle = filterText.toLowerCase();
        return entries.filter(e => e.preview.toLowerCase().includes(needle));
    }

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"
    implicitWidth: 380
    implicitHeight: 440

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width / 2, 0);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x - root.implicitWidth / 2;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.filterText = "";
        root.confirmClear = false;
        root.visible = true;
        focusGrab.active = true;
        listProc.running = true;
    }

    function close() {
        root.visible = false;
    }

    // grabFocus dismisses popups too eagerly on Hyprland; use a real
    // input grab for keyboard focus and click-outside-to-dismiss instead.
    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        onCleared: root.close()
    }

    function copyEntry(id) {
        copyProc.pendingId = id;
        copyProc.running = true;
        root.close();
    }

    function deleteEntry(id) {
        deleteProc.pendingId = id;
        deleteProc.running = true;
        root.entries = root.entries.filter(e => e.id !== id);
    }

    // cliphist decode/delete only need the id before the first tab, so
    // entries carry just the id, never the raw (user-controlled) preview.
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0);
                const parsed = [];
                for (const line of lines) {
                    const m = line.match(/^(\d+)\t(.*)$/);
                    if (!m)
                        continue;
                    const preview = m[2];
                    const imgMatch = preview.match(/^\[\[ binary data [^ ]+ (\w+) \d+x\d+ \]\]$/);
                    const ext = imgMatch ? imgMatch[1].toLowerCase() : null;
                    const knownExt = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff"].includes(ext);
                    parsed.push({
                        id: m[1],
                        preview: preview,
                        isImage: imgMatch !== null && knownExt,
                        ext: knownExt ? ext : null
                    });
                }
                root.entries = parsed;
            }
        }
    }

    Process {
        id: copyProc
        property string pendingId: ""
        stdinEnabled: true
        command: ["sh", "-c", "cliphist decode | wl-copy"]
        onRunningChanged: if (running) write(pendingId + "\t\n")
    }

    Process {
        id: deleteProc
        property string pendingId: ""
        stdinEnabled: true
        command: ["cliphist", "delete"]
        onRunningChanged: if (running) write(pendingId + "\t\n")
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
    }

    Timer {
        id: clearArmTimer
        interval: 3000
        onTriggered: root.confirmClear = false
    }

    onVisibleChanged: {
        if (!visible) {
            confirmClear = false;
            focusGrab.active = false;
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Theme.radius
                    color: Theme.surface2

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        clip: true
                        focus: root.visible
                        onTextChanged: root.filterText = text
                        Keys.onEscapePressed: root.close()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: "Search clipboard..."
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }

                Text {
                    text: "\uf1f8"
                    color: root.confirmClear ? Theme.red : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconFontSize

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.confirmClear) {
                                wipeProc.running = true;
                                root.entries = [];
                                root.confirmClear = false;
                            } else {
                                root.confirmClear = true;
                                clearArmTimer.restart();
                            }
                        }
                    }
                }
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredEntries

                delegate: Rectangle {
                    id: rowItem
                    required property var modelData

                    width: listView.width
                    height: 44
                    radius: Theme.radius
                    color: rowMouse.containsMouse ? Theme.surface2 : "transparent"

                    property string thumbPath: ""

                    Process {
                        id: thumbProc
                        running: rowItem.modelData.isImage
                        stdinEnabled: true
                        command: ["sh", "-c",
                            'mkdir -p /tmp/quickshell-clipboard-thumbs && cliphist decode > "$1"',
                            "thumb", "/tmp/quickshell-clipboard-thumbs/" + rowItem.modelData.id + "." + rowItem.modelData.ext]
                        onRunningChanged: if (running) write(rowItem.modelData.id + "\t\n")
                        onExited: rowItem.thumbPath = "/tmp/quickshell-clipboard-thumbs/" + rowItem.modelData.id + "." + rowItem.modelData.ext
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyEntry(rowItem.modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 10

                        Image {
                            visible: rowItem.modelData.isImage && rowItem.thumbPath.length > 0
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            fillMode: Image.PreserveAspectCrop
                            source: rowItem.thumbPath.length > 0 ? "file://" + rowItem.thumbPath : ""
                        }

                        Text {
                            Layout.fillWidth: true
                            text: rowItem.modelData.isImage ? "Image" : rowItem.modelData.preview
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "\uf00d"
                            color: deleteMouse.containsMouse ? Theme.red : Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconFontSize

                            MouseArea {
                                id: deleteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteEntry(rowItem.modelData.id)
                            }
                        }
                    }
                }
            }

            Text {
                visible: listView.count === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "No clipboard history"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
