import QtQuick
import QtQuick.Layouts

// Card for Dashboard.qml's expanded detail view. Purely presentational -
// reads straight from the WeatherData singleton, same as Calendar.qml
// reading CalendarEvents directly (no logic-instance indirection needed).
// Loosely modeled on Google's weather search card: big current reading +
// precip/humidity/wind line, an hourly temperature trend, then a row of
// day cards - condensed to fit the dashboard's ~300px width.
Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.surface2
    implicitWidth: layout.implicitWidth + 24
    implicitHeight: layout.implicitHeight + 20

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Current conditions: big icon + temp, with precip/humidity/wind
        // alongside it.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Image {
                source: "file://" + WeatherData.imageForCode(WeatherData.currentCode, WeatherData.currentIsDay)
                width: 48
                height: 48
                sourceSize.width: 48
                sourceSize.height: 48
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: WeatherData.currentTemp + "\u00b0"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 26
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: "Precip " + WeatherData.currentPrecipProb + "%"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 3
                }

                Text {
                    text: "Humidity " + WeatherData.currentHumidity + "%"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 3
                }

                Text {
                    text: "Wind " + WeatherData.currentWindSpeed + " km/h"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 3
                }
            }
        }

        // Hourly temperature trend - a simple filled sparkline (Canvas)
        // with hour/temp labels underneath, roughly 3h apart. Not pixel-
        // aligned to the canvas's own per-point x positions (RowLayout
        // divides by count, Canvas divides by count-1) - an acceptable
        // approximation at this widget's small scale.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: WeatherData.hourly.length > 1

            Canvas {
                id: sparkline
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                property var trend: WeatherData.hourly
                onTrendChanged: requestPaint()
                onWidthChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const pts = trend;
                    if (!pts || pts.length < 2)
                        return;

                    const temps = pts.map(p => p.temp);
                    let minT = Math.min(...temps);
                    let maxT = Math.max(...temps);
                    if (minT === maxT) {
                        minT -= 1;
                        maxT += 1;
                    }
                    const pad = 4;
                    const n = pts.length;
                    const stepX = width / (n - 1);
                    const yFor = t => pad + (1 - (t - minT) / (maxT - minT)) * (height - pad * 2);

                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (let i = 0; i < n; i++)
                        ctx.lineTo(i * stepX, yFor(temps[i]));
                    ctx.lineTo((n - 1) * stepX, height);
                    ctx.closePath();
                    ctx.fillStyle = "rgba(224, 175, 104, 0.22)";
                    ctx.fill();

                    ctx.beginPath();
                    for (let i = 0; i < n; i++) {
                        const x = i * stepX, y = yFor(temps[i]);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = Theme.yellow;
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: WeatherData.hourly

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatTime(modelData.time, "hh:00")
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.temp + "\u00b0"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }
                }
            }
        }

        // Daily forecast - today + next 3 days as compact cards.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: WeatherData.daily

                delegate: Rectangle {
                    id: dayCard
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: dayCol.implicitHeight + 12
                    radius: Theme.radius - 4
                    color: index === 0 ? Qt.lighter(Theme.surface1, 1.3) : "transparent"

                    ColumnLayout {
                        id: dayCol
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: dayCard.index === 0 ? "Today" : Qt.locale("en_GB").dayName(dayCard.modelData.date.getDay(), Locale.ShortFormat)
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: "file://" + WeatherData.imageForCode(dayCard.modelData.code, true)
                            width: 28
                            height: 28
                            sourceSize.width: 28
                            sourceSize.height: 28
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: dayCard.modelData.tempMax + "\u00b0"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: dayCard.modelData.tempMin + "\u00b0"
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                        }
                    }
                }
            }
        }
    }
}
