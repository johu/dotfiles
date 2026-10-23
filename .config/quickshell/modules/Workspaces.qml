import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland

Rectangle {
    id: root
    radius: Theme.radius
    color: Theme.surface1
    implicitWidth: layout.implicitWidth + 12
    implicitHeight: Theme.moduleHeight

    function switchTo(workspace) {
        const lua = typeof workspace === "number"
            ? `hl.dsp.focus({ workspace = ${workspace} })`
            : `hl.dsp.focus({ workspace = "${workspace}" })`;
        hyprctl.exec(["hyprctl", "dispatch", lua]);
    }

    Process {
        id: hyprctl
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => root.switchTo(wheel.angleDelta.y > 0 ? "-1" : "+1")
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: {
                const ids = new Set([1, 2, 3, 4, 5]);
                for (const w of Hyprland.workspaces.values)
                    ids.add(w.id);
                return Array.from(ids).sort((a, b) => a - b);
            }

            delegate: Rectangle {
                id: dot
                required property int modelData

                readonly property var ws: {
                    for (const w of Hyprland.workspaces.values) {
                        if (w.id === modelData)
                            return w;
                    }
                    return null;
                }
                readonly property bool active: ws !== null && ws.focused

                width: 19
                height: 19
                radius: width / 2
                color: active ? Theme.blue : (hover.hovered ? Theme.green : Theme.crust)

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: root.switchTo(dot.modelData)
                }
            }
        }
    }
}
