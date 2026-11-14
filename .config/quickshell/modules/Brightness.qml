import QtQuick
import Quickshell.Io

Item {
    id: root

    // Backend detected at runtime: brightnessctl for a real backlight device
    // (fast, no debounce), else DDC/CI via ddcutil (VCP 0x10, 0-100). See
    // docs/ideas/brightness-laptop-backend.md.
    //
    // ddcutil takes ~700ms per call, so scroll is debounced: value and OSD
    // update at once, the hardware write waits for scrolling to settle.
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

    // Nothing pushes external changes (brightness keys, monitor OSD), so poll:
    // rarely for slow ddcutil, more often for cheap sysfs reads.
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
        renderType: Text.NativeRendering
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
