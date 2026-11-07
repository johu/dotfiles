import QtQuick
import QtQuick.Layouts

// Expand section for Dashboard.qml's network card - no summary row of its
// own; Dashboard's wifiTile toggle (the grid icon) drives `expanded`
// directly, so this is purely the animated reveal + NetworkCard content.
ColumnLayout {
    id: root

    property bool expanded: false
    readonly property bool pskActive: detailCard.pskActive

    spacing: 0

    // Same reserve-then-fade sequencing as WeatherRow.qml/
    // SystemResourcesRow.qml - see their comments for why this two-step
    // (grow box, then fade content in) is needed instead of a plain
    // opacity Behavior.
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

    NetworkCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
    }
}
