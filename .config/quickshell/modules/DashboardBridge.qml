pragma Singleton
import QtQuick

// Lets modules outside Dashboard.qml (e.g. NetworkIndicator) open it on a
// specific expand row without a direct reference.
QtObject {
    signal openNetworkRequested()
    signal openBluetoothRequested()
    // mode: "region" | "screen" | "window" | "record-region" | "record-screen" - handled by Capture.qml
    signal captureRequested(string mode)
}
