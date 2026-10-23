import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias content: layout.data
    property int horizontalPadding: 15
    property int leftPadding: horizontalPadding
    property int rightPadding: horizontalPadding
    property int spacing: 10

    radius: Theme.radius
    color: Theme.surface1
    implicitHeight: Theme.moduleHeight
    implicitWidth: layout.implicitWidth + leftPadding + rightPadding

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
        spacing: root.spacing
    }
}
