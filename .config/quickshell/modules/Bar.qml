import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
    id: bar

    color: "transparent"
    implicitHeight: Theme.barHeight

    // Keeps the media pill clickable while paused without surfacing an
    // unrelated backgrounded player. Only the bus name last seen playing
    // counts.
    property string lastActivePlayerId: ""

    // Self-contained PanelWindow (IPC target "launcher"), not part of the bar
    // layout; it just needs to exist for SUPER+SPACE's `qs ipc call launcher
    // toggle`.
    Launcher {}

    // Screenshot picker (IPC target "capture"); same pattern.
    Capture {}

    Instantiator {
        model: Mpris.players.values
        delegate: Connections {
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    bar.lastActivePlayerId = modelData.dbusName;
            }
            Component.onCompleted: if (modelData.isPlaying)
                bar.lastActivePlayerId = modelData.dbusName
        }
    }

    anchors {
        top: true
        left: true
        right: true
    }

    exclusiveZone: implicitHeight

    mask: Region {
        item: fullArea
    }

    Item {
        id: fullArea
        anchors.fill: parent
    }

    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 15
        spacing: 15

        Pill {
            // Mirrors waybar's #navigation group: nested children add their own
            // padding, giving an asymmetric 20px/13px inset.
            leftPadding: 11
            rightPadding: 9
            spacing: 10
            Logo {}
            Workspaces {}
        }

        Pill {
            visible: activeWindow.text.length > 0

            ActiveWindow {
                id: activeWindow
                Layout.maximumWidth: 600
            }
        }
    }

    Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        Clock {}
    }

    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.rightMargin: 15
        spacing: 15

        // A visible toggle on a RowLayout child can get stuck without a repaint on
        // this compositor, so a Loader creates a fresh Media only once a player
        // exists. Matches Dashboard's MediaExpandCard guard (`players.length > 0`).
        Loader {
            active: Mpris.players.values.length > 0
            visible: active
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0

            sourceComponent: Pill {
                horizontalPadding: 14
                Media {
                    lastActivePlayerId: bar.lastActivePlayerId
                    Layout.maximumWidth: 250
                }
            }
        }

        // Recording indicator: red dot + elapsed time, click to stop.
        Loader {
            active: Recorder.recording
            visible: active
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0

            sourceComponent: Pill {
                horizontalPadding: 12
                spacing: 8

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.red
                    Layout.alignment: Qt.AlignVCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }

                Text {
                    text: Recorder.stopping ? "Saving…" : Recorder.elapsedText
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Recorder.stop()
                }
            }
        }

        Pill {
            // Margins mirror waybar's #system (7px top/3px bottom); padding is larger
            // because the glyphs sit close to the pill's rounded end caps.
            height: 32
            horizontalPadding: 14
            spacing: 14

            Tray {}
            Privacy {}
            Battery {}
            // Hidden unless a device is connected (the dashboard toggle covers
            // powered-but-idle). `visible:` on a Bluetooth {} loses to its internal
            // `visible: present` binding, and a collapsed clipped Item doesn't hide
            // it either, so a Loader builds the pill only once connected.
            Bluetooth {
                id: btProbe
                visible: false
            }

            Loader {
                active: btProbe.present && btProbe.connectedCount > 0
                visible: active
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0

                sourceComponent: Bluetooth {}
            }
            Clipboard {}
            NotificationsGlyph {}
            Settings {}
        }
    }
}
