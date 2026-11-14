import QtQuick
import QtQuick.Layouts

// Per-app audio summary; click expands the AudioMixerCard. Backed by an
// invisible AudioMixer {} owned by the caller. Same shape as
// SystemResourcesRow.qml.
ColumnLayout {
    id: root

    property var streams: []
    property string summaryText: ""
    property bool expanded: false

    spacing: 6

    Rectangle {
        Layout.fillWidth: true
        color: Qt.lighter(Theme.surface1, 1.3)
        radius: Theme.radius
        implicitHeight: summaryRow.implicitHeight + 16

        RowLayout {
            id: summaryRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            Text {
                text: "\uf028"
                color: Theme.blue
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize
                renderType: Text.NativeRendering
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Sound"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.summaryText
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-2)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Expand/collapse sequencing via `reserved`: see SystemResourcesRow.qml.
    property bool reserved: false

    onExpandedChanged: {
        if (root.expanded) {
            fadeOut.stop();
            root.reserved = true;
            growDelay.restart();
        } else {
            growDelay.stop();
            fadeIn.stop();
            fadeOut.restart();
        }
    }

    Timer {
        id: growDelay
        // Matches Dashboard's card height Behavior, so the box finishes growing
        // before the content fades in.
        interval: 180
        onTriggered: fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: detailCard
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: detailCard
        property: "opacity"
        to: 0
        duration: 150
        easing.type: Easing.OutCubic
        onStopped: if (!root.expanded)
            root.reserved = false
    }

    AudioMixerCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
        streams: root.streams
    }
}
