import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Fixed width: the bell and bell-slash glyphs differ in width, and tracking
    // implicitWidth resized the Pill on every DND toggle.
    implicitWidth: Theme.iconFontSize
    implicitHeight: Theme.moduleHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: Theme.moduleHeight

    readonly property int unread: Notifications.unreadCount

    Text {
        id: bellText
        width: Theme.iconFontSize
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
        text: Notifications.dnd ? "\uf1f7" : "\uf0a2"
        color: Notifications.dnd ? Theme.red : (root.unread > 0 ? Theme.blue : Theme.subtext1)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        renderType: Text.NativeRendering
        font.bold: true
    }

    Rectangle {
        visible: root.unread > 0 && !Notifications.dnd
        width: 14
        height: 14
        radius: 7
        color: Theme.red
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -2
        anchors.rightMargin: -4

        Text {
            anchors.centerIn: parent
            text: root.unread > 9 ? "9+" : String(root.unread)
            color: Theme.base
            font.family: Theme.fontFamily
            font.pixelSize: Theme.minFontSize - 2
            renderType: Text.NativeRendering
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                PopupManager.toggle("notifications");
            else
                Notifications.dnd = !Notifications.dnd;
        }
    }

    NotificationHistory {
        id: history
    }

    PopupBehavior {
        name: "notifications"
        popup: history
        openFn: () => history.open(root)
    }
}
