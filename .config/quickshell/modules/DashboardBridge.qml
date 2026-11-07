pragma Singleton
import QtQuick

// Lets modules outside Dashboard.qml (e.g. NetworkIndicator.qml's bar
// glyph) ask it to open and jump to a specific expand row, without
// needing a direct reference to the Dashboard instance Settings.qml owns.
QtObject {
    signal openNetworkRequested()
}
