import QtQuick
import Quickshell.Widgets
import Quickshell.Io

// Quickshell's built-in image://icon/ provider never reports a load
// failure: on a missing icon it synthesizes a checkerboard placeholder
// pixmap as a *valid* image, so Image.status stays Ready even when
// nothing was actually found. Resolve icons ourselves via `find` instead,
// and hide entirely when nothing matches.
Item {
    id: root

    property string iconSource: ""
    property int size: 16

    readonly property var parsed: root.iconSource.match(/^image:\/\/icon\/([^?]+)(?:\?path=([^?]+))?/)
    readonly property string iconName: root.parsed ? root.parsed[1] : ""
    readonly property string explicitPath: root.parsed && root.parsed[2] ? root.parsed[2] : ""

    property string resolvedIconPath: ""

    implicitWidth: root.size
    implicitHeight: root.size

    // Only the explicit-path case (icon names qualified with a
    // hicolor/<size>/status/ theme path, e.g. quassel) needs this
    // workaround - Quickshell's provider fails to walk that layout.
    // Plain icon names with no explicit path resolve fine through the
    // native image://icon/ provider (QIcon::fromTheme), which correctly
    // follows theme inheritance/symlinks that our own `find` would miss.
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

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.resolvedIconPath ? "file://" + root.resolvedIconPath : (root.explicitPath.length === 0 ? root.iconSource : "")
        visible: source.toString().length > 0
    }
}
