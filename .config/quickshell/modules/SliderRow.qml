import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string icon: ""
    property color accentColor: Theme.teal
    property real value: 0

    signal moved(real value)

    spacing: 10

    Text {
        text: root.icon
        color: root.accentColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        font.bold: true
        Layout.preferredWidth: 20
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        radius: 4
        color: Theme.surface2

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 4
            width: parent.width * Math.max(0, Math.min(1, root.value))
            color: root.accentColor
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function emit(x) {
                root.moved(Math.max(0, Math.min(1, x / track.width)));
            }

            onPressed: mouse => emit(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    emit(mouse.x);
            }
            onWheel: wheel => {
                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                root.moved(Math.max(0, Math.min(1, root.value + step)));
            }
        }
    }

    Text {
        text: Math.round(root.value * 100) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
    }
}
