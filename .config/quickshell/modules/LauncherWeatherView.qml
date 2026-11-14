import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// Weather view of the launcher: a 7-day strip, the hourly curve of the
// selected day (temperature line, rain probability bars) and the details of
// the selected day and hour. Same contract as the other launcher views.
// Fixed geometry (explicit x / y), so nothing shifts with the data.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property var loc: Qt.locale("en_GB")
    readonly property var detail: WeatherData.detail
    readonly property bool ready: WeatherData.detailLoaded && view.detail.daily.length > 0

    property int dayIndex: 0
    property int hour: new Date().getHours()

    readonly property var day: view.ready ? view.detail.daily[view.dayIndex] : null
    readonly property var dayHours: view.ready ? view.detail.hourly.slice(view.dayIndex * 24, view.dayIndex * 24 + 24) : []
    readonly property var hourEntry: view.dayHours[view.hour] ?? null
    readonly property bool isToday: view.dayIndex === 0
    readonly property var cur: view.detail.current

    readonly property int leftWidth: 400
    readonly property int rightX: view.leftWidth + 40

    readonly property var hints: [[
            { keys: ["h", "l"], text: "day" },
            { keys: ["j", "k"], text: "hour" },
            { keys: ["Ctrl-u", "Ctrl-d"], text: "6 hours" },
            { keys: ["t"], text: "now" },
            { keys: ["r"], text: "refresh" },
            { keys: ["q"], text: "back" }
        ]]

    Component.onCompleted: WeatherData.loadDetail(false)

    function moveHour(delta) {
        if (!view.ready)
            return;
        const last = view.detail.hourly.length - 1;
        const idx = Math.max(0, Math.min(view.dayIndex * 24 + view.hour + delta, last));
        view.dayIndex = Math.floor(idx / 24);
        view.hour = idx % 24;
    }

    function moveDay(delta) {
        if (!view.ready)
            return;
        view.dayIndex = Math.max(0, Math.min(view.dayIndex + delta, view.detail.daily.length - 1));
    }

    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_Left:
            view.moveDay(-1);
            return true;
        case Qt.Key_L:
        case Qt.Key_Right:
            view.moveDay(1);
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            view.moveHour(1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.moveHour(-1);
            return true;
        case Qt.Key_D:
            if (ctrl)
                view.moveHour(6);
            return true;
        case Qt.Key_U:
            if (ctrl)
                view.moveHour(-6);
            return true;
        case Qt.Key_T:
        case Qt.Key_Home:
            view.dayIndex = 0;
            view.hour = new Date().getHours();
            return true;
        case Qt.Key_R:
            WeatherData.loadDetail(true);
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    function compass(deg) {
        return ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"][Math.round(deg / 22.5) % 16];
    }

    function clock(d) {
        return Qt.formatTime(d, "HH:mm");
    }

    function mm(v) {
        return (Math.round(v * 10) / 10) + " mm";
    }

    // Rows of the left-hand details: for today the current conditions, for
    // other days the daily summary, then sun times and UV.
    readonly property var metrics: {
        if (!view.ready)
            return [];
        const d = view.day;
        const rows = [];
        if (view.isToday) {
            rows.push(["Feels like", view.cur.feels + "°"]);
            rows.push(["Humidity", view.cur.humidity + " %"]);
            rows.push(["Wind", view.cur.wind + " km/h " + view.compass(view.cur.windDir) + ", gusts " + view.cur.gusts]);
            rows.push(["Pressure", view.cur.pressure + " hPa"]);
            rows.push(["Clouds", view.cur.clouds + " %"]);
            rows.push(["Rain now", view.mm(view.cur.precip)]);
        } else {
            rows.push(["Rain", view.mm(d.precipSum)]);
            rows.push(["Rain chance", d.popMax + " %"]);
            rows.push(["Wind up to", d.windMax + " km/h"]);
        }
        rows.push(["Sunrise", view.clock(d.sunrise)]);
        rows.push(["Sunset", view.clock(d.sunset)]);
        rows.push(["UV index", "" + d.uvMax]);
        return rows;
    }

    // ---- left column ----
    Text {
        x: 0
        y: 0
        width: view.leftWidth
        height: 52
        verticalAlignment: Text.AlignVCenter
        text: "Weather"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 12
        font.bold: true
        renderType: view.textRender
    }

    Text {
        x: 0
        y: 54
        width: view.leftWidth
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: WeatherData.detailLoading ? "Updating…" : (WeatherData.detailError !== "" ? WeatherData.detailError : (WeatherData.detailLoaded ? "Updated " + view.clock(new Date(WeatherData.detailAt)) + " · " + WeatherData.lat.toFixed(2) + ", " + WeatherData.lon.toFixed(2) : "Loading the forecast…"))
        color: WeatherData.detailError !== "" ? Theme.red : Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        renderType: view.textRender
    }

    Item {
        visible: view.ready
        x: 0
        y: 96
        width: view.leftWidth
        height: parent.height - 96

        Image {
            x: 0
            y: 0
            width: 104
            height: 104
            source: view.day ? "file://" + WeatherData.imageForCode(view.isToday ? view.cur.code : view.day.code, view.isToday ? view.cur.isDay : true) : ""
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectFit
        }

        Text {
            x: 124
            y: 0
            width: view.leftWidth - 124
            height: 64
            verticalAlignment: Text.AlignVCenter
            text: view.day ? (view.isToday ? view.cur.temp + "°" : view.day.tMax + "° / " + view.day.tMin + "°") : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 34
            font.bold: true
            renderType: view.textRender
        }

        Text {
            x: 124
            y: 66
            width: view.leftWidth - 124
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: view.day ? WeatherData.descriptionForCode(view.isToday ? view.cur.code : view.day.code) + (view.isToday ? " · " + view.day.tMax + "° / " + view.day.tMin + "°" : "") : ""
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
            elide: Text.ElideRight
            renderType: view.textRender
        }

        Column {
            x: 0
            y: 128
            width: view.leftWidth
            spacing: 4

            Repeater {
                model: view.metrics

                Item {
                    required property var modelData

                    width: view.leftWidth
                    height: 32

                    Text {
                        x: 0
                        width: 130
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData[0]
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        renderType: view.textRender
                    }

                    Text {
                        x: 134
                        width: view.leftWidth - 134
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: modelData[1]
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1
                        elide: Text.ElideRight
                        renderType: view.textRender
                    }
                }
            }
        }

        // Selected hour
        Rectangle {
            x: 0
            y: parent.height - 168
            width: view.leftWidth
            height: 168
            radius: 14
            color: Theme.surface2

            Image {
                x: 14
                y: 14
                width: 56
                height: 56
                source: view.hourEntry ? "file://" + WeatherData.imageForCode(view.hourEntry.code, view.hourEntry.isDay) : ""
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectFit
            }

            Text {
                x: 82
                y: 12
                width: view.leftWidth - 96
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: view.hourEntry ? view.loc.toString(view.hourEntry.time, "ddd d MMM") + ", " + view.clock(view.hourEntry.time) : ""
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                renderType: view.textRender
            }

            Text {
                x: 82
                y: 42
                width: view.leftWidth - 96
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: view.hourEntry ? view.hourEntry.temp + "°  ·  " + WeatherData.descriptionForCode(view.hourEntry.code) : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                elide: Text.ElideRight
                renderType: view.textRender
            }

            Text {
                x: 14
                y: 84
                width: view.leftWidth - 28
                height: 70
                wrapMode: Text.Wrap
                lineHeight: 1.2
                text: view.hourEntry ? "Feels like " + view.hourEntry.feels + "°  ·  Humidity " + view.hourEntry.humidity + " %\nWind " + view.hourEntry.wind + " km/h  ·  Rain " + view.hourEntry.pop + " % (" + view.mm(view.hourEntry.precip) + ")" : ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                renderType: view.textRender
            }
        }
    }

    // ---- separator ----
    Rectangle {
        x: view.leftWidth + 20
        width: 1
        height: parent.height
        color: Theme.surface2
    }

    // ---- 7-day strip ----
    Row {
        visible: view.ready
        x: view.rightX
        y: 0
        spacing: 10

        Repeater {
            model: view.ready ? view.detail.daily : []

            Rectangle {
                id: card

                required property var modelData
                required property int index

                readonly property real cardW: (view.width - view.rightX - 6 * 10) / 7

                width: card.cardW
                height: 168
                radius: 14
                color: card.index === view.dayIndex ? Theme.surface2 : "transparent"
                border.width: card.index === 0 ? 2 : 1
                border.color: card.index === view.dayIndex ? Theme.blue : (card.index === 0 ? Theme.subtext1 : Theme.surface2)

                Text {
                    x: 0
                    y: 8
                    width: parent.width
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: card.index === 0 ? "Today" : view.loc.toString(card.modelData.date, "ddd d")
                    color: card.index === view.dayIndex ? Theme.text : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    renderType: view.textRender
                }

                Image {
                    x: (parent.width - 56) / 2
                    y: 38
                    width: 56
                    height: 56
                    source: "file://" + WeatherData.imageForCode(card.modelData.code, true)
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    x: 0
                    y: 100
                    width: parent.width
                    height: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: card.modelData.tMax + "°  " + card.modelData.tMin + "°"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.bold: true
                    renderType: view.textRender
                }

                Text {
                    x: 0
                    y: 132
                    width: parent.width
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: card.modelData.popMax + " %"
                    color: card.modelData.popMax >= 50 ? Theme.blue : Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: view.textRender
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: view.dayIndex = card.index
                }
            }
        }
    }

    // ---- hourly chart of the selected day ----
    Item {
        id: chart

        visible: view.ready
        x: view.rightX
        y: 192
        width: view.width - view.rightX
        height: view.height - 192

        readonly property int axisW: 44
        readonly property int plotTop: 52
        readonly property int plotH: 260
        readonly property int barsTop: plotTop + plotH + 44
        readonly property int barsH: 100
        readonly property int pad: 22
        readonly property real plotW: width - axisW - 12
        readonly property int n: Math.max(view.dayHours.length, 2)

        readonly property var temps: view.dayHours.map(h => h.temp)
        readonly property real minT: temps.length > 0 ? Math.floor(Math.min.apply(null, temps) - 1) : 0
        readonly property real maxT: temps.length > 0 ? chart.minT + Math.max(1, Math.ceil((Math.ceil(Math.max.apply(null, temps) + 1) - chart.minT) / 4)) * 4 : 4

        function px(i) {
            return chart.axisW + chart.pad + i / (chart.n - 1) * (chart.plotW - 2 * chart.pad);
        }

        function py(t) {
            return chart.plotTop + (chart.maxT - t) / Math.max(1, chart.maxT - chart.minT) * chart.plotH;
        }

        readonly property var points: view.dayHours.map((h, i) => Qt.point(chart.px(i), chart.py(h.temp)))

        Text {
            x: 0
            y: 0
            width: parent.width
            height: 40
            verticalAlignment: Text.AlignVCenter
            text: view.day ? view.loc.toString(view.day.date, "dddd, d MMMM") : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 9
            font.bold: true
            renderType: view.textRender
        }

        // temperature grid + axis
        Repeater {
            model: 5

            Item {
                required property int index

                readonly property real value: chart.minT + index * (chart.maxT - chart.minT) / 4

                Rectangle {
                    x: chart.axisW
                    y: chart.py(parent.value)
                    width: chart.plotW
                    height: 1
                    color: Theme.surface2
                    opacity: 0.7
                }

                Text {
                    x: 0
                    y: chart.py(parent.value) - 10
                    width: chart.axisW - 8
                    height: 20
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(parent.value) + "°"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    renderType: view.textRender
                }
            }
        }

        // hour cursor
        Rectangle {
            x: chart.px(view.hour) - 1
            y: chart.plotTop
            width: 2
            height: chart.barsTop + chart.barsH - chart.plotTop
            color: Theme.blue
            opacity: 0.5
        }

        // temperature line
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.yellow
                strokeWidth: 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: chart.points
                }
            }
        }

        Repeater {
            model: view.dayHours

            Rectangle {
                required property var modelData
                required property int index

                readonly property bool sel: index === view.hour

                x: chart.px(index) - width / 2
                y: chart.py(modelData.temp) - height / 2
                width: sel ? 14 : 7
                height: width
                radius: width / 2
                color: sel ? Theme.blue : Theme.yellow
                border.width: sel ? 2 : 0
                border.color: Theme.base
            }
        }

        // temperature labels every 3 hours and for the selected hour
        Repeater {
            model: view.dayHours

            Text {
                required property var modelData
                required property int index

                visible: index % 3 === 0 || index === view.hour
                x: chart.px(index) - 22
                y: chart.py(modelData.temp) - 34
                width: 44
                height: 22
                horizontalAlignment: Text.AlignHCenter
                text: modelData.temp + "°"
                color: index === view.hour ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: index === view.hour
                renderType: view.textRender
            }
        }

        // rain probability bars
        Text {
            x: chart.axisW
            y: chart.barsTop - 24
            width: 200
            height: 20
            text: "Rain chance"
            color: Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            renderType: view.textRender
        }

        Repeater {
            model: view.dayHours

            Item {
                required property var modelData
                required property int index

                Rectangle {
                    x: chart.px(index) - 7
                    y: chart.barsTop + chart.barsH * (1 - modelData.pop / 100)
                    width: 14
                    height: Math.max(2, chart.barsH * modelData.pop / 100)
                    radius: 3
                    color: Theme.blue
                    opacity: index === view.hour ? 1 : 0.6
                }
            }
        }

        // hour labels
        Repeater {
            model: view.dayHours

            Text {
                required property var modelData
                required property int index

                visible: index % 3 === 0 || index === view.hour
                x: chart.px(index) - 22
                y: chart.barsTop + chart.barsH + 8
                width: 44
                height: 22
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatTime(modelData.time, "HH")
                color: index === view.hour ? Theme.text : Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: index === view.hour
                renderType: view.textRender
            }
        }
    }

    Text {
        visible: !view.ready
        x: view.rightX
        y: 200
        width: view.width - view.rightX
        horizontalAlignment: Text.AlignHCenter
        text: WeatherData.detailError !== "" ? WeatherData.detailError : "Loading the forecast…"
        color: WeatherData.detailError !== "" ? Theme.red : Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 6
        renderType: view.textRender
    }
}
