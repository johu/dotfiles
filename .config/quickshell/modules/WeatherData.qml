pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Location is read from the untracked secrets.json (not a secret, but keeps
    // user config in one place):
    // { "weatherLocation": { "lat": 53.0793, "lon": 8.8017 } }
    readonly property string secretsPath: Quickshell.shellPath("secrets.json")

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

    // Retry soon after a failed card fetch instead of waiting for the 15 min tick.
    Timer {
        id: retryTimer
        interval: 20 * 1000
        onTriggered: if (!root.loaded) root.reload()
    }

    // Fill the card fields from the detailed forecast, so the cards and the
    // launcher view never disagree about whether data is available.
    function applyDetailToCard() {
        const d = root.detail;
        if (!d.current || d.hourly.length === 0 || d.daily.length === 0)
            return;
        root.currentTemp = d.current.temp;
        root.currentCode = d.current.code;
        root.currentIsDay = d.current.isDay;
        root.currentHumidity = d.current.humidity;
        root.currentWindSpeed = d.current.wind;

        const now = new Date();
        now.setMinutes(now.getMinutes() + 30, 0, 0);
        now.setMinutes(0, 0, 0);
        const startIdx = d.hourly.findIndex(h => h.time.getTime() >= now.getTime());
        root.currentPrecipProb = startIdx >= 0 ? d.hourly[startIdx].pop : 0;
        const trend = [];
        if (startIdx >= 0) {
            for (let i = 0; i < 8; i++) {
                const hi = startIdx + i * 3;
                if (hi >= d.hourly.length)
                    break;
                trend.push({ time: d.hourly[hi].time, temp: d.hourly[hi].temp });
            }
        }
        root.hourly = trend;
        root.daily = d.daily.slice(0, 4).map(y => ({ date: y.date, code: y.code, tempMax: y.tMax, tempMin: y.tMin }));
        root.loaded = true;
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

                    // Hourly data is on the hour but current.time has minutes; round (not
                    // floor) so the trend starts at the closest reading.
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
                    if (!root.loaded)
                        retryTimer.restart();
                }
            }
        }
    }

    // ---- Detailed forecast for the launcher's weather view ----
    // Fetched on demand (loadDetail), not every 15 minutes like the card data:
    // detail = { current, hourly[168], daily[7] }, all from one open-meteo call.
    property bool detailLoaded: false
    property bool detailLoading: false
    property string detailError: ""
    property var detail: ({ current: null, hourly: [], daily: [] })
    property real detailAt: 0

    function loadDetail(force) {
        if (root.detailLoading)
            return;
        if (!force && root.detailLoaded && Date.now() - root.detailAt < 10 * 60 * 1000)
            return;
        if (root.lat === 0 && root.lon === 0) {
            root.detailError = "No weatherLocation in secrets.json";
            return;
        }
        root.detailError = "";
        root.detailLoading = true;
        detailProc.running = true;
    }

    Process {
        id: detailProc

        command: ["curl", "-sL", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon + "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,cloud_cover,precipitation&hourly=temperature_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,wind_speed_10m,relative_humidity_2m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,sunrise,sunset,uv_index_max&timezone=auto&forecast_days=7"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.detailLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    const r = v => Math.round(v ?? 0);
                    const h = d.hourly;
                    const hourly = h.time.map((t, i) => ({
                                time: new Date(t),
                                temp: r(h.temperature_2m[i]),
                                feels: r(h.apparent_temperature[i]),
                                pop: r(h.precipitation_probability[i]),
                                precip: h.precipitation[i] ?? 0,
                                code: h.weather_code[i] ?? 0,
                                wind: r(h.wind_speed_10m[i]),
                                humidity: r(h.relative_humidity_2m[i]),
                                isDay: h.is_day[i] === 1
                            }));
                    const y = d.daily;
                    const daily = y.time.map((t, i) => ({
                                date: new Date(t),
                                code: y.weather_code[i] ?? 0,
                                tMax: r(y.temperature_2m_max[i]),
                                tMin: r(y.temperature_2m_min[i]),
                                precipSum: y.precipitation_sum[i] ?? 0,
                                popMax: r(y.precipitation_probability_max[i]),
                                windMax: r(y.wind_speed_10m_max[i]),
                                sunrise: new Date(y.sunrise[i]),
                                sunset: new Date(y.sunset[i]),
                                uvMax: Math.round((y.uv_index_max[i] ?? 0) * 10) / 10
                            }));
                    const c = d.current;
                    root.detail = {
                        current: {
                            temp: r(c.temperature_2m),
                            feels: r(c.apparent_temperature),
                            code: c.weather_code ?? 0,
                            isDay: c.is_day === 1,
                            humidity: r(c.relative_humidity_2m),
                            wind: r(c.wind_speed_10m),
                            windDir: c.wind_direction_10m ?? 0,
                            gusts: r(c.wind_gusts_10m),
                            pressure: r(c.pressure_msl),
                            clouds: r(c.cloud_cover),
                            precip: c.precipitation ?? 0
                        },
                        hourly: hourly,
                        daily: daily
                    };
                    root.detailAt = Date.now();
                    root.detailLoaded = true;
                    root.detailError = "";
                    if (!root.loaded)
                        root.applyDetailToCard();
                } catch (e) {
                    root.detailError = root.detailLoaded ? "" : "Could not load the forecast";
                }
            }
        }
    }

    // Hand-drawn flat SVGs in the tokyonight palette rather than
    // image://icon/, which does no real hicolor lookup (see ResolvedIcon.qml).
    readonly property string assetsDir: Quickshell.shellPath("assets/weather")

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
