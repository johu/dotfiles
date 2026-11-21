import QtQuick
import "AiUsageFmt.js" as F

// One rate-limit meter: title, percent, reset time and a bar. The colour follows the dashboard card
// (green below 70 %, yellow below 90 %, red above). percent < 0 = unknown.
Item {
    id: root

    property string title: ""
    property real percent: -1
    property string resetsAt: ""
    property string message: ""

    readonly property color accent: root.percent >= 90 ? Theme.red : root.percent >= 70 ? Theme.yellow : Theme.green

    implicitHeight: 84

    GText {
        text: root.title
        color: GentooStyle.dim
        anchors.left: parent.left
        y: 0
        height: 26
    }

    GText {
        visible: root.percent >= 0
        text: Math.round(root.percent) + " %"
        strong: true
        size: 26
        color: root.accent
        anchors.right: parent.right
        y: -2
        height: 30
    }

    GText {
        text: root.percent >= 0 ? (root.resetsAt ? "resets " + F.resetsIn(root.resetsAt) : "") : root.message
        color: GentooStyle.faint
        anchors.left: parent.left
        anchors.right: parent.right
        y: 28
        height: 24
    }

    Rectangle {
        x: 0
        y: 60
        width: parent.width
        height: 16
        radius: 8
        color: GentooStyle.cardColor

        Rectangle {
            visible: root.percent >= 0
            width: Math.max(parent.height, parent.width * Math.min(100, root.percent) / 100)
            height: parent.height
            radius: 8
            color: root.accent
        }
    }
}
