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
        onClicked: PopupManager.toggle("clipboard")
    }

    PopupBehavior {
        name: "clipboard"
        popup: picker
        openFn: () => picker.open(root)
    }

    ClipboardPicker {
        id: picker
    }
}
