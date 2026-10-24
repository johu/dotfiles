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

    Process {
        running: root.iconName.length > 0
        command: root.explicitPath
            ? ["find", root.explicitPath, "-iname", root.iconName + ".*"]
            : ["find", "/usr/share/icons/Papirus-Dark", "/usr/share/icons/hicolor", "/usr/share/pixmaps", "-iname", root.iconName + ".*"]
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
        source: root.resolvedIconPath ? "file://" + root.resolvedIconPath : ""
        visible: root.resolvedIconPath.length > 0
    }
}
