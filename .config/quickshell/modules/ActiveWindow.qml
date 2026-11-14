import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    // activeToplevel is only set by the next "activewindowv2" event, so query
    // it once at startup.
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

    // activeToplevel only updates on non-empty events, so on an empty
    // workspace it keeps the previous window. Detect that by cross-checking
    // focusedWorkspace.
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

    // Text.implicitWidth is 0 on first render with elide and no width; measure
    // with TextMetrics plus a small margin for sub-pixel layout.
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
        renderType: Text.NativeRendering
        font.bold: true
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
