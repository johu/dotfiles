pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Each entry: { summary, dtstart: { date, allDay, hhmm }, rrule: { freq, until } | null }
    property var events: []
    property bool loaded: false

    function eventsOn(date) {
        return root.events.filter(ev => matches(ev, date));
    }

    function hasEventsOn(date) {
        return root.events.some(ev => matches(ev, date));
    }

    function matches(ev, date) {
        const d = ev.dtstart.date;
        if (date < d)
            return false;
        if (!ev.rrule || !ev.rrule.freq)
            return sameDay(d, date);
        if (ev.rrule.until && date > ev.rrule.until)
            return false;
        if (ev.rrule.freq === "YEARLY")
            return date.getMonth() === d.getMonth() && date.getDate() === d.getDate();
        if (ev.rrule.freq === "WEEKLY")
            return date.getDay() === d.getDay();
        if (ev.rrule.freq === "DAILY")
            return true;
        return sameDay(d, date);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // ICS URLs live in an untracked local file (not in the dotfiles repo) so
    // the secret calendar URL never ends up in version control:
    // { "icalUrls": ["https://calendar.google.com/calendar/ical/.../private-.../basic.ics"] }
    readonly property string secretsPath: "/home/johu/.config/quickshell/secrets.json"

    property var pendingUrls: []
    property var fetchedRaw: []

    function reload() {
        root.fetchedRaw = [];
        configReader.running = true;
    }

    Component.onCompleted: reload()

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.reload()
    }

    Process {
        id: configReader
        command: ["cat", root.secretsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                let urls = [];
                try {
                    const cfg = JSON.parse(this.text);
                    urls = cfg.icalUrls || [];
                } catch (e) {
                    // No secrets.json yet, or it's invalid - calendar just shows no events.
                }
                root.pendingUrls = urls;
                root.fetchNext();
            }
        }
    }

    function fetchNext() {
        if (root.pendingUrls.length === 0) {
            root.parseAll();
            return;
        }
        curlProc.targetUrl = root.pendingUrls.shift();
        curlProc.running = true;
    }

    Process {
        id: curlProc
        property string targetUrl: ""
        command: ["curl", "-sL", "--max-time", "10", targetUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fetchedRaw.push(this.text);
                root.fetchNext();
            }
        }
    }

    function parseAll() {
        let parsed = [];
        for (const ics of root.fetchedRaw)
            parsed = parsed.concat(parseIcs(ics));
        root.events = parsed;
        root.loaded = true;
    }

    function parseIcs(text) {
        const unfolded = text.replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "");
        const lines = unfolded.split("\n");
        const results = [];
        let cur = null;
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") {
                cur = {};
            } else if (line === "END:VEVENT") {
                if (cur && cur.dtstart)
                    results.push(cur);
                cur = null;
            } else if (cur) {
                const idx = line.indexOf(":");
                if (idx < 0)
                    continue;
                const rawKey = line.substring(0, idx);
                const value = line.substring(idx + 1);
                const key = rawKey.split(";")[0];
                if (key === "SUMMARY")
                    cur.summary = unescapeIcs(value);
                else if (key === "DTSTART")
                    cur.dtstart = parseIcsDate(value, rawKey);
                else if (key === "RRULE")
                    cur.rrule = parseRRule(value);
            }
        }
        return results;
    }

    // Best-effort: ignores timezone offsets and RRULE features beyond
    // FREQ/UNTIL (no BYDAY/INTERVAL/COUNT/exceptions). Good enough for
    // yearly holiday feeds and simple weekly/daily recurring events.
    function parseIcsDate(value, rawKey) {
        const allDay = rawKey.indexOf("VALUE=DATE") >= 0 && rawKey.indexOf("VALUE=DATE-TIME") < 0;
        const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?/);
        if (!m)
            return { date: new Date(0), allDay: true, hhmm: null };
        const date = new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]));
        const hasTime = m[4] !== undefined;
        return { date, allDay: allDay || !hasTime, hhmm: hasTime ? (m[4] + ":" + m[5]) : null };
    }

    function parseRRule(value) {
        const parts = {};
        for (const kv of value.split(";")) {
            const eq = kv.indexOf("=");
            if (eq > 0)
                parts[kv.substring(0, eq)] = kv.substring(eq + 1);
        }
        return {
            freq: parts.FREQ || null,
            until: parts.UNTIL ? parseIcsDate(parts.UNTIL, "").date : null
        };
    }

    function unescapeIcs(s) {
        return s.replace(/\\n/g, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
    }
}
