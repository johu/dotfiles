pragma Singleton
import QtQuick

// Lets modules outside Dashboard.qml (e.g. NetworkIndicator) open it on a
// specific expand row without a direct reference.
QtObject {
    signal openNetworkRequested()
    signal openBluetoothRequested()
    // mode: "region" | "screen" | "window" | "record-region" | "record-screen" - handled by Capture.qml
    // Also: "annotate" | "ocr" | "qr".
    signal captureRequested(string mode)

    // Toggles whose state lives in Dashboard.qml's hidden logic instances.
    // Dashboard mirrors the state here so other modules (the launcher) can
    // read it and request a toggle without a direct reference.
    property bool nightLightPresent: false
    property bool nightLightActive: false
    property bool idleInhibitActive: false
    signal toggleNightLightRequested()
    signal toggleIdleInhibitRequested()
}
