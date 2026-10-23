import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    // Hyprland.activeToplevel is only populated by the "activewindowv2" IPC
    // event, which fires on the *next* focus change — it stays null on
    // startup until then. Query it once ourselves to cover that gap.
    property string initialTitle: ""

    Process {
        running: true
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (data && data.title)
                        root.initialTitle = data.title;
                } catch (e) {}
            }
        }
    }

    // Hyprland.activeToplevel is only ever updated by a *non-empty*
    // "activewindowv2" IPC event; on a workspace with no windows it stays
    // stuck pointing at the previously focused (now unfocused) window.
    // Detect that staleness by cross-checking against focusedWorkspace,
    // which is driven by reliable workspace/monitor events instead.
    readonly property var toplevel: Hyprland.activeToplevel
    readonly property var focusedWs: Hyprland.focusedWorkspace
    readonly property bool toplevelStale: toplevel !== null && focusedWs !== null && toplevel.workspace !== null && toplevel.workspace.id !== focusedWs.id

    readonly property string rawTitle: {
        if (!root.toplevel)
            return root.initialTitle;
        if (root.toplevelStale)
            return "";
        return root.toplevel.title;
    }

    readonly property var rewrites: [
        [/(.*) ?[—-] ?Mozilla Firefox/, "$1 󰈹"],
        [/^Mozilla Firefox$/, "Firefox 󰈹"],
        [/(.*) ?[—-] ?Dolphin/, "$1 󰉋"],
        [/Spotify.*/, "Spotify 󰓇"],
        [/Steam.*/, "Steam 󰓓"],
    ]

    readonly property string displayText: {
        for (const [pattern, replacement] of rewrites) {
            if (pattern.test(rawTitle))
                return rawTitle.replace(pattern, replacement);
        }
        return rawTitle;
    }

    readonly property alias text: label.text

    // Text.implicitWidth reads 0 on first render when elide is set and no
    // explicit width has been assigned yet. Measure separately via
    // TextMetrics instead, with a small margin for the sub-pixel gap
    // between its measurement and the Text item's actual glyph layout.
    implicitWidth: metrics.width + 4
    implicitHeight: label.implicitHeight

    TextMetrics {
        id: metrics
        font: label.font
        text: root.displayText
    }

    Text {
        id: label
        anchors.fill: parent
        text: root.displayText
        color: Theme.lavender
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
