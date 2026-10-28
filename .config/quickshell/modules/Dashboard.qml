import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Quick-settings dashboard, design variant C (compact popup). Rows are
// thin wrappers around already-existing per-feature modules rather than
// new state. system-resources.md (SystemResourcesRow) departs from the
// design doc's deferred-"More"-divider sketch slightly: its CPU/RAM
// summary is always visible, and clicking it expands in place to the
// detailed card instead of sitting behind a separate generic toggle.
//
// Built on a full-screen transparent PanelWindow (same pattern as
// Launcher.qml) rather than a PopupWindow. A PopupWindow is an xdg-popup,
// whose live resize goes through a positioner recalculation that visibly
// glitches on this compositor (footgun #11 below) - a PanelWindow is a
// wlr-layer-shell surface with a size the client controls directly, so
// the `card` Rectangle inside can freely grow/shrink (toggle grid rows,
// the media row, future weather/audio-mixer cards, this file's own
// SystemResourcesRow expand) with a real `Behavior on height` and no
// resize-related flicker, confirmed against caelestia/shell's dashboard
// (`references/shell/modules/dashboard/Content.qml`), which does the
// same `Behavior on implicitHeight` for the same reason.
PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // A layer-shell surface anchored to all four edges still gets inset by
    // other surfaces' exclusive zones by default - the bar's own
    // `exclusiveZone: implicitHeight` (Bar.qml) pushed this window's local
    // y=0 down to the real bar's bottom edge, so `card`'s `topMargin:
    // Theme.barHeight + 8` below was adding the bar height a *second* time
    // on top of that implicit inset (confirmed via pixel-measuring a
    // screenshot: the card rendered at y~90, not the intended y~50).
    // exclusionMode: Ignore opts this window out of that inset so it
    // truly spans the full screen from y=0, matching what the topMargin
    // math already assumes.
    exclusionMode: ExclusionMode.Ignore

    function open() {
        root.visible = true;
    }

    IpcHandler {
        target: "dashboard"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.visible = false;
        }
    }

    // Reset on every reopen so expanded detail rows don't stay stuck open.
    // netPanel is a separate PopupWindow only ever closed by re-clicking
    // the WiFi tile - without this, any dashboard-close path other than
    // that tile (outside click, workspace switch, power buttons) leaves
    // it stranded open with no remaining way to dismiss it.
    onVisibleChanged: if (!root.visible) {
        weatherRow.expanded = false;
        audioRow.expanded = false;
        sysRow.expanded = false;
        netPanel.visible = false;
    }

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

    SystemResources {
        id: sysLogic
        visible: false
    }

    AudioMixer {
        id: audioLogic
        visible: false
    }

    NetworkPanel {
        id: netPanel
    }

    Process {
        id: btManager
        command: ["blueman-manager"]
    }

    // Covers the whole screen - click anywhere outside the card to dismiss
    // (same dismiss pattern as Launcher.qml's own full-screen MouseArea).
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barHeight + 8
        anchors.rightMargin: 15
        radius: Theme.radius
        color: Theme.surface1
        width: 324
        height: layout.implicitHeight + 24
        // AudioMixerRow/SystemResourcesRow reserve their detail card's
        // full height the instant `expanded` flips (only opacity fades in
        // afterward, per their own comments - see SystemResourcesRow.qml's
        // "Reserves layout space" note) and rely on *this* Rectangle's own
        // height Behavior below to visually "reveal" that already-laid-out
        // content as it grows. Without clip: true, the content isn't
        // actually masked - it just overflows past the still-small
        // boundary immediately, colliding with whatever row sits below it
        // (confirmed: AudioMixerRow, not being the last row, looked like it
        // "snapped" instead of animating, while SystemResourcesRow - last,
        // so its overflow just extended past the bottom edge unnoticed -
        // looked fine).
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // Consumes clicks on the card itself so they don't fall through to
        // the full-screen dismiss MouseArea behind it.
        MouseArea {
            anchors.fill: parent
        }

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
                    enabled: netLogic.present
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
                    icon: Notifications.dnd ? "\uf1f7" : "\uf0a2"
                    label: "DND"
                    accentColor: Theme.red
                    active: Notifications.dnd
                    onClicked: Notifications.setDndSilently(!Notifications.dnd)
                }
                ToggleTile {
                    icon: "\uf186"
                    iconSource: nightLogic.active ? "" : "file:///home/johu/.config/quickshell/assets/icons/sun.svg"
                    label: "Night"
                    accentColor: Theme.yellow
                    active: nightLogic.active
                    enabled: nightLogic.present
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
                muted: root.sink?.audio?.muted ?? false
                mutable: true
                onMoved: v => {
                    if (root.sink?.audio) {
                        root.sink.audio.volume = v;
                        // Dragging all the way down is how a mute gesture
                        // reads to a user - without this, 0% and muted
                        // were two different states that looked identical
                        // (icon already drew the same glyph for both) but
                        // behaved differently for anything else reading
                        // PwAudio.muted (media keys, other mixers).
                        root.sink.audio.muted = v === 0;
                    }
                }
                onIconClicked: if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted
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

            // Tighter spacing than the outer layout's 12px - these two
            // rows read as one "monitoring" group, unlike the looser
            // spacing between unrelated sections above (toggles, sliders,
            // media, power buttons).
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                WeatherRow {
                    id: weatherRow
                    Layout.fillWidth: true
                }

                AudioMixerRow {
                    id: audioRow
                    Layout.fillWidth: true
                    streams: audioLogic.streams
                    summaryText: audioLogic.summaryText
                }

                SystemResourcesRow {
                    id: sysRow
                    Layout.fillWidth: true
                    cpuPercent: sysLogic.cpuPercent
                    cpuModel: sysLogic.cpuModel
                    cpuCores: sysLogic.cpuCores
                    ramPercent: sysLogic.ramPercent
                    ramUsedStr: sysLogic.ramUsedStr
                    ramTotalStr: sysLogic.ramTotalStr
                    ramFreeStr: sysLogic.ramFreeStr
                    tempCelsius: sysLogic.tempCelsius
                    rootDiskPercent: sysLogic.rootDiskPercent
                    disks: sysLogic.disks
                }
            }
        }
    }
}
