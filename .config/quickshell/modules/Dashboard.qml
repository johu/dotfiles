import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Quick-settings dashboard, design variant C (compact popup; the "More"
// expand section from the design doc is deferred until a first card
// feature — weather/system-resources/audio-mixer — actually exists, to
// avoid building empty scaffolding). Rows are thin wrappers around
// already-existing per-feature modules rather than new state.
PopupWindow {
    id: root

    anchor.adjustment: PopupAdjustment.Slide

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width / 2, 0);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x - card.implicitWidth / 2;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.visible = true;
        focusGrab.active = true;
    }

    // grabFocus auto-dismisses popups far too eagerly on Hyprland; toggle
    // visibility via the trigger glyph's own click handler instead. Outside-
    // click dismissal is handled separately below via HyprlandFocusGrab's
    // cleared() signal (same imperative active-toggling pattern as
    // ClipboardPicker.qml - binding active directly to root.visible does
    // not reliably activate the grab).
    grabFocus: false
    color: "transparent"

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        onCleared: root.visible = false
    }

    onVisibleChanged: if (!root.visible) focusGrab.active = false;

    // Hyprland.focusedWorkspace is reassigned to a *new* object on every
    // workspace switch (not the same object with its id mutated), so a
    // Connections { target: Hyprland.focusedWorkspace; onIdChanged } would
    // miss switches - track the id through a plain property binding
    // instead, which re-evaluates on either the reference or the id
    // changing.
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    onFocusedWorkspaceIdChanged: root.visible = false

    // On a machine running EasyEffects (or any filter-chain tool), the
    // PipeWire "default sink" can be a virtual node (e.g. easyeffects_sink)
    // whose own effect chain (compressor/limiter) can absorb volume
    // changes before they ever reach real speakers. Real ALSA-backed
    // hardware sinks are always named "alsa_output.*" by WirePlumber's ALSA
    // monitor - virtual/filter sinks never are - so that prefix is a
    // portable way to tell "is the default already real hardware" apart
    // from "need to bypass to a real one", without hardcoding EasyEffects
    // by name. On a machine with no such filter chain (e.g. a laptop),
    // the default sink already starts with "alsa_output." and is used
    // directly - no guessing needed.
    // Confirmed via `pw-link -l`, not guessed from wpctl's sink listing
    // order (that was the earlier mistake - the HDMI sink isn't actually
    // wired to anything; EasyEffects' processed output really goes here).
    readonly property string preferredHardwareSinkName: "alsa_output.usb-JDS_Labs_JDS_Labs_UAC2_DAC__XU208_-00.iec958-stereo"

    readonly property var hardwareSink: {
        const def = Pipewire.defaultAudioSink;
        if (def && def.name && def.name.startsWith("alsa_output."))
            return def;
        // Default sink looks virtual - this desktop has multiple real
        // hardware outputs (HDMI, two digital, a USB mic), so picking
        // "any" real ALSA sink could grab the wrong one; prefer the one
        // actually wired to the monitor's speakers when present, and
        // only fall back to "first real ALSA sink found" as a best-effort
        // guess on an unknown machine.
        return Pipewire.nodes.values.find(n => n.isSink && !n.isStream && n.name === root.preferredHardwareSinkName) ?? Pipewire.nodes.values.find(n => n.isSink && !n.isStream && n.name && n.name.startsWith("alsa_output.")) ?? def;
    }
    readonly property var sink: root.hardwareSink

    PwObjectTracker {
        objects: [root.sink]
    }

    function volumeIcon() {
        if (!root.sink?.audio || root.sink.audio.muted)
            return "\uf026";
        if (root.sink.audio.volume > 0.66)
            return "\uf028";
        if (root.sink.audio.volume > 0.0)
            return "\uf027";
        return "\uf026";
    }

    // Fixed size, independent of content — reactive resizing on this
    // compositor visibly "shakes" the popup (footgun #11).
    implicitWidth: 324
    implicitHeight: layout.implicitHeight + 24

    // Logic-only instances (visible: false) backing the toggle tiles below
    // - sourced for their public state/functions, not their own bar-sized
    // text glyph, which the tiles replace with a uniform icon+label tile
    // matching the dashboard design instead.
    NetworkIndicator {
        id: netLogic
        visible: false
    }

    Bluetooth {
        id: btLogic
        visible: false
    }

    Notifications {
        id: dndLogic
        visible: false
    }

    NightLight {
        id: nightLogic
        visible: false
    }

    IdleInhibit {
        id: idleLogic
        visible: false
    }

    Brightness {
        id: brightLogic
        visible: false
    }

    NetworkPanel {
        id: netPanel
    }

    Process {
        id: btManager
        command: ["blueman-manager"]
    }

    Process {
        id: dndToggle
        command: ["swaync-client", "-d", "-sw"]
    }

    Process {
        id: swayncPanel
        command: ["swaync-client", "-t", "-sw"]
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface1

        ColumnLayout {
            id: layout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            width: 300
            spacing: 12

            GridLayout {
                columns: 5
                columnSpacing: 8
                rowSpacing: 8
                Layout.alignment: Qt.AlignHCenter

                ToggleTile {
                    id: wifiTile
                    icon: netLogic.activeWifiNetwork ? netLogic.wifiIcon(netLogic.activeWifiNetwork.signalStrength) : (netLogic.wiredDevice?.connected ? "\u{f0200}" : "\uf1eb")
                    label: netLogic.activeWifiNetwork ? "WiFi" : (netLogic.wiredDevice?.connected ? "LAN" : "WiFi")
                    accentColor: Theme.sky
                    active: !!netLogic.activeWifiNetwork || !!netLogic.wiredDevice?.connected
                    onClicked: {
                        if (netPanel.visible)
                            netPanel.visible = false;
                        else
                            netPanel.open(wifiTile);
                    }
                }
                ToggleTile {
                    icon: "\uf293"
                    label: "BT"
                    accentColor: Theme.blue
                    active: btLogic.powered
                    enabled: btLogic.present
                    onClicked: btManager.running = true
                }
                ToggleTile {
                    icon: dndLogic.alt.includes("dnd") ? "\uf1f7" : "\uf0a2"
                    label: "DND"
                    accentColor: Theme.red
                    active: dndLogic.alt.includes("dnd")
                    onClicked: dndToggle.running = true
                    onRightClicked: {
                        swayncPanel.running = true;
                        root.visible = false;
                    }
                }
                ToggleTile {
                    icon: nightLogic.active ? "\uf186" : "\uf185"
                    label: "Night"
                    accentColor: Theme.yellow
                    active: nightLogic.active
                    onClicked: {
                        if (nightLogic.gameModeActive)
                            return;
                        nightLogic.active = !nightLogic.active;
                        nightLogic.overrideUntil = nightLogic.nextTransitionEpochAfter(new Date());
                        nightLogic.sendCommand(nightLogic.active ? "temperature 4500" : "identity");
                    }
                }
                ToggleTile {
                    icon: "\uf0f4"
                    label: "Awake"
                    accentColor: Theme.green
                    active: idleLogic.active
                    onClicked: idleLogic.active = !idleLogic.active
                }
            }

            SliderRow {
                Layout.fillWidth: true
                icon: root.volumeIcon()
                accentColor: Theme.blue
                value: root.sink?.audio?.volume ?? 0
                onMoved: v => {
                    if (root.sink?.audio) {
                        root.sink.audio.volume = v;
                        if (v > 0)
                            root.sink.audio.muted = false;
                    }
                }
            }

            SliderRow {
                Layout.fillWidth: true
                icon: "\uf042"
                accentColor: Theme.teal
                value: brightLogic.brightness
                onMoved: v => brightLogic.setLocal(v)
            }

            Loader {
                Layout.fillWidth: true
                // Media.qml always renders a play/pause glyph even with no
                // player (relies on callers gating it, same as Bar.qml's
                // own Loader) - without this guard an idle dashboard shows
                // a phantom play icon with no track.
                active: Mpris.players.values.length > 0
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0

                // Pill's own implicitWidth is content-driven by default -
                // explicitly matching the Loader's assigned width (Loader
                // becomes the Pill's parent here) is what lets the Media
                // label below wrap instead of eliding.
                sourceComponent: Pill {
                    width: parent.width
                    // Pill's own implicitHeight is a fixed Theme.moduleHeight
                    // (single-line pills elsewhere) - grow it to fit a
                    // wrapped two-line title instead of clipping it.
                    implicitHeight: Math.max(Theme.moduleHeight, mediaContent.implicitHeight + 12)
                    horizontalPadding: 14
                    Media {
                        id: mediaContent
                        wrap: true
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Same actions wlogout's own layout.json defines (see
                // ~/.config/wlogout/layout) - a subset surfaced here for
                // daily use; the rest stay behind the wlogout shortcut.
                PowerButton {
                    icon: "\uf023"
                    label: "Lock"
                    accentColor: Theme.subtext1
                    command: ["sh", "-c", "sleep 1;hyprlock"]
                    onActivated: root.visible = false
                }

                PowerButton {
                    icon: "\uf011"
                    label: "Logout"
                    accentColor: Theme.red
                    command: ["hyprshutdown"]
                    onActivated: root.visible = false
                }

                PowerButton {
                    icon: "\uf021"
                    label: "Reboot"
                    accentColor: Theme.sky
                    command: ["sh", "-c", "hyprshutdown -t 'Restarting...' --post-cmd 'reboot'"]
                    onActivated: root.visible = false
                }
            }
        }
    }
}
