import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Rasterizes a live image:// source (e.g. image://qsimage/<id>/<generation>,
// a notification's embedded avatar pixmap) to a PNG on disk before the
// source notification closes and the buffer behind that URL dies with it.
// grabToImage() needs a real mapped surface to render into - same
// constraint IdleInhibit.qml works around - hence the invisible PanelWindow.
Item {
    id: root

    property var queue: []
    property var current: null

    function cache(key, source, dir, onDone) {
        root.queue.push({
            key: key,
            source: source,
            dir: dir,
            onDone: onDone
        });
        root.pump();
    }

    function pump() {
        if (root.current || root.queue.length === 0)
            return;
        root.current = root.queue.shift();
        grabImage.source = root.current.source;
    }

    function finishCurrent(path) {
        const done = root.current;
        root.current = null;
        if (done.onDone)
            done.onDone(path);
        root.pump();
    }

    function deleteCachedMany(fileUrls) {
        const paths = fileUrls.filter(u => u.startsWith("file://")).map(u => u.slice("file://".length));
        if (paths.length === 0)
            return;
        deleteProc.command = ["rm", "-f", ...paths];
        deleteProc.running = true;
    }

    Process {
        id: deleteProc
    }

    PanelWindow {
        implicitWidth: 64
        implicitHeight: 64
        color: "transparent"
        mask: Region {}

        Image {
            id: grabImage
            anchors.fill: parent
            cache: false
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            opacity: 0

            onStatusChanged: {
                if (!root.current)
                    return;
                if (status === Image.Error) {
                    root.finishCurrent(null);
                } else if (status === Image.Ready) {
                    grabToImage(result => {
                        const path = root.current.dir + "/" + root.current.key + ".png";
                        result.saveToFile(path);
                        root.finishCurrent(path);
                    });
                }
            }
        }
    }
}
