import QtQuick
import QtQuick.Layouts

// Per-stream row for AudioMixerCard.qml: app icon (click to mute, hover for
// name), volume slider and percent. Not built on SliderRow.qml, whose icon
// is a font glyph.
RowLayout {
    id: root

    property var node

    readonly property bool muted: root.node?.audio?.muted ?? false
    readonly property real volume: root.node?.audio?.volume ?? 0

    // Captured once per node, not a binding: reading .properties subscribes to
    // propertiesChanged, which fires ~2x/sec for a voice stream (pulse.corked
    // flips) and kept re-laying out the row, even mid-fade.
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
        // process.binary beats application.name: some apps set the latter to an
        // internal component (Discord: "WEBRTC VoiceEngine").
        root.appBinary = root.node.properties?.["application.process.binary"] || "";
        root.appName = root.appBinary || root.node.properties?.["application.name"] || root.node.description || root.node.name;
        root.pipewireIconName = root.node.properties?.["application.icon-name"] ?? "";
        root.appPid = root.node.properties?.["application.process.id"] ?? "";
    }

    onNodeChanged: root.captureIdentity()
    Component.onCompleted: root.captureIdentity()

    // A binary-derived .desktop icon beats PipeWire's: many apps never set
    // application.icon-name. Some (Spotify) set no binary either, so appName is
    // the second key to try.
    readonly property string lookupKey: root.appBinary || root.appName
    readonly property string appIconName: (root.lookupKey ? AppIconResolver.iconNameForBinary(root.lookupKey) : "") || root.pipewireIconName

    // Proton games have no .desktop entry; SteamGameIcon.qml finds the Steam
    // AppID via the process tree and returns an icon path, which wins.
    readonly property string steamIconPath: root.appPid ? SteamGameIcon.iconPathForPid(root.appPid) : ""

    // The same walk resolves the game's title from Steam's appmanifest, which
    // wins over the binary name in the tooltip.
    readonly property string steamGameName: root.appPid ? SteamGameIcon.gameNameForPid(root.appPid) : ""
    readonly property string displayName: root.steamGameName || root.appName

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
            renderType: Text.NativeRendering
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
            // Left-aligned to the icon: centering pushed long names past the card's
            // left edge, where `card` clips them.
            anchors.left: iconArea.left
            radius: 6
            // Same surface as the emerge tooltip; thin green outline, normal text.
            color: Theme.surface1
            border.width: 1
            border.color: Theme.green
            implicitWidth: tooltipText.implicitWidth + 16
            implicitHeight: tooltipText.implicitHeight + 8

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: root.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.small(-2)
                font.weight: Theme.smallWeight
                renderType: Text.NativeRendering
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
            color: Theme.blue
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
        font.pixelSize: Theme.small(-2)
        font.weight: Theme.smallWeight
        renderType: Text.NativeRendering
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
    }
}
