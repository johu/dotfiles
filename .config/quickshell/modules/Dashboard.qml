import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// Quick-settings popup. A full-screen transparent PanelWindow instead of a
// PopupWindow: xdg-popup resizing glitches here (footgun #11), while a
// layer-shell surface can animate its height freely.
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

    // Ignore the bar's exclusive zone, or topMargin gets added on top of it.
    exclusionMode: ExclusionMode.Ignore

    // Only the password prompt needs keyboard focus. Set imperatively:
    // binding to networkRow.pskActive throws a ReferenceError at startup.
    property bool networkPskActive: false
    WlrLayershell.keyboardFocus: root.networkPskActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

    // Lets NetworkIndicator reach the dashboard without a direct reference.
    Connections {
        target: DashboardBridge
        function onOpenNetworkRequested() {
            root.open();
            networkRow.expanded = true;
            bluetoothRow.expanded = false;
        }
        function onOpenBluetoothRequested() {
            root.open();
            bluetoothRow.expanded = true;
            networkRow.expanded = false;
        }
    }

    // Reset on reopen; other close paths would leave detail rows stuck open.
    onVisibleChanged: if (!root.visible) {
        weatherRow.expanded = false;
        audioRow.expanded = false;
        sysRow.expanded = false;
        agentRow.expanded = false;
        networkRow.expanded = false;
        bluetoothRow.expanded = false;
    }

    // focusGrab is off: the full-screen MouseArea already swallows outside clicks.
    PopupBehavior {
        name: "dashboard"
        popup: root
        focusGrab: false
        openFn: () => root.open()
    }

    // A virtual default sink (e.g. easyeffects_sink) can absorb volume changes,
    // so target a real "alsa_output.*" sink.
    readonly property string preferredHardwareSinkName: "alsa_output.usb-JDS_Labs_JDS_Labs_UAC2_DAC__XU208_-00.iec958-stereo"

    readonly property var hardwareSink: {
        const def = Pipewire.defaultAudioSink;
        if (def && def.name && def.name.startsWith("alsa_output."))
            return def;
        // Prefer the sink wired to the monitor speakers, else the first real ALSA sink.
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

    function toggleNightLight() {
        if (nightLogic.gameModeActive)
            return;
        nightLogic.active = !nightLogic.active;
        nightLogic.overrideUntil = nightLogic.nextTransitionEpochAfter(new Date());
        nightLogic.sendCommand(nightLogic.active ? "temperature 4500" : "identity");
    }

    // Lets other modules (SystemActions/launcher) read and toggle these.
    Connections {
        target: DashboardBridge
        function onToggleNightLightRequested() {
            if (nightLogic.present)
                root.toggleNightLight();
        }
        function onToggleIdleInhibitRequested() {
            idleLogic.active = !idleLogic.active;
        }
    }

    Binding {
        target: DashboardBridge
        property: "nightLightPresent"
        value: nightLogic.present
    }

    Binding {
        target: DashboardBridge
        property: "nightLightActive"
        value: nightLogic.active
    }

    Binding {
        target: DashboardBridge
        property: "idleInhibitActive"
        value: idleLogic.active
    }

    // Invisible instances, used only for their state and functions.
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

    AgentUsage {
        id: agentLogic
        visible: false
    }

    AudioMixer {
        id: audioLogic
        visible: false
    }

    // Click outside the card to dismiss.
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
        width: 418
        height: layout.implicitHeight + 24
        // Clip: detail cards reserve their full height at once, so without it they
        // overflow while the height animates.
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // Swallow clicks so they don't reach the dismiss area behind.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: layout
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            width: 394
            spacing: 12

            GridLayout {
                columns: 8
                columnSpacing: 6
                rowSpacing: 6
                Layout.alignment: Qt.AlignHCenter

                ToggleTile {
                    id: wifiTile
                    icon: netLogic.activeWifiNetwork ? netLogic.wifiIcon(netLogic.activeWifiNetwork.signalStrength) : (netLogic.wiredDevice?.connected ? "\u{f0200}" : "\uf1eb")
                    accentColor: Theme.sky
                    active: !!netLogic.activeWifiNetwork || !!netLogic.wiredDevice?.connected
                    enabled: netLogic.present
                    // Opening one collapses the other.
                    onClicked: {
                        const opening = !networkRow.expanded;
                        networkRow.expanded = opening;
                        if (opening)
                            bluetoothRow.expanded = false;
                    }
                }
                ToggleTile {
                    icon: "\uf293"
                    id: bluetoothTile
                    accentColor: Theme.blue
                    active: btLogic.powered
                    enabled: btLogic.present
                    onClicked: {
                        const opening = !bluetoothRow.expanded;
                        bluetoothRow.expanded = opening;
                        if (opening)
                            networkRow.expanded = false;
                    }
                }
                ToggleTile {
                    icon: Notifications.dnd ? "\uf1f7" : "\uf0a2"
                    accentColor: Theme.red
                    active: Notifications.dnd
                    onClicked: Notifications.setDndSilently(!Notifications.dnd)
                }
                ToggleTile {
                    icon: "\uf186"
                    iconSource: nightLogic.active ? "" : Quickshell.shellPath("assets/icons/sun.svg")
                    accentColor: Theme.yellow
                    active: nightLogic.active
                    enabled: nightLogic.present
                    onClicked: root.toggleNightLight()
                }
                ToggleTile {
                    icon: "\uf0f4"
                    accentColor: Theme.green
                    active: idleLogic.active
                    onClicked: idleLogic.active = !idleLogic.active
                }

                ToggleTile {
                    icon: "\uf030"
                    accentColor: Theme.mauve
                    // Left click = region picker, right click = whole screen.
                    onClicked: {
                        root.visible = false;
                        DashboardBridge.captureRequested("region");
                    }
                    onRightClicked: {
                        root.visible = false;
                        DashboardBridge.captureRequested("screen");
                    }
                }

                ToggleTile {
                    icon: "\uf111"
                    accentColor: Theme.red
                    active: Recorder.recording
                    // Same, and either also stops a running recording.
                    onClicked: {
                        root.visible = false;
                        DashboardBridge.captureRequested("record-region");
                    }
                    onRightClicked: {
                        root.visible = false;
                        DashboardBridge.captureRequested("record-screen");
                    }
                }

                ToggleTile {
                    icon: "\uf011"
                    accentColor: Theme.lavender
                    onClicked: {
                        wlogoutProc.running = true;
                        root.visible = false;
                    }
                }
            }

            Process {
                id: wlogoutProc
                command: ["wlogout"]
            }

            // Reveal for wifiTile; has no summary row of its own.
            NetworkRow {
                id: networkRow
                Layout.fillWidth: true
                // Collapsed rows are zero-height but still take a spacing slot.
                visible: reserved
                onPskActiveChanged: root.networkPskActive = pskActive
            }

            // Reveal for bluetoothTile.
            BluetoothRow {
                id: bluetoothRow
                Layout.fillWidth: true
                visible: reserved
            }

            // Always expanded: media is persistent, high-priority state.
            Loader {
                Layout.fillWidth: true
                active: Mpris.players.values.length > 0
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0

                sourceComponent: Rectangle {
                    width: parent ? parent.width : 0
                    radius: Theme.radius
                    // Plain surface2 hides MediaExpandCard's disabled prev/next icons.
                    color: Qt.lighter(Theme.surface1, 1.3)
                    implicitHeight: cardContent.implicitHeight + 24

                    MediaExpandCard {
                        id: cardContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                    }
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
                        // Dragging to the bottom reads as mute; keep 0% and muted the same state.
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

            // Tighter spacing: these two rows read as one group.
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

                AgentUsageRow {
                    id: agentRow
                    Layout.fillWidth: true
                    ok: agentLogic.ok
                    status: agentLogic.status
                    sessionPercent: agentLogic.sessionPercent
                    sessionResetsAt: agentLogic.sessionResetsAt
                    weeklyPercent: agentLogic.weeklyPercent
                    weeklyResetsAt: agentLogic.weeklyResetsAt
                }
            }
        }
    }
}
