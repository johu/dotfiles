import QtQuick

Item {
    id: root
    implicitWidth: Math.max(28, label.implicitWidth + 12)
    implicitHeight: 28

    Text {
        id: label
        anchors.centerIn: parent
        text: "\uf30d"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: launcher.toggle()
    }

    Launcher {
        id: launcher
    }
}
