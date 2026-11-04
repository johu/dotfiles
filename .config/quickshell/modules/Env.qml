pragma Singleton
import QtQuick
import Quickshell

QtObject {
    function targetScreen() {
        const name = Quickshell.env("QS_BAR_SCREEN");
        if (name) {
            const match = Quickshell.screens.find(s => s.name === name);
            if (match)
                return match;
        }
        return Quickshell.screens[0] ?? null;
    }
}
