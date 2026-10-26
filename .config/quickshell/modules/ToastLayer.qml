import QtQuick
import Quickshell

PanelWindow {
    id: root

    color: "transparent"
    exclusiveZone: 0
    implicitWidth: column.implicitWidth + 16
    implicitHeight: column.implicitHeight + 16

    anchors {
        top: true
        right: true
    }

    Column {
        id: column
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 8

        Repeater {
            model: Notifications.popups

            NotificationCard {
                notif: modelData
            }
        }

        Repeater {
            model: ToastManager.queue

            Toast {
                message: model.message
                icon: model.icon
                toastId: model.toastId
            }
        }
    }
}
