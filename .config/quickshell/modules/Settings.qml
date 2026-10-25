import QtQuick
import QtQuick.Layouts

Text {
    id: root

    text: "\uf013"
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
            if (dashboard.visible)
                dashboard.visible = false;
            else
                dashboard.open(root);
        }
    }

    Dashboard {
        id: dashboard
    }
}
