import QtQuick

// Shared cover-art square for MediaHoverPopup/MediaExpandCard.
// Not every player exposes mpris:artUrl as a file:// URI Image can load
// directly (some are http:// covers needing a real fetch) - guard with
// visible: artUrl !== "" and a fallback glyph instead of letting Image
// silently fail to nothing.
Rectangle {
    id: root

    property string artUrl: ""

    radius: 10
    color: Theme.surface2
    clip: true

    Image {
        id: art
        anchors.fill: parent
        visible: root.artUrl !== "" && status === Image.Ready
        source: root.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Text {
        anchors.centerIn: parent
        visible: !art.visible
        text: "\uf001"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.width * 0.35)
    }
}
