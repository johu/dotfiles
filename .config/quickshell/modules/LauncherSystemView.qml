import QtQuick
import "SysMonFormat.js" as Fmt

// System view of the launcher: a Performance page (live tiles, history graphs
// and stats per resource) and a Processes page (grouped table, sort, filter,
// kill). Data comes from SysMonCollector, which runs scripts/sysmon.py only
// while this view exists. Same contract as the other views.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1800
    readonly property int preferredHeight: 1040

    // "performance" | "processes"
    property string page: "performance"
    readonly property var current: view.page === "performance" ? perf : procs

    SysMonCollector {
        id: collector
    }

    function handleEscape() {
        return view.current.handleEscape();
    }

    readonly property var hints: view.current.hints

    function handleKey(event) {
        if (event.key === Qt.Key_Tab) {
            view.page = view.page === "performance" ? "processes" : "performance";
            return true;
        }
        if (view.current.handleKey(event))
            return true;
        switch (event.key) {
        case Qt.Key_1:
            view.page = "performance";
            return true;
        case Qt.Key_2:
            view.page = "processes";
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    // ---- header ----
    Text {
        x: 0
        y: 0
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "System"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    Row {
        x: 200
        y: 4
        spacing: 12

        Repeater {
            model: [{ id: "performance", title: "Performance", n: "1" }, { id: "processes", title: "Processes", n: "2" }]

            Rectangle {
                required property var modelData

                readonly property bool on: view.page === modelData.id

                width: 190
                height: 44
                radius: 14
                color: on ? Theme.surface2 : "transparent"
                border.width: on ? 2 : 1
                border.color: on ? Theme.blue : Theme.surface2

                Text {
                    x: 16
                    width: 20
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.n
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: view.textRender
                }

                Text {
                    x: 40
                    width: parent.width - 52
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.title
                    color: on ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.bold: on
                    renderType: view.textRender
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: view.page = modelData.id
                }
            }
        }
    }

    Text {
        x: view.width - width
        y: 0
        width: 760
        height: 28
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: collector.ready ? "up " + Fmt.duration(collector.s.uptime) + "   ·   load " + collector.s.cpu.load.map(x => x.toFixed(2)).join("  ") : "Starting…"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        renderType: view.textRender
    }

    Text {
        x: view.width - width
        y: 28
        width: 760
        height: 24
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        text: collector.ready ? collector.s.host + "  ·  Linux " + collector.s.kernel : ""
        color: Theme.subtext1
        opacity: 0.8
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        renderType: view.textRender
    }

    // ---- pages ----
    SysMonPerformance {
        id: perf

        visible: view.page === "performance"
        x: 0
        y: 70
        width: view.width
        height: view.height - 70
        col: collector
        textRender: view.textRender
        onOpenProcesses: key => {
            procs.sortBy(key);
            view.page = "processes";
        }
    }

    SysMonProcesses {
        id: procs

        visible: view.page === "processes"
        x: 0
        y: 70
        width: view.width
        height: view.height - 70
        col: collector
        textRender: view.textRender
    }

    Text {
        visible: !collector.ready
        x: 0
        y: 300
        width: view.width
        horizontalAlignment: Text.AlignHCenter
        text: "Collecting the first sample…"
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 6
        font.italic: true
        renderType: view.textRender
    }
}
