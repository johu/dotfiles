import QtQuick
import QtQuick.Effects
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

    // Ignore the bar's reserved exclusive zone so this surface (and the
    // screencopy capture it blurs) covers the true full screen, not just
    // the area below the bar — otherwise the capture's aspect ratio no
    // longer matches the screen's and letterboxes at the edges.
    exclusionMode: ExclusionMode.Ignore

    // Exclusive keyboard focus on the layer-shell surface (the same
    // mechanism rofi uses) rather than PopupWindow's grabFocus, which
    // dismisses almost immediately on Hyprland (see Calendar.qml).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property int pillWidth: 460
    readonly property int pillHeight: 64
    readonly property int resultsPanelWidth: 880
    readonly property int tileWidth: 220
    readonly property int tileContentMargin: 16
    readonly property int tileIconSize: 48
    readonly property int tileIconSpacing: 8
    readonly property int maxVisibleRows: 3
    readonly property int resultColumns: Math.max(1, Math.floor(root.resultsPanelWidth / root.tileWidth))
    readonly property int inputFontSize: Theme.fontSize + 8
    readonly property int resultFontSize: Theme.fontSize + 4
    readonly property int focusedDescFontSize: Theme.fontSize + 1
    // Fixed 2-line slot height so tiles with shorter names don't collapse
    // upward and misalign icons against their row neighbors.
    readonly property int nameBlockHeight: Math.round(root.resultFontSize * 2.8)
    // Derived so the margin above the icon exactly equals the margin
    // below the (fixed-height) name block — not a magic number that could
    // drift out of sync if nameBlockHeight's formula changes.
    readonly property int tileHeight: root.tileContentMargin * 2 + root.tileIconSize + root.tileIconSpacing + root.nameBlockHeight
    // Reserve a fixed-height slot for the focused-item description so
    // neither it nor the results grid below it shift position as
    // selection moves between apps with and without a comment/genericName.
    readonly property int focusedDescHeight: Math.round(root.focusedDescFontSize * 3.2)

    readonly property var selectedEntry: root.filtered[root.selectedIndex] ?? null
    readonly property string selectedDescription: root.selectedEntry ? (root.selectedEntry.comment || root.selectedEntry.genericName || "") : ""

    property string query: ""
    property int selectedIndex: 0

    readonly property var apps: {
        const entries = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        return entries.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    // fzf-style subsequence scorer: rewards consecutive runs and matches
    // starting right after a word boundary, penalizes scattered spans.
    // Returns -1 when needle isn't a subsequence of haystack at all.
    function fuzzyScore(needle, haystack) {
        if (!needle)
            return 0;

        let score = 0;
        let needleIndex = 0;
        let lastMatchIndex = -1;
        let consecutiveRun = 0;

        for (let i = 0; i < haystack.length && needleIndex < needle.length; i++) {
            if (haystack[i] !== needle[needleIndex])
                continue;

            let charScore = 1;
            if (lastMatchIndex === i - 1) {
                consecutiveRun++;
                charScore += consecutiveRun * 3;
            } else {
                consecutiveRun = 0;
            }

            const prev = i > 0 ? haystack[i - 1] : "";
            if (i === 0 || prev === " " || prev === "-" || prev === "_" || prev === ".")
                charScore += 4;

            score += charScore;
            lastMatchIndex = i;
            needleIndex++;
        }

        if (needleIndex < needle.length)
            return -1;

        const span = lastMatchIndex + 1;
        score += Math.max(0, 20 - (span - needle.length));
        return score;
    }

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return [];

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
            else {
                const fuzzy = root.fuzzyScore(q, name);
                if (fuzzy >= 0)
                    score = 50 + Math.min(fuzzy, 40);
            }

            if (score >= 0)
                scored.push({ entry: e, score: score });
        }
        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return scored.map(s => s.entry);
    }

    function open() {
        root.query = "";
        // searchInput.text isn't bound back to root.query (onTextChanged is
        // one-way, input -> query), so it must be cleared separately or a
        // query typed before an Escape-close lingers visibly on reopen
        // while filtering silently shows no results.
        searchInput.text = "";
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

    // Hyprland's native layer_rule blur doesn't render on this machine's
    // experimental Lua-config engine (confirmed: layer_rule accepted with
    // no error, decoration.blur.enabled true, but zero visible blur across
    // static config, dynamic hyprctl eval, and varying ignore_alpha). Fake
    // the blur instead via a one-shot screencopy + MultiEffect, same
    // pattern as references/shell/modules/lock/LockSurface.qml. Captured
    // fresh each time the launcher opens (Loader re-creates the
    // ScreencopyView), so it's a snapshot frozen at open-time rather than
    // a live blur — acceptable tradeoff for a launcher that owns exclusive
    // keyboard focus anyway.
    Item {
        id: blurredBackground

        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            active: root.visible
            sourceComponent: ScreencopyView {
                captureSource: root.screen
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Launcher.qml is pinned to a single screen (root.screen), so only
    // that monitor ever gets a blurred backdrop above — the rest of the
    // desktop stays untouched and visibly unblurred on other monitors.
    // Give every other screen its own blur-only (no pill/results) window
    // with the same screencopy+MultiEffect fake-blur, so the whole desktop
    // reads as dimmed while the launcher is open.
    Variants {
        model: Quickshell.screens.filter(s => s !== root.screen)

        PanelWindow {
            id: backdrop

            required property var modelData

            screen: modelData
            visible: root.visible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                anchors.fill: parent

                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                    blurMultiplier: 1
                }

                Loader {
                    anchors.fill: parent
                    active: backdrop.visible
                    sourceComponent: ScreencopyView {
                        captureSource: backdrop.screen
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.32 - height / 2
        width: root.pillWidth
        height: root.pillHeight
        radius: root.pillHeight / 2.5
        color: Theme.surface1
        border.width: 1
        border.color: Theme.surface2

        // Swallow clicks so they don't fall through to the fullscreen
        // dismiss MouseArea behind this pill.
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                text: "\uf002"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: root.inputFontSize
            }

            TextInput {
                id: searchInput

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.inputFontSize
                clip: true

                onTextChanged: root.query = text

                Keys.onEscapePressed: root.close()
                Keys.onRightPressed: root.selectedIndex = Math.min(root.selectedIndex + 1, root.filtered.length - 1)
                Keys.onLeftPressed: root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                Keys.onDownPressed: root.selectedIndex = Math.min(root.selectedIndex + root.resultColumns, root.filtered.length - 1)
                Keys.onUpPressed: root.selectedIndex = Math.max(root.selectedIndex - root.resultColumns, 0)
                Keys.onReturnPressed: root.launch(root.selectedIndex)
            }
        }
    }

    Text {
        id: focusedDescription

        visible: root.selectedDescription.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: 10
        width: root.resultsPanelWidth
        height: root.focusedDescHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: root.selectedDescription
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.italic: true
        font.pixelSize: root.focusedDescFontSize
    }

    Item {
        id: resultsPanel

        visible: root.filtered.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: focusedDescription.bottom
        anchors.topMargin: 14
        width: root.resultsPanelWidth
        height: Math.min(grid.contentHeight, root.maxVisibleRows * root.tileHeight)
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        GridView {
            id: grid

            anchors.fill: parent
            clip: true
            cellWidth: resultsPanel.width / root.resultColumns
            cellHeight: root.tileHeight
            model: root.filtered
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true

            onCurrentIndexChanged: grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)

            delegate: Item {
                id: delegateRoot

                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: Theme.radius / 2
                    color: delegateRoot.index === root.selectedIndex ? Theme.surface2 : "transparent"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.tileContentMargin
                    spacing: root.tileIconSpacing

                    IconImage {
                        source: Quickshell.iconPath(delegateRoot.modelData.icon, "image-missing")
                        implicitSize: root.tileIconSize
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.nameBlockHeight
                        verticalAlignment: Text.AlignTop
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        text: delegateRoot.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.resultFontSize
                        elide: Text.ElideRight
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
        }
    }
}
