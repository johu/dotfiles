import QtQuick
import QtQuick.Layouts

// Expand section of the network card. No summary row: Dashboard's wifiTile
// drives `expanded`; this is the animated reveal of NetworkCard.
ColumnLayout {
    id: root

    property bool expanded: false
    readonly property bool pskActive: detailCard.pskActive

    spacing: 0

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

    NetworkCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
    }
}
