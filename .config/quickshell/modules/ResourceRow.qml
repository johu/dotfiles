import QtQuick
import QtQuick.Layouts

// Icon+bar+value row for SystemResourcesCard.qml. Static instances, not a
// Repeater over an array literal: that gets a new identity every poll and
// recreates every delegate, flickering.
//
// Root is a plain Item so a full-row MouseArea (hover tooltip) isn't a
// layout child stealing a column slot.
Item {
    id: root

    property string icon: ""
    // Shown instead of `icon` when set (e.g. an SVG for RAM, which the font
    // lacks). Empty falls back to the glyph.
    property string iconSource: ""
    property string value: ""
    // Longer text for a hover tooltip (e.g. disk "213G / 437G"), keeping `value`
    // short so the bar stays wide. Empty disables it.
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

        // Fixed-size slot to center the icon; Layout.alignment on the implicit
        // size left glyph and bar at slightly different vertical centers.
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
                renderType: Text.NativeRendering
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
            // Matches SliderRow's track (height 8, radius 4).
            visible: root.percent >= 0
            Layout.fillWidth: true
            Layout.preferredWidth: 100
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter
            height: 8
            radius: 4
            // surface1, not surface2: the card itself is surface2, which hid the empty
            // part.
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
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 36
            Layout.minimumWidth: 36
            text: root.value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.small(-2)
            font.weight: Theme.smallWeight
            renderType: Text.NativeRendering
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
        // Left-aligned: right-aligned grew leftward and clipped long text (CPU
        // model) past the card edge.
        anchors.left: parent.left
        radius: 6
        // Lighter than the detail card so the popover reads as elevated.
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
            font.pixelSize: Theme.small(-2)
            font.weight: Theme.smallWeight
            renderType: Text.NativeRendering
        }
    }
}
