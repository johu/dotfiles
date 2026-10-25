import QtQuick
import QtQuick.Layouts

// Always-visible current-conditions summary for Dashboard.qml; click
// toggles the detailed WeatherCard (today + next 3 days) below it. Reads
// straight from the WeatherData singleton - no logic instance needed,
// same as Calendar.qml reading CalendarEvents directly.
ColumnLayout {
    id: root

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

            Image {
                source: "file://" + WeatherData.imageForCode(WeatherData.currentCode, WeatherData.currentIsDay)
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Weather"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    // Layout.fillWidth + elide here isn't just cosmetic
                    // overflow handling - omitting it (confirmed via
                    // bisection, not guessed) makes QtQuick.Layouts
                    // mis-position the ICON column to this Text's left by
                    // an extra, non-constant offset. Always pair a dynamic-
                    // width subtitle Text in one of these summary rows with
                    // both properties, matching AudioMixerRow/
                    // SystemResourcesRow's established pattern.
                    Layout.fillWidth: true
                    text: WeatherData.loaded ? (WeatherData.currentTemp + "\u00b0C, " + WeatherData.descriptionForCode(WeatherData.currentCode)) : "Loading\u2026"
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

    // Same reserve-then-fade sequencing as SystemResourcesRow.qml - see
    // that file's comment for why this two-step (grow box, then fade
    // content in) is needed instead of a plain opacity Behavior.
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

    WeatherCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
    }
}
