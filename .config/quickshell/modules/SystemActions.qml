pragma Singleton
import QtQuick
import Quickshell

// Session, toggle and capture actions as launcher-style entries (omacast
// row 16). Single choke point for what "lock", "reboot", "night light" ...
// mean, so other surfaces (power menu, dashboard) can share it later.
//
// Each entry mimics the DesktopEntry fields the launcher reads (id, name,
// comment, genericName, keywords, icon) plus: system (true), glyph (Nerd
// Font icon), color, active (shows a check mark) and execute().
Singleton {
    id: root

    // Runs fn shortly after the launcher has closed, so the launcher is not
    // in a screenshot or still holding keyboard focus.
    function later(fn) {
        deferred.fn = fn;
        deferred.restart();
    }

    Timer {
        id: deferred

        property var fn: null

        interval: 250
        onTriggered: {
            if (fn)
                fn();
        }
    }

    function sh(cmd) {
        root.later(() => Quickshell.execDetached(["sh", "-c", cmd]));
    }

    function capture(mode) {
        root.later(() => DashboardBridge.captureRequested(mode));
    }

    function entry(id, name, comment, keywords, glyph, color, execute, active) {
        return {
            id: "sys:" + id,
            name: name,
            comment: comment,
            genericName: "System",
            keywords: keywords,
            icon: "",
            glyph: glyph,
            color: color,
            active: active === true,
            system: true,
            execute: execute
        };
    }

    // Recomputed when toggle state changes, so check marks stay current.
    readonly property var entries: {
        const list = [
            // Session (same commands as the wlogout layout)
            root.entry("lock", "Lock Screen", "Lock the session with hyprlock", ["lock", "screen", "hyprlock"], "\uf023", Theme.lavender, () => root.sh("hyprlock")),
            root.entry("logout", "Log Out", "End the Hyprland session", ["logout", "log out", "sign out", "exit"], "\uf08b", Theme.lavender, () => root.sh("hyprshutdown")),
            root.entry("suspend", "Suspend", "Suspend to RAM", ["suspend", "sleep"], "\uf186", Theme.lavender, () => root.sh("systemctl suspend")),
            root.entry("hibernate", "Hibernate", "Suspend to disk", ["hibernate"], "\uf0c7", Theme.lavender, () => root.sh("systemctl hibernate")),
            root.entry("reboot", "Reboot", "Restart the computer", ["reboot", "restart"], "\uf021", Theme.maroon, () => root.sh("hyprshutdown -t 'Restarting...' --post-cmd 'reboot'")),
            root.entry("poweroff", "Power Off", "Shut the computer down", ["power off", "poweroff", "shutdown", "shut down"], "\uf011", Theme.red, () => root.sh("hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'")),

            // Toggles
            root.entry("dnd", "Do Not Disturb", Notifications.dnd ? "Notifications are muted (on)" : "Notifications are shown (off)", ["dnd", "do not disturb", "mute notifications", "silence"], Notifications.dnd ? "\uf1f7" : "\uf0a2", Theme.red, () => {
                Notifications.dnd = !Notifications.dnd;
            }, Notifications.dnd),
            root.entry("idle", "Keep Awake", DashboardBridge.idleInhibitActive ? "Idle inhibitor is on" : "Idle inhibitor is off", ["idle", "inhibit", "caffeine", "keep awake", "no sleep"], "\uf0f4", Theme.green, () => DashboardBridge.toggleIdleInhibitRequested(), DashboardBridge.idleInhibitActive)
        ];
        if (DashboardBridge.nightLightPresent)
            list.push(root.entry("nightlight", "Night Light", DashboardBridge.nightLightActive ? "Warm screen colour is on" : "Warm screen colour is off", ["night light", "nightlight", "blue light", "warm", "sunset"], "\uf186", Theme.yellow, () => DashboardBridge.toggleNightLightRequested(), DashboardBridge.nightLightActive));

        // Capture (handled by Capture.qml through DashboardBridge)
        list.push(root.entry("shot-region", "Screenshot Region", "Pick an area to capture", ["screenshot", "screen shot", "capture", "region"], "\uf030", Theme.mauve, () => root.capture("region")));
        list.push(root.entry("shot-screen", "Screenshot Screen", "Capture the whole screen", ["screenshot", "screen shot", "capture", "full screen"], "\uf108", Theme.mauve, () => root.capture("screen")));
        list.push(root.entry("shot-window", "Screenshot Window", "Capture the focused window", ["screenshot", "screen shot", "capture", "window"], "\uf2d0", Theme.mauve, () => root.capture("window")));
        list.push(root.entry("shot-annotate", "Annotate Screenshot", "Pick an area, then draw on it", ["annotate", "screenshot", "markup", "draw"], "\uf040", Theme.mauve, () => root.capture("annotate")));
        list.push(root.entry("ocr", "Copy Text from Screen", "OCR an area into the clipboard", ["ocr", "text", "recognize", "copy text"], "\uf031", Theme.mauve, () => root.capture("ocr")));
        list.push(root.entry("qr", "Scan QR Code", "Decode a QR code on screen", ["qr", "qr code", "scan"], "\uf029", Theme.mauve, () => root.capture("qr")));
        list.push(root.entry("rec-region", Recorder.recording ? "Stop Recording" : "Record Region", Recorder.recording ? "Finish and save the recording" : "Pick an area to record", ["record", "recording", "screen recording", "region"], "\uf111", Theme.red, () => root.capture("record-region"), Recorder.recording));
        list.push(root.entry("rec-screen", Recorder.recording ? "Stop Recording" : "Record Screen", Recorder.recording ? "Finish and save the recording" : "Record the whole screen", ["record", "recording", "screen recording", "screen"], "\uf111", Theme.red, () => root.capture("record-screen"), Recorder.recording));
        return list;
    }
}
