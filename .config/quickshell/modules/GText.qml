import QtQuick

// Text with the Gentoo view's defaults (font, zoom-aware render type).
Text {
    property int size: Theme.fontSize + 2
    property bool strong: false
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(size, Theme.fontSize + 2)
    renderType: GentooStyle.textRender
    font.weight: strong ? Font.Bold : Theme.smallWeight
    font.hintingPreference: Font.PreferFullHinting
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
