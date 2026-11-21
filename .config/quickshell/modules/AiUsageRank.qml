import QtQuick
import "AiUsageFmt.js" as F

// Ranked list with proportional bars: [{ name, tokens, cost }], at most `maxRows` rows.
Item {
    id: root

    property var items: []
    property int maxRows: 5
    property bool showCost: false
    property var colors: [Theme.blue, Theme.mauve, Theme.teal, Theme.green, Theme.yellow, Theme.maroon]
    readonly property int rowH: 44
    readonly property real maxV: root.items.length ? Math.max(1, root.items[0].tokens) : 1

    implicitHeight: root.maxRows * root.rowH

    Repeater {
        model: root.items.slice(0, root.maxRows)

        delegate: Item {
            required property var modelData
            required property int index

            y: index * root.rowH
            width: root.width
            height: root.rowH

            GText {
                anchors.left: parent.left
                anchors.right: value.left
                anchors.rightMargin: 12
                y: 0
                height: 24
                text: modelData.name
            }

            GText {
                id: value

                anchors.right: parent.right
                y: 0
                height: 24
                text: F.tok(modelData.tokens) + (root.showCost && modelData.cost > 0 ? "  ·  " + F.cost(modelData.cost) : "")
                color: GentooStyle.dim
            }

            Rectangle {
                y: 28
                width: parent.width
                height: 6
                radius: 3
                color: GentooStyle.cardColor

                Rectangle {
                    width: Math.max(6, parent.width * modelData.tokens / root.maxV)
                    height: 6
                    radius: 3
                    color: root.colors[index % root.colors.length]
                }
            }
        }
    }
}
