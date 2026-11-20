pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ClockParse.js" as P

// State and logic of the Clock view: timers (incl. Pomodoro), alarms, stopwatch with saved
// sessions, ringing, world-clock zones and the date-pill state of the bar. A singleton, so
// everything keeps running while the launcher view is closed; saved to
// ~/.local/state/quickshell/clock.json and restored on start. Alarms only work while the shell
// runs (a missed one is reported). Do Not Disturb never silences a ring: notifications use
// critical urgency, which Notifications.qml lets through. Test hooks: `qs ipc call clock ...`.
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    // timer colours, chosen by the owner (2026-11-20); a new timer takes the first one not in use
    readonly property var palette: [Theme.blue, Theme.yellow, Theme.green, Theme.red, Theme.lavender]

    property double nowMs: Date.now()
    property bool loaded: false

    // ---- state ----
    // timer: { id, name, colorIdx, ms (length of the current phase), state: ready|running|paused|ringing,
    //          endMs (running), leftMs (paused / ready), repeat, pomo: null | { focus, brk, longBrk, rounds, round, phase: focus|break|long } }
    property var timers: []
    // alarm: { id, time "HH:MM", label, days [1..7] ([] = once), date "" | "YYYY-MM-DD", enabled, nextMs, snoozeMs }
    property var alarms: []
    property bool swRunning: false
    property double swStartMs: 0       // when the current run started
    property double swAccumMs: 0       // time of earlier runs of this session
    property double swSessionStartMs: 0
    property string swName: ""
    property var sessions: []          // { name, startMs, endMs, durationMs }, newest first
    property var ringing: []           // { key, kind: timer|alarm, id, name, sub, since }
    property var missed: []            // { text, atMs } of alarms that came due while the shell was off
    property var zones: ["Europe/Lisbon", "America/New_York", "America/Sao_Paulo", "Asia/Tokyo", "Australia/Sydney", "UTC"]
    property int nextId: 1

    // ---- test / quiet hooks ----
    property bool soundMuted: false
    property bool notifyMuted: false

    signal ringStarted
    signal changed
    // the bar asks for the Clock view (Launcher.qml listens)
    signal openRequested

    function requestOpen() {
        root.openRequested();
    }

    // ================================================================ persistence
    function snapshot() {
        return JSON.stringify({ v: 1, timers: root.timers, alarms: root.alarms, swRunning: root.swRunning, swStartMs: root.swStartMs, swAccumMs: root.swAccumMs, swSessionStartMs: root.swSessionStartMs, swName: root.swName, sessions: root.sessions, ringing: root.ringing, zones: root.zones, nextId: root.nextId });
    }

    function restore(blob) {
        if (blob !== "") {
            try {
                const o = JSON.parse(blob);
                root.timers = o.timers ?? [];
                root.alarms = o.alarms ?? [];
                root.swRunning = o.swRunning === true;
                root.swStartMs = o.swStartMs ?? 0;
                root.swAccumMs = o.swAccumMs ?? 0;
                root.swSessionStartMs = o.swSessionStartMs ?? 0;
                root.swName = o.swName ?? "";
                root.sessions = o.sessions ?? [];
                root.ringing = o.ringing ?? [];
                root.zones = o.zones ?? root.zones;
                root.nextId = o.nextId ?? 1;
            } catch (e) {
                console.warn("clock.json unreadable, starting empty");
            }
        }
        root.loaded = true;
        root.nowMs = Date.now();
        // a ring that was active when the shell stopped rings again
        if (root.ringing.length > 0)
            root.beginRing();
        root.tick();
        root.probeZones();
    }

    function save() {
        saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 400
        onTriggered: if (root.loaded) {
            adapter.blob = root.snapshot();
            chmodTimer.restart();
        }
    }

    // the file holds timer and alarm names: owner only, like the other state files
    Timer {
        id: chmodTimer

        interval: 800
        onTriggered: chmodProc.running = true
    }

    Process {
        id: chmodProc

        command: ["chmod", "600", root.stateDir + "/clock.json"]
    }

    FileView {
        id: file

        path: root.stateDir + "/clock.json"
        printErrors: false
        onLoaded: root.restore(adapter.blob)
        onLoadFailed: root.restore("")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property string blob: ""
        }
    }

    // sound file from launcher-config.json (`clockSound`), default: a freedesktop placeholder
    FileView {
        id: cfgFile

        path: Quickshell.shellPath("launcher-config.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: cfg

            property string clockSound: ""
            // separate sounds: an alarm is a long gentle piece, a timer a plain repeated ring
            property string clockAlarmSound: ""
            property string clockTimerSound: ""
            // 0..1, relative to the system volume (pw-play --volume); alarms should not be painful
            property real clockVolume: 0.6
        }
    }

    readonly property real soundVolume: Math.max(0.05, Math.min(1, cfg.clockVolume))
    readonly property string fallbackSound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    // bundled defaults (own synthesized marimba, see assets/sounds/README.md)
    readonly property string alarmSoundFile: cfg.clockAlarmSound !== "" ? cfg.clockAlarmSound : (cfg.clockSound !== "" ? cfg.clockSound : Quickshell.shellPath("assets/sounds/alarm.ogg"))
    readonly property string timerSoundFile: cfg.clockTimerSound !== "" ? cfg.clockTimerSound : (cfg.clockSound !== "" ? cfg.clockSound : Quickshell.shellPath("assets/sounds/timer.ogg"))
    // an alarm wins when both ring
    readonly property string soundFile: root.ringing.some(r => r.kind === "alarm") ? root.alarmSoundFile : root.timerSoundFile
    // set when the chosen file could not be played (missing, bad format): the fallback plays instead
    property bool soundFailed: false

    // ================================================================ tick
    Timer {
        interval: 1000
        running: root.loaded
        repeat: true
        onTriggered: root.tick()
    }

    function tick() {
        const now = Date.now();
        root.nowMs = now;
        let timers = root.timers, alarms = root.alarms, touched = false;
        for (const t of timers) {
            if (t.state === "running" && t.endMs <= now) {
                root.ringTimer(t.id);
                touched = true;
            }
        }
        const due = [];
        for (const a of root.alarms) {
            // a snoozed alarm rings again even when it switched itself off (one-off alarms do)
            if (a.snoozeMs > 0 && now >= a.snoozeMs)
                due.push({ a: a, snooze: true });
            else if (a.enabled && a.nextMs > 0 && now >= a.nextMs)
                due.push({ a: a, snooze: false });
        }
        for (const d of due) {
            const a = d.a;
            const late = now - (d.snooze ? a.snoozeMs : a.nextMs);
            const once = !a.days || a.days.length === 0;
            root.patchAlarm(a.id, d.snooze ? { snoozeMs: 0 } : (once ? { enabled: false, nextMs: -1 } : { nextMs: P.nextAlarm(a, now) }));
            if (late > 120000)
                root.reportMissed(a);
            else
                root.ring("alarm", a.id, a.label !== "" ? a.label : "Alarm", a.time + (P.daysText(a.days) !== "" ? " · " + P.daysText(a.days) : ""));
            touched = true;
        }
        // an alarm that nobody answered stops after five minutes and is reported as missed;
        // a timer rings until it is dismissed
        for (const r of root.ringing) {
            if (r.kind === "alarm" && now - r.since > 300000)
                root.missRing(r.key);
        }
        if (touched)
            root.save();
    }

    // ================================================================ helpers
    function newId() {
        const i = root.nextId;
        root.nextId = i + 1;
        return i;
    }

    function patchTimer(id, patch) {
        root.timers = root.timers.map(t => t.id === id ? Object.assign({}, t, patch) : t);
        root.changed();
    }

    function patchAlarm(id, patch) {
        root.alarms = root.alarms.map(a => a.id === id ? Object.assign({}, a, patch) : a);
        root.changed();
    }

    function timerById(id) {
        return root.timers.find(t => t.id === id) ?? null;
    }

    function timerColor(t) {
        return root.palette[(t?.colorIdx ?? 0) % root.palette.length];
    }

    function freeColorIdx() {
        const used = root.timers.map(t => t.colorIdx);
        for (let i = 0; i < root.palette.length; i++)
            if (used.indexOf(i) < 0)
                return i;
        return root.timers.length % root.palette.length;
    }

    function leftMs(t) {
        if (t.state === "running")
            return Math.max(0, t.endMs - root.nowMs);
        return t.leftMs;
    }

    // ================================================================ timers
    // "5m tea", "25/5", "1h30": returns "" or an error text
    function addTimer(text, autostart) {
        const p = P.parseTimer(text);
        if (!p.ok)
            return "Not a duration: try 5m, 90s, 1h30, 25 or 25/5";
        const now = Date.now();
        const t = { id: root.newId(), name: p.name, colorIdx: root.freeColorIdx(), ms: p.ms, state: "ready", endMs: 0, leftMs: p.ms, repeat: false, pomo: p.pomo ? { focus: p.pomo.focus, brk: p.pomo.brk, longBrk: p.pomo.longBrk, rounds: p.pomo.rounds, round: 1, phase: "focus" } : null };
        if (autostart !== false) {
            t.state = "running";
            t.endMs = now + p.ms;
        }
        root.timers = root.timers.concat([t]);
        root.changed();
        root.save();
        return "";
    }

    function editTimer(id, text) {
        const t = root.timerById(id);
        const p = P.parseTimer(text);
        if (!t || !p.ok)
            return "Not a duration";
        if (t.state === "running" || t.state === "ringing")
            return "Pause the timer first";
        root.patchTimer(id, { name: p.name, ms: p.ms, leftMs: p.ms, pomo: p.pomo ? { focus: p.pomo.focus, brk: p.pomo.brk, longBrk: p.pomo.longBrk, rounds: p.pomo.rounds, round: 1, phase: "focus" } : null });
        root.save();
        return "";
    }

    function toggleTimer(id) {
        const t = root.timerById(id);
        if (!t)
            return;
        const now = Date.now();
        if (t.state === "running")
            root.patchTimer(id, { state: "paused", leftMs: Math.max(0, t.endMs - now) });
        else if (t.state === "paused" || t.state === "ready")
            root.patchTimer(id, { state: "running", endMs: now + (t.leftMs > 0 ? t.leftMs : t.ms) });
        else if (t.state === "ringing")
            root.dismiss("t" + id);
        root.save();
    }

    function addMinute(id) {
        const t = root.timerById(id);
        if (!t)
            return;
        const now = Date.now();
        if (t.state === "ringing") {
            root.removeRing("t" + id);
            root.patchTimer(id, { state: "running", endMs: now + 60000 });
        } else if (t.state === "running") {
            root.patchTimer(id, { endMs: t.endMs + 60000 });
        } else {
            root.patchTimer(id, { leftMs: t.leftMs + 60000, ms: t.state === "ready" ? t.ms + 60000 : t.ms });
        }
        root.save();
    }

    function resetTimer(id) {
        const t = root.timerById(id);
        if (!t)
            return;
        root.removeRing("t" + id);
        root.patchTimer(id, root.phaseReset(t));
        root.save();
    }

    function phaseReset(t) {
        if (!t.pomo)
            return { state: "ready", leftMs: t.ms, endMs: 0 };
        const p = Object.assign({}, t.pomo, { round: 1, phase: "focus" });
        return { state: "ready", ms: p.focus * 60000, leftMs: p.focus * 60000, endMs: 0, pomo: p };
    }

    function removeTimer(id) {
        root.removeRing("t" + id);
        root.timers = root.timers.filter(t => t.id !== id);
        root.changed();
        root.save();
    }

    function setRepeat(id, on) {
        root.patchTimer(id, { repeat: on });
        root.save();
    }

    // Pomodoro: the phase after the current one. Returns a patch (not started) or null when the cycle is complete.
    function nextPhase(t) {
        const p = Object.assign({}, t.pomo);
        if (p.phase === "focus") {
            if (p.round >= p.rounds) {
                p.phase = "long";
                return { pomo: p, ms: p.longBrk * 60000 };
            }
            p.phase = "break";
            return { pomo: p, ms: p.brk * 60000 };
        }
        if (p.phase === "long")
            return null;
        p.round += 1;
        p.phase = "focus";
        return { pomo: p, ms: p.focus * 60000 };
    }

    function skipPhase(id) {
        const t = root.timerById(id);
        if (!t || !t.pomo)
            return;
        root.removeRing("t" + id);
        const n = root.nextPhase(t);
        if (n === null)
            root.patchTimer(id, root.phaseReset(t));
        else
            root.patchTimer(id, { pomo: n.pomo, ms: n.ms, state: "running", endMs: Date.now() + n.ms, leftMs: n.ms });
        root.save();
    }

    function ringTimer(id) {
        const t = root.timerById(id);
        if (!t)
            return;
        root.patchTimer(id, { state: "ringing", leftMs: 0 });
        let sub = "Timer finished · " + P.durationText(t.ms);
        if (t.pomo)
            sub = t.pomo.phase === "focus" ? "Focus round " + t.pomo.round + " of " + t.pomo.rounds + " done: break time" : (t.pomo.phase === "long" ? "Long break over: cycle complete" : "Break over: back to focus");
        root.ring("timer", id, t.name !== "" ? t.name : "Timer", sub);
    }

    // what happens after the ring of a timer was answered with "dismiss"
    function afterTimerRing(id) {
        const t = root.timerById(id);
        if (!t || t.state !== "ringing")
            return;
        const now = Date.now();
        if (t.pomo) {
            const n = root.nextPhase(t);
            if (n === null)
                root.patchTimer(id, root.phaseReset(t));
            else
                root.patchTimer(id, { pomo: n.pomo, ms: n.ms, state: "running", endMs: now + n.ms, leftMs: n.ms });
        } else if (t.repeat) {
            root.patchTimer(id, { state: "running", endMs: now + t.ms, leftMs: t.ms });
        } else {
            root.patchTimer(id, { state: "ready", leftMs: t.ms, endMs: 0 });
        }
    }

    // ================================================================ alarms
    // timeText "7:30", daysText "mon tue" | "weekdays" | "daily" | "" (once). Returns "" or an error text.
    function addAlarm(timeText, daysText, label, date) {
        const time = P.parseClock(timeText);
        if (time === "")
            return "Not a time: try 7:30 or 0730";
        const days = P.parseDays(daysText);
        if (days === null)
            return "Not weekdays: try mon tue, weekdays, weekend or daily";
        const a = { id: root.newId(), time: time, label: label ?? "", days: days, date: date ?? "", enabled: true, nextMs: -1, snoozeMs: 0 };
        a.nextMs = P.nextAlarm(a, Date.now());
        if (a.nextMs < 0)
            return "That date has already passed";
        root.alarms = root.alarms.concat([a]);
        root.changed();
        root.save();
        return "";
    }

    function editAlarm(id, timeText, daysText, label) {
        const time = P.parseClock(timeText);
        const days = P.parseDays(daysText);
        if (time === "" || days === null)
            return "Not a valid time or weekdays";
        const a = Object.assign({}, root.alarms.find(x => x.id === id), { time: time, days: days, label: label ?? "", snoozeMs: 0 });
        a.nextMs = a.enabled ? P.nextAlarm(a, Date.now()) : -1;
        root.patchAlarm(id, { time: a.time, days: a.days, label: a.label, nextMs: a.nextMs, snoozeMs: 0 });
        root.save();
        return "";
    }

    function toggleAlarm(id) {
        const a = root.alarms.find(x => x.id === id);
        if (!a)
            return;
        const on = !a.enabled;
        root.patchAlarm(id, { enabled: on, nextMs: on ? P.nextAlarm(a, Date.now()) : -1, snoozeMs: 0 });
        root.save();
    }

    function removeAlarm(id) {
        root.removeRing("a" + id);
        root.alarms = root.alarms.filter(a => a.id !== id);
        root.changed();
        root.save();
    }

    function snoozeRing(key) {
        const r = root.ringing.find(x => x.key === key);
        if (!r || r.kind !== "alarm")
            return;
        root.removeRing(key);
        root.patchAlarm(r.id, { snoozeMs: Date.now() + 5 * 60000 });
        root.save();
    }

    function missRing(key) {
        const r = root.ringing.find(x => x.key === key);
        if (!r)
            return;
        const a = root.alarms.find(x => x.id === r.id);
        root.removeRing(key);
        root.reportMissed(a ? a : { time: r.sub.split(" ")[0], label: r.name === "Alarm" ? "" : r.name });
        root.save();
    }

    function reportMissed(a) {
        const text = a.time + (a.label !== "" ? "  " + a.label : "");
        root.missed = [{ text: text, atMs: Date.now() }].concat(root.missed).slice(0, 10);
        if (!root.notifyMuted)
            Quickshell.execDetached(["notify-send", "-a", "Clock", "-i", "alarm-clock", "Missed alarm", text]);
    }

    // next alarm that will fire: { ms, alarm } or null
    readonly property var nextAlarmInfo: {
        let best = null;
        for (const a of root.alarms) {
            if (!a.enabled && !(a.snoozeMs > 0))
                continue;
            const ms = a.snoozeMs > 0 ? a.snoozeMs : a.nextMs;
            if (ms > 0 && (best === null || ms < best.ms))
                best = { ms: ms, alarm: a };
        }
        return best;
    }

    // ================================================================ ringing
    function ring(kind, id, name, sub) {
        const key = (kind === "timer" ? "t" : "a") + id;
        if (root.ringing.some(r => r.key === key))
            return;
        const first = root.ringing.length === 0;
        root.ringing = root.ringing.concat([{ key: key, kind: kind, id: id, name: name, sub: sub, since: Date.now() }]);
        if (!root.notifyMuted)
            notifComp.createObject(root, { key: key, args: ["-a", "Clock", "-u", "critical", "-i", kind === "timer" ? "appointment-soon" : "alarm-clock", name, sub] });
        if (first)
            root.beginRing();
        root.ringStarted();
        root.changed();
        root.save();
    }

    function beginRing() {
        root.soundFailed = false;
        if (!root.soundMuted && !sound.running)
            sound.running = true;
    }

    // The notification of a ring stays until dismissed (critical), so remember its id (notify-send -p)
    // and close it when the ring is answered on the screen.
    property var notifIds: ({})

    Component {
        id: notifComp

        Process {
            property string key: ""
            property var args: []

            command: ["notify-send", "-p"].concat(args)
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const id = parseInt(this.text.trim());
                    if (isNaN(id))
                        return;
                    if (root.ringing.some(r => r.key === key))
                        root.notifIds[key] = id;
                    else
                        root.closeNotification(id);
                }
            }
            onExited: destroy()
        }
    }

    function closeNotification(id) {
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification", String(id)]);
    }

    function removeRing(key) {
        if (!root.ringing.some(r => r.key === key))
            return;
        if (root.notifIds[key] !== undefined) {
            root.closeNotification(root.notifIds[key]);
            delete root.notifIds[key];
        }
        root.ringing = root.ringing.filter(r => r.key !== key);
        if (root.ringing.length === 0) {
            restartSound.stop();
            sound.running = false;
            root.soundFailed = false;
        }
        root.changed();
    }

    function dismiss(key) {
        const r = root.ringing.find(x => x.key === key);
        if (!r)
            return;
        root.removeRing(key);
        if (r.kind === "timer")
            root.afterTimerRing(r.id);
        root.save();
    }

    function dismissAll() {
        for (const r of root.ringing.slice())
            root.dismiss(r.key);
    }

    // loops the sound until the last ring is answered
    Process {
        id: sound

        property double startedAt: 0

        command: ["pw-play", "--volume", String(root.soundVolume), root.soundFailed ? root.fallbackSound : root.soundFile]
        onRunningChanged: if (running)
            startedAt = Date.now()
        onExited: code => {
            // failing at once means the file is unusable: switch to the bundled sound
            // (only while a ring is still active: dismissing a ring kills pw-play on purpose)
            if (root.ringing.length > 0 && code !== 0 && Date.now() - startedAt < 1500 && !root.soundFailed)
                root.soundFailed = true;
            if (root.ringing.length > 0 && !root.soundMuted)
                restartSound.restart();
        }
    }

    Timer {
        id: restartSound

        interval: 500
        onTriggered: if (root.ringing.length > 0 && !root.soundMuted)
            sound.running = true
    }

    // ================================================================ stopwatch
    function swElapsed() {
        return root.swElapsedAt(root.nowMs);
    }

    function swElapsedAt(now) {
        return root.swAccumMs + (root.swRunning ? now - root.swStartMs : 0);
    }

    function swToggle() {
        const now = Date.now();
        if (root.swRunning) {
            root.swAccumMs = root.swAccumMs + (now - root.swStartMs);
            root.swRunning = false;
        } else {
            if (root.swAccumMs === 0)
                root.swSessionStartMs = now;
            root.swStartMs = now;
            root.swRunning = true;
        }
        root.nowMs = now;
        root.changed();
        root.save();
    }

    // saves the session (when it ran at least 3 s) and clears the stopwatch
    function swFinish() {
        const now = Date.now();
        const total = root.swElapsed();
        if (total >= 3000)
            root.sessions = [{ name: root.swName, startMs: root.swSessionStartMs, endMs: now, durationMs: total }].concat(root.sessions).slice(0, 60);
        root.swRunning = false;
        root.swAccumMs = 0;
        root.swStartMs = 0;
        root.swSessionStartMs = 0;
        root.changed();
        root.save();
    }

    function swSetName(n) {
        root.swName = n;
        root.save();
    }

    function removeSession(i) {
        root.sessions = root.sessions.filter((s, j) => j !== i);
        root.changed();
        root.save();
    }

    // ================================================================ world clock
    property string localZone: ""
    property var offsets: ({})       // zone -> { off: minutes, abbr }
    property var allZones: []

    function zoneLabel(z) {
        const map = { "America/Sao_Paulo": "São Paulo", "UTC": "UTC" };
        if (map[z])
            return map[z];
        return z.split("/").pop().replace(/_/g, " ");
    }

    // local zone first, the others sorted by offset; a zone equal to the local one is dropped
    readonly property var zoneList: {
        const loc = root.localZone !== "" ? root.localZone : "Europe/Berlin";
        const rest = root.zones.filter((z, i) => z !== loc && root.zones.indexOf(z) === i);
        rest.sort((a, b) => ((root.offsets[a]?.off ?? 0) - (root.offsets[b]?.off ?? 0)) || a.localeCompare(b));
        return [loc].concat(rest);
    }

    // { hh, mm, ss, clock "20:24", dateText "Wed 18.11.", offHours (vs the local zone), dayDiff (-1/0/1), abbr,
    //   strip: sun phase of each of the 24 local hours (0 night, 1 sunrise / sunset glow, 2 day) }
    function zoneInfo(z) {
        const o = root.offsets[z];
        const loc = root.offsets[root.zoneList[0]];
        const offMin = o ? o.off : 0, locMin = loc ? loc.off : 0;
        const d = new Date(root.nowMs + offMin * 60000), l = new Date(root.nowMs + locMin * 60000);
        const day = x => Math.floor(x.getTime() / 86400000);
        const pos = P.zonePos(z, offMin);
        return { strip: P.dayStrip(root.nowMs, offMin, pos[0], pos[1]), hh: d.getUTCHours(), mm: d.getUTCMinutes(), ss: d.getUTCSeconds(), clock: P.pad(d.getUTCHours()) + ":" + P.pad(d.getUTCMinutes()), dateText: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getUTCDay()] + " " + P.pad(d.getUTCDate()) + "." + P.pad(d.getUTCMonth() + 1) + ".", offHours: (offMin - locMin) / 60, dayDiff: day(d) - day(l), abbr: o ? o.abbr : "", known: !!o };
    }

    function addZone(name) {
        const z = name.trim();
        if (root.allZones.length > 0 && root.allZones.indexOf(z) < 0)
            return "Unknown time zone";
        if (root.zones.indexOf(z) >= 0 || z === root.localZone)
            return "Already in the list";
        root.zones = root.zones.concat([z]);
        root.probeZones();
        root.save();
        return "";
    }

    function removeZone(z) {
        root.zones = root.zones.filter(x => x !== z);
        root.changed();
        root.save();
    }

    // QML has no Intl: ask `date` for each zone's offset (on start, when zones change, every 5 minutes for DST)
    function probeZones() {
        if (probe.running)
            return;
        const all = [root.localZone !== "" ? root.localZone : "Europe/Berlin"].concat(root.zones);
        probe.command = ["sh", "-c", 'for z in "$@"; do printf "%s\\t%s\\t%s\\n" "$z" "$(TZ="$z" date +%z)" "$(TZ="$z" date +%Z)"; done', "sh"].concat(all);
        probe.running = true;
    }

    Process {
        id: localProc

        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const z = this.text.trim();
                if (z !== "" && z !== root.localZone) {
                    root.localZone = z;
                    root.probeZones();
                }
            }
        }
    }

    Process {
        id: probe

        property var found: ({})

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const f = line.split("\t");
                if (f.length < 3)
                    return;
                const sign = f[1][0] === "-" ? -1 : 1;
                const off = sign * (parseInt(f[1].slice(1, 3)) * 60 + parseInt(f[1].slice(3, 5)));
                probe.found[f[0]] = { off: off, abbr: f[2] };
            }
        }
        onRunningChanged: if (!running) {
            root.offsets = Object.assign({}, root.offsets, probe.found);
            probe.found = ({});
        }
    }

    Timer {
        interval: 300000
        running: root.loaded
        repeat: true
        onTriggered: {
            localProc.running = true;
            root.probeZones();
        }
    }

    Process {
        id: zoneListProc

        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: root.allZones = this.text.split("\n").filter(l => l !== "")
        }
    }

    function loadAllZones() {
        if (root.allZones.length === 0 && !zoneListProc.running)
            zoneListProc.running = true;
    }

    // ================================================================ bar pill
    // { mode: none|timer|alarm|ringing, text, color, lastMinute }
    readonly property var pill: {
        if (root.ringing.length > 0) {
            const r = root.ringing[0];
            return { mode: "ringing", text: r.name, color: Theme.red, lastMinute: false };
        }
        let best = null;
        for (const t of root.timers) {
            if (t.state !== "running")
                continue;
            const left = Math.max(0, t.endMs - root.nowMs);
            if (best === null || left < best.left)
                best = { left: left, t: t };
        }
        const na = root.nextAlarmInfo;
        const alarmLeft = na ? na.ms - root.nowMs : -1;
        if (best !== null && (alarmLeft < 0 || alarmLeft > 12 * 3600000 || best.left <= alarmLeft)) {
            const last = best.left < 60000;
            return { mode: "timer", text: P.countdown(best.left), color: last ? Theme.yellow : root.timerColor(best.t), lastMinute: last };
        }
        if (na && alarmLeft <= 12 * 3600000)
            return { mode: "alarm", text: na.alarm.time, color: Theme.mauve, lastMinute: false };
        return { mode: "none", text: "", color: Theme.pink, lastMinute: false };
    }

    // ================================================================ IPC (tests and shortcuts)
    IpcHandler {
        target: "clock"

        function add(text: string): string {
            return root.addTimer(text, true) || "ok";
        }
        function alarm(time: string, days: string, label: string): string {
            return root.addAlarm(time, days, label, "") || "ok";
        }
        function ring(name: string): void {
            root.ring("timer", 0, name, "Test ring");
        }
        function dismiss(): void {
            root.dismissAll();
        }
        function timer(op: string, id: int): string {
            switch (op) {
            case "toggle":
                root.toggleTimer(id);
                break;
            case "minute":
                root.addMinute(id);
                break;
            case "reset":
                root.resetTimer(id);
                break;
            case "skip":
                root.skipPhase(id);
                break;
            case "remove":
                root.removeTimer(id);
                break;
            case "repeat":
                root.setRepeat(id, true);
                break;
            case "dismiss":
                root.dismiss("t" + id);
                break;
            default:
                return "unknown op";
            }
            return "ok";
        }
        function snooze(): string {
            const r = root.ringing.find(x => x.kind === "alarm");
            if (!r)
                return "no ringing alarm";
            root.snoozeRing(r.key);
            return "ok";
        }
        function alarmop(op: string, id: int): string {
            if (op === "toggle")
                root.toggleAlarm(id);
            else if (op === "remove")
                root.removeAlarm(id);
            else if (op === "snooze3s")
                root.patchAlarm(id, { snoozeMs: Date.now() + 3000 });
            else
                return "unknown op";
            return "ok";
        }
        function sw(op: string): string {
            if (op === "toggle")
                root.swToggle();
            else if (op === "finish")
                root.swFinish();
            else
                return "unknown op";
            return "ok";
        }
        function zone(op: string, name: string): string {
            if (op === "add")
                return root.addZone(name) || "ok";
            if (op === "remove") {
                root.removeZone(name);
                return "ok";
            }
            return "unknown op";
        }
        function quiet(on: bool): void {
            root.soundMuted = on;
            root.notifyMuted = on;
        }
        function notify(on: bool): void {
            root.notifyMuted = !on;
        }
        function clear(): void {
            root.dismissAll();
            root.timers = [];
            root.alarms = [];
            root.sessions = [];
            root.swRunning = false;
            root.swAccumMs = 0;
            root.missed = [];
            root.changed();
            root.save();
        }
        function state(): string {
            return JSON.stringify({ timers: root.timers.map(t => ({ id: t.id, name: t.name, state: t.state, left: P.countdown(root.leftMs(t)), pomo: t.pomo ? t.pomo.phase + " " + t.pomo.round + "/" + t.pomo.rounds : "" })), alarms: root.alarms.map(a => ({ id: a.id, time: a.time, days: a.days, enabled: a.enabled, next: a.nextMs, snooze: a.snoozeMs })), ringing: root.ringing.map(r => r.key + ":" + r.name), pill: root.pill, sw: { running: root.swRunning, elapsed: P.stopwatch(root.swElapsed()) }, sessions: root.sessions.length, missed: root.missed.length, local: root.localZone, zones: root.zoneList, offsets: root.offsets });
        }
    }
}
