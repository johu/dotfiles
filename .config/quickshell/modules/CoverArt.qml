import QtQuick

// Cover-art square shared by MediaHoverPopup/MediaExpandCard. artUrl may be
// an http:// cover that Image can't load directly, so show a fallback
// glyph when it's empty.
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
        renderType: Text.NativeRendering
    }
}
