import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

// image://icon/ never reports a load failure (a missing icon becomes a
// valid checkerboard pixmap), so resolve icons with `find` and hide when
// nothing matches.
Item {
    id: root

    property string iconSource: ""
    property int size: 16

    readonly property var parsed: root.iconSource.match(/^image:\/\/icon\/([^?]+)(?:\?path=([^?]+))?/)
    readonly property string iconName: root.parsed ? root.parsed[1] : ""
    readonly property string explicitPath: root.parsed && root.parsed[2] ? root.parsed[2] : ""

    property string resolvedIconPath: ""

    // Opt-in (off by default, so other callers are unchanged): when the theme
    // can't resolve a plain icon name, look in app-private icon dirs
    // (/usr/share/<app>/icons, e.g. quassel's connect-quassel). Used by
    // tray menus, where dbusmenu icon names carry no IconThemePath.
    property bool searchAppIconDirs: false
    readonly property bool needsAppSearch: root.searchAppIconDirs && root.iconName.length > 0 && root.explicitPath.length === 0 && Quickshell.iconPath(root.iconName, true) === ""
    property string appIconPath: ""

    implicitWidth: root.size
    implicitHeight: root.size

    // Only explicit hicolor/<size>/status/ paths (e.g. quassel) need this;
    // Quickshell's provider can't walk that layout. Plain names resolve via
    // image://icon/, which follows theme inheritance that `find` misses.
    Process {
        running: root.explicitPath.length > 0
        command: ["find", root.explicitPath, "-iname", root.iconName + ".*"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.split("\n").find(line => line.length > 0);
                root.resolvedIconPath = match || "";
            }
        }
    }

    Process {
        running: root.needsAppSearch
        command: ["sh", "-c", "for d in /usr/share/*/icons /usr/local/share/*/icons; do [ -d \"$d\" ] && find \"$d\" \\( -name \"$1.svg\" -o -name \"$1.png\" \\); done | awk 'NR==1{f=$0} /dark/ && !d{d=$0} END{print d ? d : f}'", "sh", root.iconName]
        stdout: StdioCollector {
            onStreamFinished: root.appIconPath = this.text.trim()
        }
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.resolvedIconPath ? "file://" + root.resolvedIconPath : (root.appIconPath ? "file://" + root.appIconPath : (root.explicitPath.length === 0 && !root.needsAppSearch ? root.iconSource : ""))
        visible: source.toString().length > 0
    }
}
