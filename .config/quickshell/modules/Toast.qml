import QtQuick
import QtQuick.Layouts

Pill {
    id: root

    property string message
    property string icon
    property int toastId

    opacity: 0

    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }

    Component.onCompleted: {
        opacity = 1;
        dismissTimer.start();
    }

    Timer {
        id: dismissTimer
        interval: 2500
        onTriggered: ToastManager.dismiss(root.toastId)
    }

    Text {
        visible: root.icon.length > 0
        text: root.icon
        color: Theme.green
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        font.bold: true
    }

    Text {
        text: root.message
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
