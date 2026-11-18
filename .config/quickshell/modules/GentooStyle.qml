pragma Singleton
import QtQuick

// Shared look of the Gentoo launcher view (colors, text rendering). The view sets
// textRender from the launcher's zoom-dependent renderer.
QtObject {
    property int textRender: Text.NativeRendering
    readonly property color dim: "#9aa3cc"
    readonly property color faint: "#7e87ad"
    readonly property color cardColor: Theme.base
    readonly property color rowSelected: Theme.surface2
    readonly property color amber: Theme.yellow

    // repository colors, stable per name
    function repoColor(name) {
        const map = { gentoo: Theme.blue, guru: Theme.green, kde: Theme.maroon, hyproverlay: Theme.mauve, "steam-overlay": Theme.teal, johu: Theme.yellow, crossdev: Theme.pink };
        if (map[name])
            return map[name];
        const pal = [Theme.lavender, Theme.sky, Theme.red, Theme.pink];
        let h = 0;
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 997;
        return pal[h % pal.length];
    }
}
