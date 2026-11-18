import QtQuick
import QtQuick.Shapes

// Donut chart: slices = [{ value, color }], with a big center number and a small caption.
// Drawn with Shapes (a Canvas loses its content when the window is unmapped on a workspace switch).
Item {
    id: donut

    property var slices: []
    property string center: ""
    property string caption: ""
    property int thickness: 26

    readonly property real total: slices.reduce((a, s) => a + s.value, 0)
    readonly property real radius: Math.min(width, height) / 2 - thickness / 2 - 1
    readonly property var arcs: {
        const out = [];
        let a = 0;
        const minSweep = 5;
        let sum = 0;
        for (const s of slices)
            if (s.value > 0)
                sum += Math.max(s.value / total * 360, minSweep);
        const k = total > 0 ? 360 / sum : 1;
        for (const s of slices) {
            if (s.value <= 0)
                continue;
            const sweep = Math.max(s.value / total * 360, minSweep) * k;
            out.push({ start: a, sweep: Math.max(sweep - 1.5, 0.5), color: s.color });
            a += sweep;
        }
        return out;
    }

    Shape {
        anchors.fill: parent
        visible: donut.total <= 0

        ShapePath {
            strokeColor: Theme.surface2
            strokeWidth: donut.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: donut.width / 2
                centerY: donut.height / 2
                radiusX: donut.radius
                radiusY: donut.radius
                startAngle: 0
                sweepAngle: 359.9
            }
        }
    }

    Repeater {
        model: donut.arcs

        Shape {
            required property var modelData

            anchors.fill: donut
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: modelData.color
                strokeWidth: donut.thickness
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: donut.width / 2
                    centerY: donut.height / 2
                    radiusX: donut.radius
                    radiusY: donut.radius
                    startAngle: modelData.start - 90
                    sweepAngle: modelData.sweep
                }
            }
        }
    }

    GText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height / 2 - height / 2 - 10)
        height: implicitHeight
        text: donut.center
        size: Math.round((donut.width - 2 * donut.thickness) * 0.27)
        strong: true
        elide: Text.ElideNone
    }

    GText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height / 2 + (donut.width - 2 * donut.thickness) * 0.16)
        height: implicitHeight
        text: donut.caption
        color: GentooStyle.dim
        size: Theme.fontSize
    }
}
