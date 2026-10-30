import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
    id: bar

    color: "transparent"
    implicitHeight: Theme.barHeight

    // Keeps the media pill meaningfully clickable while paused without
    // resurfacing an unrelated backgrounded player (e.g. a paused YouTube
    // tab) that happens to also be in a non-Stopped MPRIS state. Only the
    // bus name that was last actually seen playing counts as "paused but
    // still relevant".
    property string lastActivePlayerId: ""

    // Self-contained PanelWindow (own IpcHandler target "launcher"), not
    // part of the bar's visible layout - just needs to exist somewhere so
    // SUPER+SPACE's `qs ipc call launcher toggle` has a live target. Used
    // to live nested inside Logo.qml's click handler; that click now
    // focuses the Gentoo workspace instead, so this moved up here.
    Launcher {}

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
            // Matches waybar's #navigation group, where nested children
            // (custom-logo, #workspaces) each add their own padding on top
            // of #navigation's own "0px 10px" — giving an asymmetric
            // 20px/13px inset rather than a flat value on both sides.
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
                Layout.maximumWidth: 400
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

        // A plain `visible: false -> true` toggle on an existing RowLayout
        // child can get stuck without a repaint on this compositor's
        // event-loop-driven (non-animation-driven) render path — a Loader
        // sidesteps that by constructing a fresh Pill/Media instance only
        // once a player is actually available, instead of toggling visibility
        // on a long-lived one.
        //
        // Matches Dashboard.qml's MediaExpandCard guard (`players.length > 0`)
        // rather than the old isPlaying/lastActivePlayerId-stopped check -
        // the cava visualizer pill should appear whenever any player is
        // registered (e.g. paused, not yet pressed play), same as the
        // dashboard card, not just while something is actively playing.
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

        Pill {
            // waybar's #system margin is asymmetric (7px top/3px bottom, not
            // centered); padding is bumped past waybar's raw 10px since our
            // glyphs sit closer to this pill's stadium-radius end caps.
            height: 32
            horizontalPadding: 14
            spacing: 14

            Tray {}
            Privacy {}
            Battery {}
            // Hidden unless a device is actually connected (not just
            // powered-on) - the dashboard's BT toggle covers the
            // powered-but-idle case. Overriding `visible:` directly on a
            // Bluetooth {} instance silently loses to its own internal
            // `visible: present` binding (confirmed empirically - not just
            // a theory), and even wrapping it in a plain Item with
            // implicitWidth/implicitHeight collapsed to 0 + clip: true
            // didn't hide it either. A Loader that only constructs the
            // real pill once connected (same pattern already used for the
            // Media pill above) sidesteps the whole problem.
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
