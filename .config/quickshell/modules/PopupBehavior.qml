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
//   grabAnchor include the anchor window (bar) in the grab so a bar-button
//              click is not swallowed. Must be false for popups that need
//              keyboard input: the compositor picks which whitelisted
//              surface gets keyboard focus, and with the bar listed it can
//              pick the bar instead of the popup.
Item {
    id: root

    required property string name
    required property var popup
    property var openFn: null
    property bool focusGrab: true
    property bool grabAnchor: true

    visible: false

    // The anchor window (the bar) is in the grab so a click on a bar button
    // reaches it instead of being swallowed as the outside click; otherwise
    // switching popups takes two clicks.
    //
    // `active` isn't bound to popup.visible: activating in the same tick
    // creates the grab before the popup is mapped, so clicks on the popup count
    // as outside and clear it. Activate after a short delay.
    HyprlandFocusGrab {
        id: grab
        windows: root.grabAnchor && root.popup.anchor && root.popup.anchor.window ? [root.popup, root.popup.anchor.window] : [root.popup]
        onCleared: root.popup.visible = false
    }

    Timer {
        id: grabTimer
        interval: 60
        onTriggered: if (root.popup.visible)
            grab.active = true
    }

    Connections {
        target: root.popup
        function onVisibleChanged() {
            if (root.popup.visible) {
                PopupManager.claim(root.name);
                if (root.focusGrab)
                    grabTimer.restart();
            } else {
                grabTimer.stop();
                grab.active = false;
                PopupManager.release(root.name);
            }
        }
    }

    Component.onCompleted: PopupManager.register(root.name, root.popup, root.openFn)
    Component.onDestruction: PopupManager.unregister(root.name)
}
