import QtQuick
import QtQuick.Layouts

// Per-stream row for AudioMixerCard.qml: app icon (click to mute, hover
// for its name) + draggable volume slider + percent. Not built on
// SliderRow.qml since its icon is a font glyph, not an app icon image
// (ResolvedIcon.qml).
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
    property string appBinary: ""
    property string pipewireIconName: ""
    property string appPid: ""

    function captureIdentity() {
        if (!root.node) {
            root.appName = "";
            root.appBinary = "";
            root.pipewireIconName = "";
            root.appPid = "";
            return;
        }
        // application.process.binary (the actual executable) wins over
        // application.name - some apps' webrtc/media engines set the latter
        // to their own internal component name instead of the app (e.g.
        // Discord's voice stream reports application.name "WEBRTC
        // VoiceEngine" but application.process.binary "Discord").
        root.appBinary = root.node.properties?.["application.process.binary"] || "";
        root.appName = root.appBinary || root.node.properties?.["application.name"] || root.node.description || root.node.name;
        root.pipewireIconName = root.node.properties?.["application.icon-name"] ?? "";
        root.appPid = root.node.properties?.["application.process.id"] ?? "";
    }

    onNodeChanged: root.captureIdentity()
    Component.onCompleted: root.captureIdentity()

    // Binary-derived (.desktop file) icon wins over whatever PipeWire
    // itself reports - several apps (Discord included) never set
    // application.icon-name at all, so that fallback was blank far more
    // often than it resolved. AppIconResolver.qml does the actual lookup.
    // Some apps (Spotify, confirmed via pw-dump) don't set
    // application.process.binary either - appName is still the display
    // app name in that case (see captureIdentity above), and "Spotify"
    // resolves to spotify.desktop just as well as a real binary name
    // would, so it's a reasonable second key to try.
    readonly property string lookupKey: root.appBinary || root.appName
    readonly property string appIconName: (root.lookupKey ? AppIconResolver.iconNameForBinary(root.lookupKey) : "") || root.pipewireIconName

    // Proton games (wine64-preloader, <Game>.exe) have no .desktop entry
    // to match at all - SteamGameIcon.qml walks the process tree for a
    // Steam AppID instead and returns a real icon file path, which wins
    // over both the theme-name lookups above when present.
    readonly property string steamIconPath: root.appPid ? SteamGameIcon.iconPathForPid(root.appPid) : ""

    spacing: 10
    opacity: root.muted ? 0.5 : 1

    Item {
        id: iconArea
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        z: iconHover.containsMouse ? 1 : 0

        Image {
            visible: root.steamIconPath.length > 0
            anchors.centerIn: parent
            width: Theme.iconFontSize
            height: Theme.iconFontSize
            sourceSize.width: Theme.iconFontSize
            sourceSize.height: Theme.iconFontSize
            fillMode: Image.PreserveAspectFit
            source: root.steamIconPath ? "file://" + root.steamIconPath : ""
        }

        ResolvedIcon {
            visible: root.steamIconPath.length === 0 && root.appIconName.length > 0
            anchors.centerIn: parent
            iconSource: root.appIconName ? "image://icon/" + root.appIconName : ""
            size: Theme.iconFontSize
        }

        Text {
            visible: root.steamIconPath.length === 0 && root.appIconName.length === 0
            anchors.centerIn: parent
            text: "\uf108"
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconFontSize
        }

        MouseArea {
            id: iconHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.node?.audio)
                root.node.audio.muted = !root.node.audio.muted
        }

        Rectangle {
            visible: iconHover.containsMouse
            anchors.bottom: iconArea.top
            anchors.bottomMargin: 4
            // Left-aligned to the icon rather than centered - centering
            // pushed longer names (e.g. "wine64-preloader") past the
            // card's left edge, where they got clipped by Dashboard.qml's
            // `card` Rectangle (clip: true). There's always room to grow
            // right, never much room to grow left this close to the
            // card's own left margin.
            anchors.left: iconArea.left
            radius: 6
            color: Theme.surface2
            implicitWidth: tooltipText.implicitWidth + 16
            implicitHeight: tooltipText.implicitHeight + 8

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: root.appName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
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
