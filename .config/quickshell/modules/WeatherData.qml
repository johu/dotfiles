pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather: the single owner of the open-meteo data (see
// docs/plans/shared-data-sources.md). One request fills both the detailed
// shape (`detail`, launcher view) and the compact card fields, so the two
// can never disagree. Views are presentational and bind to this singleton.
Singleton {
    id: root

    // Location is read from the untracked secrets.json (not a secret, but keeps
    // user config in one place):
    // { "weatherLocation": { "lat": 53.0793, "lon": 8.8017 } }
    readonly property string secretsPath: Quickshell.shellPath("secrets.json")

    property real lat: 0
    property real lon: 0
    property bool hasLocation: false
    property string locationError: ""

    // ---- Shared data vocabulary ----
    readonly property bool loaded: fetcher.loaded
    readonly property bool loading: fetcher.loading
    readonly property string error: root.locationError !== "" ? root.locationError : fetcher.error
    readonly property real updatedAt: fetcher.updatedAt
    function refresh(force) {
        fetcher.refresh(force);
    }

    // Detailed forecast: { current, hourly[168], daily[7] }.
    property var detail: ({ current: null, hourly: [], daily: [] })

    // Card fields, derived from `detail` in one pass.
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
                    // No secrets.json yet, or it's invalid.
                }
                if (loc && typeof loc.lat === "number" && typeof loc.lon === "number") {
                    root.lat = loc.lat;
                    root.lon = loc.lon;
                    root.locationError = "";
                    root.hasLocation = true;
                } else {
                    root.hasLocation = false;
                    root.locationError = "No weatherLocation in secrets.json";
                }
            }
        }
    }

    function buildDetail_(d) {
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
        if (hourly.length === 0 || daily.length === 0 || !c)
            throw new Error("empty forecast");
        return {
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
    }

    // Fill the card fields from the detailed forecast.
    function applyDetail_(d) {
        root.detail = d;
        root.currentTemp = d.current.temp;
        root.currentCode = d.current.code;
        root.currentIsDay = d.current.isDay;
        root.currentHumidity = d.current.humidity;
        root.currentWindSpeed = d.current.wind;

        // Hourly data is on the hour but "now" has minutes; round (not
        // floor) so the trend starts at the closest reading.
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
    }

    Fetcher {
        id: fetcher
        active: root.hasLocation
        interval: 15 * 60 * 1000
        staleAfter: 10 * 60 * 1000
        failureText: "Could not load the forecast"
        command: root.hasLocation ? ["curl", "-sLf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon + "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl,cloud_cover,precipitation&hourly=temperature_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,wind_speed_10m,relative_humidity_2m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,sunrise,sunset,uv_index_max&timezone=auto&forecast_days=7"] : []
        parse: text => root.buildDetail_(JSON.parse(text))
        onFetched: d => root.applyDetail_(d)
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
