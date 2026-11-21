import QtQuick
import "AiUsageFmt.js" as F

// Tokens per day as bars (today = lighter bar), with two grid lines and three day labels.
Item {
    id: root

    // [{ d: "YYYY-MM-DD", tokens }]
    property var days: []
    readonly property real maxV: {
        let m = 1;
        for (const d of root.days)
            m = Math.max(m, d.tokens);
        return m;
    }
    readonly property int plotX: 64
    readonly property int labelH: 28
    readonly property real plotH: Math.max(20, height - labelH)
    readonly property real gap: 10
    readonly property real barW: root.days.length ? (width - plotX - gap * (root.days.length - 1)) / root.days.length : 0

    Repeater {
        model: [0, 0.5, 1]

        delegate: Item {
            required property real modelData
            readonly property real yy: root.plotH - root.plotH * modelData

            Rectangle {
                x: root.plotX
                y: parent.yy
                width: root.width - root.plotX
                height: 1
                color: Theme.surface2
            }

            GText {
                x: 0
                y: parent.yy - 12
                width: root.plotX - 10
                height: 24
                horizontalAlignment: Text.AlignRight
                text: F.tok(root.maxV * modelData).replace(" ", "")
                color: GentooStyle.faint
            }
        }
    }

    Repeater {
        model: root.days

        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property real bh: modelData.tokens > 0 ? Math.max(4, root.plotH * modelData.tokens / root.maxV) : 0

            x: root.plotX + index * (root.barW + root.gap)
            y: root.plotH - bh
            width: root.barW
            height: bh
            radius: 4
            color: index === root.days.length - 1 ? Theme.blue : "#4a6aa8"
        }
    }

    Repeater {
        model: root.days.length ? [0, Math.floor((root.days.length - 1) / 2), root.days.length - 1] : []

        delegate: GText {
            required property int modelData
            required property int index
            readonly property real cx: root.plotX + modelData * (root.barW + root.gap) + root.barW / 2

            // the last label ends at the right edge, the first starts at the plot's left edge
            x: index === 0 ? root.plotX : index === 2 ? root.width - width : cx - width / 2
            y: root.plotH + 4
            height: 24
            text: root.days[modelData] ? F.dayLabel(root.days[modelData].d) : ""
            color: GentooStyle.faint
        }
    }
}
