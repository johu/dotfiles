import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    // When set, rendered instead of `icon` as an image (e.g. a custom SVG
    // asset for a glyph no nerd font provides cleanly) - see NightLight's
    // "day" state. Empty string falls back to the `icon` glyph.
    property string iconSource: ""
    property bool active: false
    property color accentColor: Theme.blue

    // `enabled` is inherited from Item (default true) - false when the
    // underlying service/hardware isn't available (e.g. bluez not
    // running). Item.enabled already blocks input to descendants, so the
    // MouseArea doesn't need its own guard; this just also dims the tile.

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
