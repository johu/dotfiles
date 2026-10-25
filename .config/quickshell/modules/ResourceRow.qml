import QtQuick
import QtQuick.Layouts

// Single icon+label+bar+value row for SystemResourcesCard.qml. Static
// explicit instances (not a Repeater over an inline array literal) - an
// array literal referencing polled properties gets a new identity on
// every poll tick, which made the Repeater destroy and recreate every
// delegate each time and flicker continuously while visible.
RowLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property real percent: -1
    property color accentColor: Theme.text

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: root.icon
        color: root.accentColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        font.bold: true
        Layout.preferredWidth: 20
    }

    Text {
        text: root.label
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        Layout.preferredWidth: 34
    }

    Rectangle {
        visible: root.percent >= 0
        Layout.fillWidth: true
        Layout.preferredWidth: 100
        height: 6
        radius: 3
        color: Theme.surface1

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 3
            width: parent.width * (root.percent / 100)
            color: root.accentColor
        }
    }

    Item {
        visible: root.percent < 0
        Layout.fillWidth: true
        Layout.preferredWidth: 100
    }

    Text {
        text: root.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        Layout.preferredWidth: 46
        horizontalAlignment: Text.AlignRight
    }
}
