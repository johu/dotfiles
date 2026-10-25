import QtQuick
import Quickshell.Io

Item {
    id: root

    // Backend is detected at runtime rather than hardcoded: laptops with
    // a real backlight device use brightnessctl (direct kernel sysfs
    // write, fast, no debounce needed); this desktop's external DP
    // monitor has no backlight device, so it falls back to DDC/CI via
    // ddcutil (VCP feature 0x10, 0-100 scale). See
    // docs/ideas/brightness-laptop-backend.md.
    //
    // ddcutil calls take ~700ms each (I2C retry overhead), too slow to
    // run once per wheel tick, so scroll adjustments are debounced: the
    // local value and OSD update immediately for responsiveness, and the
    // actual hardware write only fires once scrolling settles.
    // brightnessctl needs no such debounce.
    property real brightness: 1.0
    property bool dimmed: false
    property real priorBrightness: 1.0
    property bool osdReady: false
    property string backend: ""
    property string backlightDevice: ""

    implicitWidth: 28
    implicitHeight: 28

    Timer {
        interval: 500
        running: true
        onTriggered: root.osdReady = true
    }

    Component.onCompleted: detect.running = true

    Process {
        id: detect
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const device = this.text.trim();
                if (device) {
                    root.backend = "brightnessctl";
                    root.backlightDevice = device;
                } else {
                    root.backend = "ddcutil";
                }
                poll.running = true;
                pollTimer.running = true;
            }
        }
    }

    function setLocal(value) {
        const clamped = Math.max(0.0, Math.min(1.0, value));
        root.brightness = clamped;
        if (root.osdReady)
            osd.show(root, root.brightness, "\uf042", Theme.teal);
        applyTimer.interval = root.backend === "brightnessctl" ? 0 : 250;
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 250
        onTriggered: {
            const percent = String(Math.round(root.brightness * 100));
            if (root.backend === "brightnessctl")
                setProcess.command = ["brightnessctl", "-d", root.backlightDevice, "set", percent + "%"];
            else
                setProcess.command = ["ddcutil", "setvcp", "10", percent];
            setProcess.running = true;
        }
    }

    Process {
        id: setProcess
    }

    // No Quickshell IPC in this Quickshell version to push a change
    // notification when the XF86MonBrightness keys or the monitor's own
    // OSD adjust brightness outside this pill, so this pill polls to stay
    // in sync. ddcutil is slow (~700ms/call), so it polls rarely;
    // brightnessctl is a cheap sysfs read, so it can poll more often.
    Timer {
        id: pollTimer
        interval: root.backend === "brightnessctl" ? 3000 : 15000
        running: false
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll
        command: root.backend === "brightnessctl" ? ["brightnessctl", "-m", "-d", root.backlightDevice] : ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                let current = NaN;
                if (root.backend === "brightnessctl") {
                    const fields = this.text.trim().split(",");
                    current = parseInt(fields[3], 10);
                } else {
                    const parts = this.text.trim().split(/\s+/);
                    current = parseInt(parts[3], 10);
                }
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
