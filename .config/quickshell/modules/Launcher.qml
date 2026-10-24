import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    visible: false
    color: "transparent"
    screen: Quickshell.screens.find(s => s.name === "DP-3") ?? null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Exclusive keyboard focus on the layer-shell surface (the same
    // mechanism rofi uses) rather than PopupWindow's grabFocus, which
    // dismisses almost immediately on Hyprland (see Calendar.qml).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""
    property int selectedIndex: 0

    readonly property var apps: {
        const entries = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        return entries.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return root.apps;

        const scored = [];
        for (const e of root.apps) {
            const name = (e.name || "").toLowerCase();
            const generic = (e.genericName || "").toLowerCase();
            const comment = (e.comment || "").toLowerCase();
            const keywords = (e.keywords || []).join(" ").toLowerCase();

            let score = -1;
            if (name === q)
                score = 1000;
            else if (name.startsWith(q))
                score = 800;
            else if (name.includes(q))
                score = 500;
            else if (generic.includes(q) || keywords.includes(q))
                score = 300;
            else if (comment.includes(q))
                score = 100;
            else if (isSubsequence(q, name))
                score = 50;

            if (score >= 0)
                scored.push({ entry: e, score: score });
        }
        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return scored.map(s => s.entry);
    }

    function isSubsequence(needle, haystack) {
        let i = 0;
        for (let j = 0; j < haystack.length && i < needle.length; j++) {
            if (haystack[j] === needle[i])
                i++;
        }
        return i === needle.length;
    }

    function open() {
        root.query = "";
        root.selectedIndex = 0;
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    function launch(index) {
        const entry = root.filtered[index];
        if (!entry)
            return;
        entry.execute();
        root.close();
    }

    onVisibleChanged: {
        if (root.visible)
            Qt.callLater(() => searchInput.forceActiveFocus());
    }

    onFilteredChanged: root.selectedIndex = 0

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 560
        height: 420
        radius: Theme.radius
        color: Theme.surface1

        // Swallow clicks so they don't fall through to the fullscreen
        // dismiss MouseArea behind this card.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uf002"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconFontSize
                }

                TextInput {
                    id: searchInput

                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true

                    onTextChanged: root.query = text

                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1)
                    Keys.onUpPressed: root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                    Keys.onReturnPressed: root.launch(root.selectedIndex)
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filtered
                currentIndex: root.selectedIndex
                highlightFollowsCurrentItem: true

                onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

                delegate: Item {
                    id: delegateRoot

                    required property var modelData
                    required property int index

                    width: list.width
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius / 2
                        color: delegateRoot.index === root.selectedIndex ? Theme.surface2 : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        IconImage {
                            source: Quickshell.iconPath(delegateRoot.modelData.icon, "image-missing")
                            implicitSize: 28
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: delegateRoot.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: delegateRoot.modelData.comment || delegateRoot.modelData.genericName || ""
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = delegateRoot.index
                        onClicked: root.launch(delegateRoot.index)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No matching apps"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
