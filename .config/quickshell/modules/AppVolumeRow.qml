import QtQuick
import QtQuick.Layouts

// Per-stream row for AudioMixerCard.qml: app icon (click to mute) + name +
// draggable volume slider + percent. Not built on SliderRow.qml since its
// icon is a font glyph, not an app icon image (ResolvedIcon.qml).
RowLayout {
    id: root

    property var node

    readonly property bool muted: root.node?.audio?.muted ?? false
    readonly property real volume: root.node?.audio?.volume ?? 0

    // Not a `readonly property: root.node.properties?.[...]` binding -
    // reading .properties inside a binding auto-subscribes it to that
    // node's propertiesChanged, which for a voice-chat stream fires ~2x/sec
    // (Discord flips its own pulse.corked on every voice-activity edge,
    // confirmed via pw-dump) even though the *identity* fields never
    // actually change after the stream is created. That churn was forcing
    // this row's text/icon to re-layout constantly, including mid-fade
    // during AudioMixerRow's expand/collapse animation. Compute once per
    // node instead.
    property string appName: ""
    property string appIconName: ""

    function captureIdentity() {
        if (!root.node) {
            root.appName = "";
            root.appIconName = "";
            return;
        }
        // application.process.binary (the actual executable) wins over
        // application.name - some apps' webrtc/media engines set the latter
        // to their own internal component name instead of the app (e.g.
        // Discord's voice stream reports application.name "WEBRTC
        // VoiceEngine" but application.process.binary "Discord").
        root.appName = root.node.properties?.["application.process.binary"] || root.node.properties?.["application.name"] || root.node.description || root.node.name;
        root.appIconName = root.node.properties?.["application.icon-name"] ?? "";
    }

    onNodeChanged: root.captureIdentity()
    Component.onCompleted: root.captureIdentity()

    spacing: 10
    opacity: root.muted ? 0.5 : 1

    ResolvedIcon {
        iconSource: root.appIconName ? "image://icon/" + root.appIconName : ""
        size: Theme.iconFontSize
        Layout.preferredWidth: 20

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.node?.audio)
                root.node.audio.muted = !root.node.audio.muted
        }
    }

    Text {
        text: root.appName
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        Layout.preferredWidth: 70
        elide: Text.ElideRight
    }

    Rectangle {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        radius: 4
        color: Theme.surface2

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 4
            width: parent.width * Math.max(0, Math.min(1, root.volume))
            color: Theme.teal
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function emit(x) {
                if (root.node?.audio)
                    root.node.audio.volume = Math.max(0, Math.min(1, x / track.width));
            }

            onPressed: mouse => emit(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    emit(mouse.x);
            }
            onWheel: wheel => {
                if (!root.node?.audio)
                    return;
                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                root.node.audio.volume = Math.max(0, Math.min(1, root.volume + step));
            }
        }
    }

    Text {
        text: Math.round(root.volume * 100) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
    }
}
