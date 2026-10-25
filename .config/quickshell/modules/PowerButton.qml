import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accentColor: Theme.text
    property var command: []

    signal activated

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.moduleHeight
    radius: Theme.radius
    // Between the dashboard card (Theme.surface1) and the toggle tiles
    // (Theme.surface2) - brighter than the card background, but not as
    // bright as a full surface2 tile.
    color: Qt.lighter(Theme.surface1, 1.3)

    RowLayout {
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.icon
            color: root.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize
            font.bold: true
        }

        Text {
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            proc.command = root.command;
            proc.running = true;
            root.activated();
        }
    }

    Process {
        id: proc
    }
}
