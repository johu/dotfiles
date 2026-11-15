import QtQuick
import "SysMonFormat.js" as Fmt

// Performance page of the system view: a sidebar of live tiles (CPU, memory,
// GPU, storage, each disk, each network interface, temperatures, battery) and
// for the selected one a history graph, a stats grid and resource specific
// extras (per-core bars, memory composition, filesystems, sensors, top
// consumers). Fixed geometry; same key contract as the other pages.
Item {
    id: page

    property var col
    property int textRender: Text.NativeRendering
    property string selectedKey: "cpu"
    property int range: 60

    signal openProcesses(string sortKey)

    readonly property var keys: page.col ? page.col.keys : []
    readonly property int sideW: 400
    readonly property int tileH: 84
    readonly property int detailX: page.sideW + 40
    readonly property int detailW: page.width - page.detailX
    readonly property var info: page.col ? page.col.info(page.selectedKey) : ({})
    readonly property string type: page.selectedKey.split(":")[0]
    readonly property bool hasGraph: (page.info.series ?? []).length > 0

    onKeysChanged: if (page.keys.length > 0 && page.keys.indexOf(page.selectedKey) < 0)
        page.selectedKey = page.keys[0]

    function handleEscape() {
        return false;
    }

    readonly property var hints: [[
            { keys: ["j", "k"], text: "resource" },
            { keys: ["h", "l"], text: "1 / 5 minutes" },
            { keys: ["↵"], text: "show processes", ghost: page.type !== "cpu" && page.type !== "mem" },
            { keys: ["Tab"], text: "processes" },
            { keys: ["q"], text: "back" }
        ]]

    function select(delta) {
        const i = page.keys.indexOf(page.selectedKey);
        page.selectedKey = page.keys[Math.max(0, Math.min(page.keys.length - 1, (i < 0 ? 0 : i) + delta))];
    }

    function handleKey(event) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_J:
        case Qt.Key_Down:
            page.select(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            page.select(-1);
            return true;
        case Qt.Key_G:
            page.selectedKey = page.keys[shift ? page.keys.length - 1 : 0] ?? page.selectedKey;
            return true;
        case Qt.Key_H:
        case Qt.Key_Left:
            page.range = 60;
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            page.range = 300;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (page.type === "cpu" || page.type === "mem")
                page.openProcesses(page.type);
            return true;
        }
        return false;
    }

    // ---- sidebar ----
    ListView {
        id: side

        x: 0
        y: 0
        width: page.sideW
        height: page.height
        clip: true
        spacing: 8
        model: page.keys
        currentIndex: page.keys.indexOf(page.selectedKey)
        onCurrentIndexChanged: if (side.currentIndex >= 0)
            side.positionViewAtIndex(side.currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: tile

            required property string modelData

            readonly property var t: page.col.info(tile.modelData)
            readonly property bool sel: tile.modelData === page.selectedKey

            width: side.width
            height: page.tileH
            radius: 16
            color: tile.sel ? Theme.surface2 : Theme.surface1
            border.width: tile.sel ? 2 : 0
            border.color: tile.t.color ?? Theme.blue

            Text {
                x: 20
                y: 8
                width: parent.width - 40
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: tile.t.title ?? ""
                color: tile.sel ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                elide: Text.ElideRight
                renderType: page.textRender
            }

            Text {
                x: 20
                y: 36
                width: parent.width - 40
                height: 20
                verticalAlignment: Text.AlignVCenter
                text: tile.t.tile ?? ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                renderType: page.textRender
            }

            // sparkline along the bottom edge
            LineGraph {
                visible: (tile.t.series ?? []).length > 0
                x: 20
                y: tile.height - 24
                width: tile.width - 40
                height: 18
                compact: true
                series: tile.t.series ?? []
                maxValue: tile.t.max ?? 100
                unit: tile.t.unit ?? "%"
                samples: 60
            }

            // storage tile: bar of the fullest filesystem instead
            Rectangle {
                visible: (tile.t.series ?? []).length === 0
                x: 20
                y: tile.height - 18
                width: tile.width - 40
                height: 8
                radius: 4
                color: Theme.surface2

                Rectangle {
                    width: parent.width * Math.min(100, tile.t.worst ?? 0) / 100
                    height: parent.height
                    radius: 4
                    color: (tile.t.worst ?? 0) > 90 ? Theme.red : Theme.sky
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.selectedKey = tile.modelData
            }
        }
    }

    Rectangle {
        x: page.sideW + 20
        width: 1
        height: parent.height
        color: Theme.surface2
    }

    // ---- detail header ----
    Text {
        x: page.detailX
        y: 0
        width: page.detailW - 300
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: page.info.title ?? ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 18
        font.bold: true
        renderType: page.textRender
    }

    Text {
        x: page.detailX
        y: 54
        width: page.detailW - 300
        height: 26
        verticalAlignment: Text.AlignVCenter
        text: page.info.sub ?? ""
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        elide: Text.ElideRight
        renderType: page.textRender
    }

    // range chips
    Row {
        visible: page.hasGraph
        x: page.detailX + page.detailW - width
        y: 8
        spacing: 10

        Repeater {
            model: [{ label: "1 min", value: 60 }, { label: "5 min", value: 300 }]

            Rectangle {
                required property var modelData

                width: 110
                height: 40
                radius: 12
                color: page.range === modelData.value ? Theme.surface2 : "transparent"
                border.width: 1
                border.color: Theme.surface2

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: page.range === modelData.value ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    renderType: page.textRender
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.range = modelData.value
                }
            }
        }
    }

    // legend for two-series graphs
    Row {
        visible: page.hasGraph && (page.info.legend ?? []).length > 0
        x: page.detailX
        y: 90
        spacing: 24
        height: 22

        Repeater {
            model: page.info.legend ?? []

            Row {
                required property var modelData

                spacing: 8

                Rectangle {
                    y: 5
                    width: 22
                    height: 4
                    radius: 2
                    color: modelData[1]
                }

                Text {
                    text: modelData[0]
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: page.textRender
                }
            }
        }
    }

    // ---- graph ----
    readonly property int graphY: (page.info.legend ?? []).length > 0 ? 118 : 94
    readonly property int graphH: 330

    Rectangle {
        visible: page.hasGraph
        x: page.detailX
        y: page.graphY
        width: page.detailW
        height: page.graphH
        radius: 16
        color: Theme.surface1
    }

    LineGraph {
        visible: page.hasGraph
        x: page.detailX
        y: page.graphY
        width: page.detailW
        height: page.graphH
        series: page.info.series ?? []
        maxValue: page.info.max ?? 100
        unit: page.info.unit ?? "%"
        samples: page.range
        textRender: page.textRender
    }

    // ---- stats grid ----
    readonly property int statsY: page.hasGraph ? page.graphY + page.graphH + 24 : 110
    readonly property int statCols: 4

    Repeater {
        model: page.info.stats ?? []

        Item {
            required property var modelData
            required property int index

            x: page.detailX + (index % page.statCols) * (page.detailW / page.statCols)
            y: page.statsY + Math.floor(index / page.statCols) * 78
            width: page.detailW / page.statCols - 16
            height: 70

            Text {
                width: parent.width
                height: 22
                text: modelData[0]
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                elide: Text.ElideRight
                renderType: page.textRender
            }

            Text {
                y: 26
                width: parent.width
                height: 36
                text: modelData[1]
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 8
                font.bold: true
                elide: Text.ElideRight
                renderType: page.textRender
            }
        }
    }

    readonly property int extrasY: page.statsY + Math.ceil((page.info.stats ?? []).length / page.statCols) * 78 + 16
    readonly property int extrasH: page.height - page.extrasY

    // ---- extras: CPU cores + top processes ----
    Item {
        visible: page.type === "cpu"
        x: page.detailX
        y: page.extrasY
        width: page.detailW
        height: page.extrasH

        Text {
            height: 26
            text: "Cores (" + (page.col.s.cpu ? page.col.s.cpu.threads : 0) + " threads)"
            color: Theme.blue
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            renderType: page.textRender
        }

        // one bar per thread, filled from the bottom
        Row {
            y: 40
            height: parent.height - 50
            spacing: 4

            Repeater {
                model: page.col.s.cpu ? page.col.s.cpu.cores : []

                Rectangle {
                    required property real modelData

                    width: Math.max(6, Math.min(26, (page.detailW * 0.55 - 4 * 32) / 32))
                    height: parent.height
                    radius: 4
                    color: Theme.surface1

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * Math.min(100, modelData) / 100)
                        radius: 4
                        color: modelData > 85 ? Theme.red : (modelData > 60 ? Theme.yellow : Theme.blue)
                    }
                }
            }
        }

        TopList {
            x: parent.width * 0.62
            width: parent.width * 0.38
            height: parent.height
            title: "Top processes by CPU"
            rows: page.type === "cpu" ? page.col.topBy("cpu", 6).map(r => ({ name: r.name, value: r.value, text: r.value.toFixed(1) + " %", frac: Math.min(1, r.value / 100) })) : []
            barColor: Theme.blue
            textRender: page.textRender
        }
    }

    // ---- extras: memory composition + top processes ----
    Item {
        visible: page.type === "mem"
        x: page.detailX
        y: page.extrasY
        width: page.detailW
        height: page.extrasH

        Text {
            height: 26
            text: "Composition"
            color: Theme.mauve
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            renderType: page.textRender
        }

        Row {
            y: 40
            width: parent.width * 0.58
            height: 36
            spacing: 2

            Repeater {
                readonly property var m: page.col.s.mem ?? ({ total: 1, used: 0, cached: 0, buffers: 0, free: 0 })

                model: [
                    { c: Theme.mauve, v: m.used }, { c: Theme.blue, v: m.cached }, { c: Theme.sky, v: m.buffers }, { c: Theme.surface2, v: Math.max(0, m.free) }
                ]

                Rectangle {
                    required property var modelData

                    width: Math.max(0, (page.detailW * 0.58 - 6) * modelData.v / Math.max(1, page.col.s.mem ? page.col.s.mem.total : 1))
                    height: 36
                    radius: 6
                    color: modelData.c
                }
            }
        }

        Row {
            y: 90
            spacing: 24

            Repeater {
                model: [["In use", Theme.mauve], ["Cached", Theme.blue], ["Buffers", Theme.sky], ["Free", Theme.surface2]]

                Row {
                    required property var modelData

                    spacing: 8

                    Rectangle {
                        y: 4
                        width: 16
                        height: 16
                        radius: 4
                        color: modelData[1]
                    }

                    Text {
                        text: modelData[0]
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        renderType: page.textRender
                    }
                }
            }
        }

        TopList {
            x: parent.width * 0.62
            width: parent.width * 0.38
            height: parent.height
            title: "Top processes by memory"
            rows: page.type === "mem" ? page.col.topBy("mem", 6).map(r => ({ name: r.name, value: r.value, text: Fmt.bytes(r.value), frac: page.col.s.mem ? Math.min(1, r.value / page.col.s.mem.total * 4) : 0 })) : []
            barColor: Theme.mauve
            textRender: page.textRender
        }
    }

    // ---- extras: filesystems ----
    Column {
        visible: page.type === "storage"
        x: page.detailX
        y: page.extrasY
        width: page.detailW
        spacing: 18

        Repeater {
            model: page.type === "storage" && page.col.s.mounts ? page.col.s.mounts : []

            Item {
                required property var modelData

                width: page.detailW
                height: 74

                Text {
                    width: 420
                    height: 30
                    text: modelData.mount
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 6
                    font.bold: true
                    elide: Text.ElideRight
                    renderType: page.textRender
                }

                Text {
                    x: 430
                    width: parent.width - 430
                    height: 30
                    horizontalAlignment: Text.AlignRight
                    text: Fmt.bytes(modelData.used) + " of " + Fmt.bytes(modelData.total) + "   " + modelData.percent.toFixed(0) + " %"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    renderType: page.textRender
                }

                Text {
                    y: 32
                    width: 420
                    height: 20
                    text: modelData.device + "  ·  " + modelData.fs
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: page.textRender
                }

                Rectangle {
                    y: 56
                    width: parent.width
                    height: 12
                    radius: 6
                    color: Theme.surface1

                    Rectangle {
                        width: parent.width * Math.min(100, modelData.percent) / 100
                        height: parent.height
                        radius: 6
                        color: modelData.percent > 90 ? Theme.red : (modelData.percent > 75 ? Theme.yellow : Theme.sky)
                    }
                }
            }
        }
    }

    // ---- extras: sensors ----
    Item {
        visible: page.type === "temps"
        x: page.detailX
        y: page.hasGraph ? page.graphY + page.graphH + 20 : 110
        width: page.detailW
        height: page.height - y

        Text {
            height: 26
            text: "Sensors"
            color: Theme.maroon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            renderType: page.textRender
        }

        Grid {
            y: 36
            columns: 2
            columnSpacing: 40
            rowSpacing: 4

            Repeater {
                model: page.type === "temps" ? ((page.col.s.temps ?? []).concat((page.col.s.gpu ?? []).filter(g => g.temp !== null).map(g => ({ chip: "gpu", label: g.name, value: g.temp })))) : []

                Item {
                    required property var modelData

                    width: (page.detailW - 40) / 2
                    height: 32

                    Text {
                        width: 150
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.dev && modelData.dev !== modelData.chip && modelData.chip === "nvme" ? modelData.dev : modelData.chip
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        elide: Text.ElideRight
                        renderType: page.textRender
                    }

                    Text {
                        x: 156
                        width: 190
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.label
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        elide: Text.ElideRight
                        renderType: page.textRender
                    }

                    Rectangle {
                        x: 360
                        y: 11
                        width: parent.width - 360 - 90
                        height: 10
                        radius: 5
                        color: Theme.surface1

                        Rectangle {
                            width: parent.width * Math.min(100, modelData.value) / 100
                            height: parent.height
                            radius: 5
                            color: modelData.value > 85 ? Theme.red : (modelData.value > 70 ? Theme.yellow : Theme.maroon)
                        }
                    }

                    Text {
                        x: parent.width - 80
                        width: 80
                        height: parent.height
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: Math.round(modelData.value) + " °C"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        renderType: page.textRender
                    }
                }
            }
        }

        Text {
            visible: (page.col.s.fans ?? []).length > 0
            y: 36 + Math.ceil(((page.col.s.temps ?? []).length + 1) / 2) * 36 + 16
            text: (page.col.s.fans ?? []).map(f => f.label + " " + f.rpm + " rpm").join("     ")
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            renderType: page.textRender
        }
    }

    // A small ranked list: name, value text and a bar.
    component TopList: Item {
        id: tl

        property string title: ""
        property var rows: []
        property color barColor: Theme.blue
        property int textRender: Text.NativeRendering

        Text {
            height: 26
            text: tl.title
            color: tl.barColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            renderType: tl.textRender
        }

        Repeater {
            model: tl.rows

            Item {
                required property var modelData
                required property int index

                y: 40 + index * 34
                anchors.left: parent.left
                anchors.right: parent.right
                height: 30

                Text {
                    anchors.left: parent.left
                    width: parent.width * 0.36
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    elide: Text.ElideRight
                    renderType: tl.textRender
                }

                Rectangle {
                    x: parent.width * 0.38
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(3, parent.width * 0.32 * modelData.frac)
                    height: 10
                    radius: 5
                    color: tl.barColor
                }

                Text {
                    anchors.right: parent.right
                    width: parent.width * 0.26
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.text
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    renderType: tl.textRender
                }
            }
        }
    }
}
