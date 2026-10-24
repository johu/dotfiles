import QtQuick
import Quickshell

PanelWindow {
    id: root

    color: "transparent"
    exclusiveZone: 0
    implicitWidth: 280
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
            model: ToastManager.queue

            Toast {
                message: model.message
                icon: model.icon
                toastId: model.toastId
            }
        }
    }
}
