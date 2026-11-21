import QtQuick

// Section header: blue title, dim right-aligned note and a rule underneath.
Item {
    id: root

    property string title: ""
    property string extra: ""

    implicitHeight: 34

    GText {
        text: root.title
        color: Theme.blue
        strong: true
        height: 28
    }

    GText {
        anchors.right: parent.right
        width: Math.max(0, parent.width - 200)
        horizontalAlignment: Text.AlignRight
        height: 28
        text: root.extra
        color: GentooStyle.faint
    }

    Rectangle {
        y: 31
        width: parent.width
        height: 1
        color: Theme.surface2
    }
}
