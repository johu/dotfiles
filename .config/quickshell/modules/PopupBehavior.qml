import QtQuick
import Quickshell.Hyprland

// Drop inside a PopupWindow/PanelWindow to opt it into PopupManager's
// shared dismiss policy.
//   name       unique key (also the `popups` IPC name)
//   popup      the window (normally `root`)
//   openFn     how IPC/toggle() opens it with no pointer context, or null
//   focusGrab  true for xdg-popups (outside click dismisses via
//              HyprlandFocusGrab); false for full-screen overlays that
//              already swallow outside clicks with their own MouseArea.
Item {
    id: root

    required property string name
    required property var popup
    property var openFn: null
    property bool focusGrab: true

    visible: false

    // The anchor window (the bar) is part of the grab so a click on a bar
    // button is delivered to that button instead of being swallowed as
    // the "outside click" that clears the grab - otherwise switching from
    // one popup to another, or closing via its own trigger, takes two
    // clicks.
    HyprlandFocusGrab {
        windows: root.popup.anchor && root.popup.anchor.window ? [root.popup, root.popup.anchor.window] : [root.popup]
        active: root.focusGrab && root.popup.visible
        onCleared: root.popup.visible = false
    }

    Connections {
        target: root.popup
        function onVisibleChanged() {
            if (root.popup.visible)
                PopupManager.claim(root.name);
            else
                PopupManager.release(root.name);
        }
    }

    Component.onCompleted: PopupManager.register(root.name, root.popup, root.openFn)
    Component.onDestruction: PopupManager.unregister(root.name)
}
