import QtQuick
import QtQuick.Layouts

// Current-conditions summary; click expands the WeatherCard. Reads the
// WeatherData singleton directly.
ColumnLayout {
    id: root

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
                    renderType: Text.NativeRendering
                    font.bold: true
                }

                Text {
                    // Layout.fillWidth + elide is required, not cosmetic: without it,
                    // QtQuick.Layouts mis-positions the icon column by a varying offset. Pair
                    // them on dynamic-width subtitles (as AudioMixerRow/SystemResourcesRow).
                    Layout.fillWidth: true
                    text: WeatherData.loaded ? (WeatherData.currentTemp + "\u00b0C, " + WeatherData.descriptionForCode(WeatherData.currentCode)) : "Loading\u2026"
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

    // Reserve-then-fade sequencing as in SystemResourcesRow.qml.
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
