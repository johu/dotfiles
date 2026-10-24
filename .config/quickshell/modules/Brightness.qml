import QtQuick
import Quickshell.Io

Item {
    id: root

    // Single-monitor setup (see shell.qml): a desktop with an external DP
    // monitor and no laptop backlight. Hyprland's sdrbrightness looked like
    // a fit but is an SDR-under-HDR reference-luminance knob only — it has
    // no visible effect on a plain `cm = srgb` desktop (readback changes,
    // pixels never do). Real hardware brightness goes over DDC/CI via
    // ddcutil (VCP feature 0x10, 0-100 scale).
    //
    // Each ddcutil call takes ~700ms (I2C retry overhead), too slow to run
    // once per wheel tick, so scroll adjustments are debounced: the local
    // value and OSD update immediately for responsiveness, and the actual
    // `setvcp` call only fires once scrolling settles.
    property real brightness: 1.0
    property bool dimmed: false
    property real priorBrightness: 1.0
    property bool osdReady: false

    implicitWidth: 28
    implicitHeight: 28

    Timer {
        interval: 500
        running: true
        onTriggered: root.osdReady = true
    }

    function setLocal(value) {
        const clamped = Math.max(0.0, Math.min(1.0, value));
        root.brightness = clamped;
        if (root.osdReady)
            osd.show(root, root.brightness, "\uf042", Theme.teal);
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 250
        onTriggered: {
            setProcess.command = ["ddcutil", "setvcp", "10", String(Math.round(root.brightness * 100))];
            setProcess.running = true;
        }
    }

    Process {
        id: setProcess
    }

    // No Quickshell IPC in this Quickshell version (0.3.1) to push a
    // change notification when the XF86MonBrightness keys or the
    // monitor's own OSD adjust brightness outside this pill. A slow,
    // infrequent poll (ddcutil itself is ~700ms/call) keeps this pill
    // from drifting out of sync with those, without hammering I2C.
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/);
                const current = parseInt(parts[3], 10);
                if (!isNaN(current))
                    root.brightness = Math.max(0.0, Math.min(1.0, current / 100));
            }
        }
    }

    Osd {
        id: osd
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: "\uf042"
        color: Theme.teal
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconFontSize
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            if (root.dimmed) {
                root.dimmed = false;
                root.setLocal(root.priorBrightness);
            } else {
                root.priorBrightness = root.brightness;
                root.dimmed = true;
                root.setLocal(0.4);
            }
        }
        onWheel: wheel => {
            root.dimmed = false;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.setLocal(root.brightness + step);
        }
    }
}
