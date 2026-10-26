import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: root

    property var notif

    implicitWidth: 320
    implicitHeight: column.implicitHeight + 16
    radius: Theme.radius
    color: Theme.surface1

    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }
    Component.onCompleted: opacity = 1

    readonly property string accent: notif.urgency === NotificationUrgency.Critical ? Theme.red : (notif.urgency === NotificationUrgency.Low ? Theme.subtext1 : Theme.blue)

    Rectangle {
        width: 3
        radius: 1.5
        color: root.accent
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 8
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        anchors.rightMargin: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ResolvedIcon {
                visible: root.notif.appIcon.length > 0
                iconSource: "image://icon/" + root.notif.appIcon
                size: 16
            }

            Text {
                Layout.fillWidth: true
                text: root.notif.appName
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
            }

            Text {
                text: "\uf00d"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize - 2

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismissPopup(root.notif.key)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.notif.summary
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            wrapMode: Text.Wrap
        }

        Text {
            visible: root.notif.body.length > 0
            Layout.fillWidth: true
            text: root.notif.body
            textFormat: Text.PlainText
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Image {
            visible: root.notif.image.length > 0
            source: root.notif.image
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            fillMode: Image.PreserveAspectCrop
        }

        RowLayout {
            visible: root.notif.actions.length > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.notif.actions

                Rectangle {
                    radius: Theme.radius / 2
                    color: Theme.surface2
                    implicitWidth: actionText.implicitWidth + 16
                    implicitHeight: actionText.implicitHeight + 8

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.invokeAction(root.notif.key, modelData.identifier)
                    }
                }
            }
        }
    }
}
