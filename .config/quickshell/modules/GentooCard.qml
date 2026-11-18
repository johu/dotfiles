import QtQuick

// A rounded card with a colored title and an optional number chip (the jump key).
Rectangle {
    id: card

    property string title: ""
    property color accent: Theme.blue
    property string number: ""
    property bool selected: false

    radius: 16
    color: GentooStyle.cardColor
    border.width: selected ? 2 : 1
    border.color: selected ? accent : Theme.surface2

    GText {
        x: 24
        y: 14
        height: 30
        text: card.title
        color: card.accent
        strong: true
        size: Theme.fontSize + 3
    }

    Rectangle {
        visible: card.number !== ""
        x: parent.width - width - 14
        y: 14
        width: 26
        height: 26
        radius: 6
        color: Theme.surface2

        GText {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            text: card.number
            color: Theme.subtext1
            size: Theme.fontSize
        }
    }
}
