import QtQuick
import Quickshell

// Reusable "nothing here" placeholder: a flat illustration, a title and a
// dimmer hint line, centered as one block. Used by the launcher views (and
// meant for bar popups that can run empty). The illustrations live in
// assets/empty/ (hand-drawn SVGs in the Tokyonight palette).
Item {
    id: root

    property string illustration: ""   // file name inside assets/empty/
    property string title: ""
    property string hint: ""
    property int imageSize: 220
    property int titleSize: Theme.fontSize + 8
    property int hintSize: Theme.fontSize + 2
    property int gap: 12
    property int textRender: Text.NativeRendering

    implicitWidth: Math.max(root.imageSize, titleText.implicitWidth, hintText.implicitWidth)
    implicitHeight: column.implicitHeight

    Column {
        id: column

        anchors.centerIn: parent
        spacing: root.gap

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.illustration !== ""
            width: root.imageSize
            height: root.imageSize
            source: root.illustration !== "" ? "file://" + Quickshell.shellPath("assets/empty/" + root.illustration) : ""
            sourceSize: Qt.size(root.imageSize * 2, root.imageSize * 2)
            fillMode: Image.PreserveAspectFit
        }

        Text {
            id: titleText

            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: root.titleSize
            font.bold: true
            renderType: root.textRender
        }

        Text {
            id: hintText

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.hint !== ""
            text: root.hint
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: root.hintSize
            renderType: root.textRender
        }
    }
}
