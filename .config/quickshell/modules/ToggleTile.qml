import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    // Shown instead of `icon` when set (an SVG where no nerd font glyph works,
    // e.g. NightLight's "day"). Empty falls back to the glyph.
    property string iconSource: ""
    property bool active: false
    property color accentColor: Theme.blue

    // `enabled` is false when the service/hardware is unavailable; Item.enabled
    // already blocks input, this also dims the tile.

    signal clicked
    signal rightClicked

    implicitWidth: 44
    implicitHeight: 44
    radius: Theme.radius / 2
    opacity: root.enabled ? 1 : 0.4
    color: root.active ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) : Theme.surface2

    Item {
        anchors.centerIn: parent
        width: Theme.iconFontSize + 6
        height: Theme.iconFontSize + 6

        Text {
            anchors.centerIn: parent
            visible: root.iconSource === ""
            text: root.icon
            color: root.active ? root.accentColor : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize + 6
            renderType: Text.NativeRendering
            font.bold: true
        }

        Image {
            anchors.centerIn: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            width: Theme.iconFontSize + 6
            height: Theme.iconFontSize + 6
            sourceSize.width: Theme.iconFontSize + 6
            sourceSize.height: Theme.iconFontSize + 6
            fillMode: Image.PreserveAspectFit
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.clicked();
            else
                root.rightClicked();
        }
    }
}
