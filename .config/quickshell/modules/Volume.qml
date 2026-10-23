import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real volume: sink?.audio?.volume ?? 0

    implicitWidth: Math.max(28, label.implicitWidth + 12)
    implicitHeight: 28

    Text {
        id: label
        anchors.centerIn: parent

        text: {
            // waybar's muted icon (nf-fa-volume_mute, U+F6A9) isn't in this
            // font's installed charset (verified via fc-query) - reuse the
            // volume-off icon instead, which already reads as "silent".
            if (root.muted)
                return "\uf026 ";
            if (root.volume > 0.66)
                return "\uf028";
            if (root.volume > 0.0)
                return "\uf027";
            return "\uf026";
        }

        color: Theme.maroon
        font.family: Theme.fontFamily
        font.pixelSize: root.muted ? Theme.fontSize : Theme.iconFontSize
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                pavucontrol.running = true;
            }
        }
    }

    Process {
        id: pavucontrol
        command: ["pavucontrol"]
    }
}
