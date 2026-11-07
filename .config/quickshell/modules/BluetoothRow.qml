import QtQuick
import QtQuick.Layouts

// Expand section for Dashboard.qml's bluetooth card - no summary row of
// its own; Dashboard's bluetoothTile toggle (the grid icon) drives
// `expanded` directly, so this is purely the animated reveal +
// BluetoothCard content. Mirrors NetworkRow.qml.
ColumnLayout {
    id: root

    property bool expanded: false

    spacing: 0

    // Same reserve-then-fade sequencing as WeatherRow.qml/NetworkRow.qml -
    // see their comments for why this two-step (grow box, then fade
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

    BluetoothCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
    }
}
