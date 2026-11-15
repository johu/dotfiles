import QtQuick

// Spectrum bars from an array of 0..100 levels (cava ascii output).
// `mirror` blends between bars growing up from the bottom edge (0) and bars
// growing both ways from the vertical middle (1), so one component can be a
// quiet backdrop and a full-screen visualizer by animating its geometry and
// `mirror`.
Item {
    id: root

    property var levels: []
    property int count: 64
    property real mirror: 0
    property real gap: 0.35
    // The green of the bar's visualizer pill, fading to teal.
    property color colorA: Theme.green
    property color colorB: Theme.teal

    readonly property real slot: width / Math.max(1, root.count)

    Repeater {
        model: root.count

        Rectangle {
            id: bar

            required property int index

            readonly property real level: (root.levels[bar.index] ?? 0) / 100
            readonly property real t: bar.index / Math.max(1, root.count - 1)

            x: bar.index * root.slot
            width: Math.max(2, root.slot * (1 - root.gap))
            radius: Math.min(width / 2, 5)
            height: Math.max(4, bar.level * root.height)
            y: (root.height - height) * (1 - root.mirror / 2)
            color: Qt.rgba(root.colorA.r + (root.colorB.r - root.colorA.r) * bar.t, root.colorA.g + (root.colorB.g - root.colorA.g) * bar.t, root.colorA.b + (root.colorB.b - root.colorA.b) * bar.t, 1)

            Behavior on height {
                NumberAnimation {
                    duration: 80
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
