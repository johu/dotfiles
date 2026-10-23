import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real volume: sink?.audio?.volume ?? 0

    // PwNode.audio reads/writes are silent no-ops unless bound here.
    PwObjectTracker {
        objects: [root.sink]
    }

    // Suppresses the OSD for the initial volume/mute values Pipewire
    // reports right after startup.
    property bool osdReady: false

    implicitWidth: Math.max(28, label.implicitWidth + 12)
    implicitHeight: 28

    Timer {
        interval: 500
        running: true
        onTriggered: root.osdReady = true
    }

    onVolumeChanged: if (root.osdReady)
        osd.show(root, root.volume, root.muted)
    onMutedChanged: if (root.osdReady)
        osd.show(root, root.volume, root.muted)

    VolumeOsd {
        id: osd
    }

    Text {
        id: label
        anchors.centerIn: parent

        text: {
            // nf-fa-volume_mute isn't in this font's charset; volume-off
            // reads as "silent" too.
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
        hoverEnabled: true
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                mixer.running = true;
            }
        }
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.volume + step));
            if (step > 0)
                root.sink.audio.muted = false;
        }
    }

    Process {
        id: mixer
        command: ["pwvucontrol"]
    }
}
