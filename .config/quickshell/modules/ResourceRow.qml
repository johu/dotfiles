import QtQuick
import QtQuick.Layouts

// Single icon+bar+value row for SystemResourcesCard.qml. Static explicit
// instances (not a Repeater over an inline array literal) - an array
// literal referencing polled properties gets a new identity on every poll
// tick, which made the Repeater destroy and recreate every delegate each
// time and flicker continuously while visible.
//
// Root is a plain Item (not a RowLayout) so a full-row MouseArea can sit
// on top for the optional hover tooltip without becoming a layout child
// itself and stealing a column slot.
Item {
    id: root

    property string icon: ""
    // When set, rendered instead of `icon` as an image (e.g. a custom SVG
    // asset for a glyph the font doesn't provide, like RAM) - same pattern
    // as ToggleTile's iconSource. Empty string falls back to the `icon` glyph.
    property string iconSource: ""
    property string value: ""
    // Optional longer-form text shown in a hover tooltip above the row
    // (e.g. disk's "213G / 437G") - keeps `value` itself short so the bar
    // next to it can stay wide. Empty string disables the tooltip.
    property string tooltip: ""
    property real percent: -1
    property color accentColor: Theme.text

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // Fixed-size slot the icon is centered inside, instead of relying
        // on Layout.alignment against the Text/Image's own implicit size -
        // same pattern as AppVolumeRow.qml's iconArea (that row's icons are
        // correctly centered; this one wasn't, with icon glyphs and the
        // thin bar landing at slightly different vertical centers).
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20

            Text {
                anchors.centerIn: parent
                visible: root.iconSource === ""
                text: root.icon
                color: root.accentColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize
                font.bold: true
            }

            Image {
                anchors.centerIn: parent
                visible: root.iconSource !== ""
                source: root.iconSource
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
            }
        }

        Rectangle {
            // Matches SliderRow.qml's track exactly (height 8, radius 4) so
            // these bars read as the same length/weight as the volume sliders.
            visible: root.percent >= 0
            Layout.fillWidth: true
            Layout.preferredWidth: 100
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter
            height: 8
            radius: 4
            // Theme.surface1, not surface2 like SliderRow's track - this
            // card's own background is surface2, so surface2 here made the
            // empty portion invisible against it.
            color: Theme.surface1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 4
                width: parent.width * (root.percent / 100)
                color: root.accentColor
            }
        }

        Item {
            visible: root.percent < 0
            Layout.fillWidth: true
            Layout.preferredWidth: 100
        }

        Text {
            // Matches SliderRow.qml's value column width.
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 36
            Layout.minimumWidth: 36
            text: root.value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            horizontalAlignment: Text.AlignRight
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.tooltip.length > 0
        cursorShape: Qt.ArrowCursor
    }

    Rectangle {
        visible: hoverArea.containsMouse && root.tooltip.length > 0
        z: 10
        anchors.bottom: parent.top
        anchors.bottomMargin: 4
        // Left-aligned to the row rather than right - right-aligned grew the
        // box leftward, which clipped long text (the CPU tooltip's model
        // name) past the card's left edge. Same reasoning as AppVolumeRow's
        // icon tooltip: there's always room to grow right, never much room
        // to grow left this close to the card's own left margin.
        anchors.left: parent.left
        radius: 6
        // Lighter than the detail card (Theme.surface2) it sits on top of,
        // so the popover reads as elevated instead of blending in.
        color: Qt.lighter(Theme.surface2, 1.4)
        implicitWidth: tooltipText.implicitWidth + 16
        implicitHeight: tooltipText.implicitHeight + 8

        Text {
            id: tooltipText
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignLeft
            text: root.tooltip
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
