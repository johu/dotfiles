import QtQuick
import QtQuick.Shapes
import "SysMonFormat.js" as Fmt

// History graph: up to three series drawn as filled lines, newest on the
// right. `maxValue` 0 means auto-scale to a round number. `compact` is the
// sidebar sparkline (no grid, no labels).
Item {
    id: root

    // [{ values: [numbers, newest last], color: "#rrggbb" }]
    property var series: []
    property real maxValue: 100
    property string unit: "%"
    property int samples: 60
    property bool compact: false
    property int textRender: Text.NativeRendering

    readonly property int labelW: root.compact ? 0 : 76
    readonly property real plotX: root.labelW
    readonly property real plotY: root.compact ? 2 : 10
    readonly property real plotW: root.width - root.plotX - (root.compact ? 0 : 12)
    readonly property real plotH: root.height - root.plotY - (root.compact ? 2 : 30)

    readonly property real maxEff: {
        if (root.maxValue > 0)
            return root.maxValue;
        let m = 0;
        for (const s of root.series)
            for (const v of (s.values ?? []).slice(-root.samples))
                m = Math.max(m, v);
        return Fmt.niceMax(m * 1.1);
    }

    // grid + axis labels
    Repeater {
        model: root.compact ? 0 : 5

        Item {
            required property int index

            Rectangle {
                x: root.plotX
                y: root.plotY + root.plotH * index / 4
                width: root.plotW
                height: 1
                color: Theme.surface2
                opacity: index === 4 ? 1 : 0.6
            }

            Text {
                x: 0
                y: root.plotY + root.plotH * index / 4 - 9
                width: root.labelW - 10
                height: 18
                horizontalAlignment: Text.AlignRight
                text: Fmt.axis(root.maxEff * (4 - index) / 4, root.unit)
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                renderType: root.textRender
            }
        }
    }

    Repeater {
        model: root.series

        Shape {
            id: shape

            required property var modelData
            required property int index

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property var line: {
                const v = shape.modelData.values ?? [];
                const n = Math.min(v.length, root.samples);
                if (n < 2)
                    return [];
                const step = root.plotW / (root.samples - 1);
                const pts = [];
                for (let i = 0; i < n; i++) {
                    const val = Math.max(0, Math.min(1, v[v.length - n + i] / root.maxEff));
                    pts.push(Qt.point(root.plotX + root.plotW - (n - 1 - i) * step, root.plotY + root.plotH * (1 - val)));
                }
                return pts;
            }
            readonly property var area: shape.line.length < 2 ? [] : [Qt.point(shape.line[0].x, root.plotY + root.plotH)].concat(shape.line, [Qt.point(shape.line[shape.line.length - 1].x, root.plotY + root.plotH)])

            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.rgba(Qt.color(shape.modelData.color).r, Qt.color(shape.modelData.color).g, Qt.color(shape.modelData.color).b, shape.index === 0 ? 0.28 : 0.14)

                PathPolyline {
                    path: shape.area
                }
            }

            ShapePath {
                strokeColor: shape.modelData.color
                strokeWidth: root.compact ? 2 : 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: shape.line
                }
            }
        }
    }

    // time axis
    Text {
        visible: !root.compact
        x: root.plotX
        y: root.height - 22
        text: (root.samples >= 60 ? Math.round(root.samples / 60) + " min" : root.samples + " s") + " ago"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        renderType: root.textRender
    }

    Text {
        visible: !root.compact
        x: root.width - width - 12
        y: root.height - 22
        text: "now"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        renderType: root.textRender
    }
}
