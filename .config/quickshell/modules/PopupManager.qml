pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Central policy for every click-dismissed popup/overlay (Calendar,
// BatteryDetail, NotificationHistory, ClipboardPicker, TrayMenu,
// Dashboard, Launcher). Each registers itself through a PopupBehavior
// child, which gives all of them the same rules:
//   * only one is open at a time (opening one closes the previous),
//   * all of them close on a workspace switch,
//   * a trigger click that lands while the popup's own focus grab is
//     being cleared does not immediately reopen it (see toggle()),
//   * `qs ipc call popups open <name>` opens any registered one, so
//     geometry can be screenshot-verified without synthetic input.
// Transient popups (Osd, MediaHoverPopup, LogoTooltip) are hover/timer
// driven and deliberately stay out of this.
Singleton {
    id: root

    // name -> { popup, open }
    property var entries: ({})
    // name -> Date.now() of the last close
    property var closedAt: ({})
    property string activeName: ""

    // Window within which a trigger click right after a close is treated
    // as the same click that dismissed the popup (outside-click clears the
    // focus grab on press, then the trigger's onClicked fires on release).
    readonly property int reopenGuardMs: 250

    function register(name, popup, openFn) {
        const next = Object.assign({}, root.entries);
        next[name] = {
            popup: popup,
            open: openFn
        };
        root.entries = next;
    }

    function unregister(name) {
        const next = Object.assign({}, root.entries);
        delete next[name];
        root.entries = next;
        if (root.activeName === name)
            root.activeName = "";
    }

    // Called by PopupBehavior when a popup becomes visible.
    function claim(name) {
        if (root.activeName !== "" && root.activeName !== name) {
            const prev = root.entries[root.activeName];
            if (prev)
                prev.popup.visible = false;
        }
        root.activeName = name;
    }

    // Called by PopupBehavior when a popup becomes hidden.
    function release(name) {
        if (root.activeName === name)
            root.activeName = "";
        root.closedAt[name] = Date.now();
    }

    function closeAll() {
        for (const name in root.entries) {
            const p = root.entries[name].popup;
            if (p.visible)
                p.visible = false;
        }
    }

    // Trigger-button entry point: close if open, otherwise open unless the
    // popup was closed a moment ago (same click that dismissed it).
    function toggle(name) {
        const e = root.entries[name];
        if (!e)
            return;
        if (e.popup.visible) {
            e.popup.visible = false;
        } else if (Date.now() - (root.closedAt[name] || 0) > root.reopenGuardMs && e.open) {
            e.open();
        }
    }

    // Hyprland.focusedWorkspace is reassigned to a *new* object on every
    // workspace switch, so track the id through a plain binding (see the
    // note this replaced in Dashboard.qml).
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    onFocusedWorkspaceIdChanged: root.closeAll()

    IpcHandler {
        target: "popups"

        function open(name: string): string {
            const e = root.entries[name];
            if (!e || !e.open)
                return "unknown or not openable: " + name;
            e.open();
            return "ok";
        }

        function close(): void {
            root.closeAll();
        }

        function list(): string {
            return Object.keys(root.entries).join(",");
        }
    }
}
