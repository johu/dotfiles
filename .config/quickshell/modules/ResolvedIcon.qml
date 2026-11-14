import QtQuick
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

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.resolvedIconPath ? "file://" + root.resolvedIconPath : (root.explicitPath.length === 0 ? root.iconSource : "")
        visible: source.toString().length > 0
    }
}
