pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Location lives in the same untracked secrets.json as icalUrls - not
    // strictly a secret, but keeps all user-specific config in one place:
    // { "weatherLocation": { "lat": 53.0793, "lon": 8.8017 } }
    readonly property string secretsPath: "/home/johu/.config/quickshell/secrets.json"

    property real lat: 0
    property real lon: 0
    property bool loaded: false

    property int currentTemp: 0
    property int currentCode: 0
    property bool currentIsDay: true
    property int currentHumidity: 0
    property int currentWindSpeed: 0
    property int currentPrecipProb: 0

    // Today + next 3 days: { date, code, tempMax, tempMin }
    property var daily: []

    // Next ~24h at 3h resolution, starting at the current hour: { time, temp }
    property var hourly: []

    function reload() {
        configReader.running = true;
    }

    Component.onCompleted: reload()

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.reload()
    }

    Process {
        id: configReader
        command: ["cat", root.secretsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                let loc = null;
                try {
                    const cfg = JSON.parse(this.text);
                    loc = cfg.weatherLocation || null;
                } catch (e) {
                    // No secrets.json yet, or it's invalid - weather just stays unloaded.
                }
                if (loc && typeof loc.lat === "number" && typeof loc.lon === "number") {
                    root.lat = loc.lat;
                    root.lon = loc.lon;
                    fetchProc.running = true;
                }
            }
        }
    }

    Process {
        id: fetchProc
        command: ["curl", "-sL", "--max-time", "10", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m,wind_speed_10m&hourly=temperature_2m,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.currentTemp = Math.round(data.current.temperature_2m);
                    root.currentCode = data.current.weather_code;
                    root.currentIsDay = data.current.is_day === 1;
                    root.currentHumidity = Math.round(data.current.relative_humidity_2m);
                    root.currentWindSpeed = Math.round(data.current.wind_speed_10m);

                    // Hourly arrays are only ever on the hour, while
                    // current.time carries minutes - round to the nearest
                    // hour (not just floor) so the trend's start lines up
                    // with whichever hourly reading is actually closest.
                    const hourKey = iso => iso.slice(0, 13);
                    const curDate = new Date(data.current.time);
                    curDate.setMinutes(curDate.getMinutes() + 30, 0, 0);
                    curDate.setMinutes(0, 0, 0);
                    const pad = n => String(n).padStart(2, "0");
                    const curHourKey = curDate.getFullYear() + "-" + pad(curDate.getMonth() + 1) + "-" + pad(curDate.getDate()) + "T" + pad(curDate.getHours());
                    const hourlyTime = data.hourly.time;
                    const startIdx = hourlyTime.findIndex(t => hourKey(t) === curHourKey);

                    root.currentPrecipProb = startIdx >= 0 ? Math.round(data.hourly.precipitation_probability[startIdx]) : 0;

                    const trend = [];
                    if (startIdx >= 0) {
                        for (let i = 0; i < 8; i++) {
                            const hi = startIdx + i * 3;
                            if (hi >= hourlyTime.length)
                                break;
                            trend.push({
                                time: new Date(hourlyTime[hi]),
                                temp: Math.round(data.hourly.temperature_2m[hi])
                            });
                        }
                    }
                    root.hourly = trend;

                    const days = [];
                    const time = data.daily.time;
                    for (let i = 0; i < time.length; i++) {
                        days.push({
                            date: new Date(time[i]),
                            code: data.daily.weather_code[i],
                            tempMax: Math.round(data.daily.temperature_2m_max[i]),
                            tempMin: Math.round(data.daily.temperature_2m_min[i])
                        });
                    }
                    root.daily = days;
                    root.loaded = true;
                } catch (e) {
                    // Network hiccup or malformed response - keep showing the last good data.
                }
            }
        }
    }

    // Hand-drawn flat SVGs in the tokyonight palette (own assets dir,
    // tracked in dotfiles) instead of Quickshell's image://icon/ provider
    // (QIcon::fromTheme() + flat QPixmap only, no real hicolor walk - see
    // ResolvedIcon.qml's workaround) or a third-party icon theme.
    readonly property string assetsDir: "/home/johu/.config/quickshell/assets/weather"

    function imageForCode(code, isDay) {
        if (code === 0)
            return root.assetsDir + (isDay ? "/clear-day.svg" : "/clear-night.svg");
        if (code <= 3) {
            if (code === 3)
                return root.assetsDir + "/cloudy.svg";
            return root.assetsDir + (isDay ? "/partly-cloudy-day.svg" : "/partly-cloudy-night.svg");
        }
        if (code === 45 || code === 48)
            return root.assetsDir + "/fog.svg";
        if (code >= 51 && code <= 67)
            return root.assetsDir + "/rain.svg";
        if (code >= 71 && code <= 77)
            return root.assetsDir + "/snow.svg";
        if (code >= 80 && code <= 82)
            return root.assetsDir + "/rain-showers.svg";
        if (code >= 85 && code <= 86)
            return root.assetsDir + "/snow.svg";
        if (code >= 95)
            return root.assetsDir + "/thunderstorm.svg";
        return root.assetsDir + "/cloudy.svg";
    }

    function descriptionForCode(code) {
        if (code === 0)
            return "Clear";
        if (code <= 3)
            return "Partly cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 51 && code <= 57)
            return "Drizzle";
        if (code >= 61 && code <= 67)
            return "Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Rain showers";
        if (code >= 85 && code <= 86)
            return "Snow showers";
        if (code >= 95)
            return "Thunderstorm";
        return "Cloudy";
    }
}
