import QtQuick
import QtQuick.Layouts

// Always-visible per-app audio summary for Dashboard.qml; click toggles
// the detailed AudioMixerCard (per-app volume sliders) below it. Backed
// by an invisible AudioMixer {} logic instance owned by the caller.
// Mirrors SystemResourcesRow.qml's summary/expand/fade shape.
ColumnLayout {
    id: root

    property var streams: []
    property string summaryText: ""
    property bool expanded: false

    spacing: 6

    Rectangle {
        Layout.fillWidth: true
        // Matches the Lock/Logout/Reboot row's PowerButton background.
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
                color: Theme.teal
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Audio mixer"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.summaryText
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
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

    // See SystemResourcesRow.qml for why expand/collapse is split into a
    // grow-then-fade-in / fade-out-then-shrink sequence via `reserved`.
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
        // Matches Dashboard.qml's card height Behavior duration, so the
        // box has finished growing before content starts fading in.
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
