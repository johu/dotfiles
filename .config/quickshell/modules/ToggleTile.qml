import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property color accentColor: Theme.blue

    // `enabled` is inherited from Item (default true) - false when the
    // underlying service/hardware isn't available (e.g. bluez not
    // running). Item.enabled already blocks input to descendants, so the
    // MouseArea doesn't need its own guard; this just also dims the tile.

    signal clicked
    signal rightClicked

    implicitWidth: 52
    implicitHeight: 52
    radius: Theme.radius / 2
    opacity: root.enabled ? 1 : 0.4
    color: root.active ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22) : Theme.surface2

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Text {
            // Fixed width + centered text instead of letting the glyph's
            // own implicitWidth drive the ColumnLayout's width - icons
            // that swap glyphs on state change (DND bell/bell-slash,
            // night-light sun/moon, WiFi signal strength) have different
            // natural widths per glyph, which resized the column and
            // re-centered the label underneath it on every toggle.
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.iconFontSize + 4
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: root.active ? root.accentColor : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: root.active ? root.accentColor : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 5
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
