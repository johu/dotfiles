import QtQuick
import QtQuick.Layouts

Text {
    id: root

    text: "\uf0ea"
    color: Theme.subtext1
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    font.bold: true
    verticalAlignment: Text.AlignVCenter
    Layout.preferredHeight: Theme.moduleHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (picker.visible)
                picker.visible = false;
            else
                picker.open(root);
        }
    }

    ClipboardPicker {
        id: picker
    }
}
