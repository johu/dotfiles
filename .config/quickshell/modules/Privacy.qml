import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

RowLayout {
    spacing: 6
    visible: screenSharing || micInUse

    readonly property bool screenSharing: Pipewire.nodes.values.some(
        n => n.isStream && (n.type & PwNodeType.VideoSource) === PwNodeType.VideoSource
    )
    readonly property bool micInUse: Pipewire.nodes.values.some(
        n => n.isStream && (n.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream
    )

    Text {
        visible: parent.screenSharing
        text: "󰍹"
        color: Theme.mauve
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
    }

    Text {
        visible: parent.micInUse
        text: "󰍬"
        color: Theme.mauve
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
    }
}
