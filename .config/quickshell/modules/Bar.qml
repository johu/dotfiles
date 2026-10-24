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
        // once a player is actually playing, instead of toggling visibility
        // on a long-lived one.
        Loader {
            active: Mpris.players.values.some(p => p.isPlaying || (p.dbusName === bar.lastActivePlayerId && p.playbackState !== MprisPlaybackState.Stopped))
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
            NetworkIndicator {}
            Bluetooth {}
            Battery {}
            Volume {}
            Clipboard {}
            Notifications {}
            Logout {}
        }
    }
}
