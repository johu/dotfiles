pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Probes once at shell start which external programs the features need and
// publishes the result (properties + ~/.local/state/quickshell/deps.json).
// Features ask `has(id)` / `bin(id)` instead of failing silently, see
// docs/ideas/dependency-check.md.
QtObject {
    id: root

    // id: key used by callers. names: candidate commands, first one on PATH
    // wins ("either tool" groups). min: minimum version,
    // checked against the first line of `<cmd> --version`. required: the
    // feature does not work at all without it; optional ones only degrade.
    // pkg: Gentoo atom to install.
    readonly property var manifest: [
        { id: "fd", names: ["fd"], feature: "Launcher file search", required: true,
          pkg: "sys-apps/fd" },
        { id: "fzf", names: ["fzf"], min: "0.34", feature: "Launcher file search", required: true,
          pkg: "app-shells/fzf" },
        { id: "bat", names: ["bat"], feature: "File preview syntax highlighting", required: false,
          pkg: "sys-apps/bat" },
        { id: "eza", names: ["eza"], feature: "File preview directory listing", required: false,
          pkg: "sys-apps/eza" },
        { id: "file", names: ["file"], feature: "File preview", required: false,
          pkg: "sys-apps/file" },
        { id: "yazi", names: ["yazi"], feature: "Open in yazi", required: false,
          pkg: "app-misc/yazi" },
        { id: "ffprobe", names: ["ffprobe"], feature: "Media file preview", required: false,
          pkg: "media-video/ffmpeg" },
        { id: "pdftoppm", names: ["pdftoppm"], feature: "PDF file preview", required: false,
          pkg: "app-text/poppler" },
        { id: "bsdtar", names: ["bsdtar"], feature: "Archive file preview", required: false,
          pkg: "app-arch/libarchive" },
        { id: "unzip", names: ["unzip"], feature: "Archive file preview", required: false,
          pkg: "app-arch/unzip" },
        { id: "7z", names: ["7z", "7zz"], feature: "Archive file preview", required: false,
          pkg: "app-arch/7zip" },

        { id: "grim", names: ["grim"], feature: "Screenshots", required: true,
          pkg: "gui-apps/grim" },
        { id: "wl-copy", names: ["wl-copy"], feature: "Clipboard copy", required: true,
          pkg: "gui-apps/wl-clipboard" },
        { id: "gpu-screen-recorder", names: ["gpu-screen-recorder"], feature: "Screen recording", required: true,
          pkg: "media-video/gpu-screen-recorder" },
        { id: "magick", names: ["magick"], feature: "Capture crop, OCR and QR", required: true,
          pkg: "media-gfx/imagemagick" },
        { id: "tesseract", names: ["tesseract"], feature: "Text capture (OCR)", required: false,
          pkg: "app-text/tesseract" },
        { id: "zbarimg", names: ["zbarimg"], feature: "QR capture", required: false,
          pkg: "media-gfx/zbar" },
        { id: "nm-connection-editor", names: ["nm-connection-editor"], feature: "Network view: edit connections and VPN profiles", required: false,
          pkg: "gnome-extra/nm-applet" },
        { id: "qrencode", names: ["qrencode"], feature: "Wi-Fi QR sharing (Network view)", required: false,
          pkg: "media-gfx/qrencode" },

        { id: "hyprlock", names: ["hyprlock"], feature: "Lock screen", required: true,
          pkg: "gui-apps/hyprlock" },
        { id: "hyprshutdown", names: ["hyprshutdown"], feature: "Session shutdown", required: false,
          pkg: "gui-apps/hyprshutdown" },
        { id: "wlogout", names: ["wlogout"], feature: "Logout menu", required: false,
          pkg: "gui-apps/wlogout" },
        { id: "hyprsunset", names: ["hyprsunset"], feature: "Night light", required: false,
          pkg: "gui-apps/hyprsunset" },

        { id: "cliphist", names: ["cliphist"], feature: "Clipboard history", required: true,
          pkg: "app-misc/cliphist" },
        { id: "brightness", names: ["brightnessctl", "ddcutil"], feature: "Brightness control", required: false,
          pkg: "app-misc/brightnessctl or app-misc/ddcutil" },
        { id: "notify-send", names: ["notify-send"], feature: "Notifications from scripts", required: false,
          pkg: "x11-libs/libnotify" },
        { id: "curl", names: ["curl"], feature: "Weather and calendar", required: false,
          pkg: "net-misc/curl" },
        { id: "nmcli", names: ["nmcli"], feature: "Network card and launcher Network view", required: false,
          pkg: "net-misc/networkmanager" },
        { id: "cava", names: ["cava"], feature: "Audio visualizer", required: false,
          pkg: "media-sound/cava" },
        { id: "xdg-open", names: ["xdg-open"], feature: "Opening files and links", required: true,
          pkg: "x11-misc/xdg-utils" },
        { id: "pactl", names: ["pactl"], feature: "Launcher audio view", required: false,
          pkg: "media-libs/libpulse" },
        { id: "eix", names: ["eix"], feature: "Portage update count", required: false,
          pkg: "app-portage/eix" },
        { id: "systemctl", names: ["systemctl"], feature: "Service checks, power actions", required: true,
          pkg: "sys-apps/systemd" },
        { id: "python3", names: ["python3"], feature: "System monitor, lyrics, agent usage", required: false,
          pkg: "dev-lang/python" }
    ]

    // Units that must be running (needs systemctl). scope: user or system.
    readonly property var services: [
        { id: "dbus", unit: "dbus.service", scope: "user", feature: "Session bus", required: true,
          pkg: "sys-apps/dbus" },
        { id: "pipewire", unit: "pipewire.service", scope: "user", feature: "Audio", required: true,
          pkg: "media-video/pipewire" },
        { id: "wireplumber", unit: "wireplumber.service", scope: "user", feature: "Audio routing", required: true,
          pkg: "media-video/wireplumber" },
        { id: "pipewire-pulse", unit: "pipewire-pulse.service", scope: "user", feature: "PulseAudio compatibility (pactl)", required: false,
          pkg: "media-video/pipewire" },
        { id: "hyprsunset-service", unit: "hyprsunset.service", scope: "user", feature: "Night light", required: false,
          pkg: "gui-apps/hyprsunset" },
        { id: "hypridle", unit: "hypridle.service", scope: "user", feature: "Idle handling (Keep Awake has no effect without it)", required: false,
          pkg: "gui-apps/hypridle" },
        { id: "hyprpaper", unit: "hyprpaper.service", scope: "user", feature: "Wallpaper", required: false,
          pkg: "gui-apps/hyprpaper" },
        { id: "hyprpolkitagent", unit: "hyprpolkitagent.service", scope: "user", feature: "Polkit authentication prompts", required: false,
          pkg: "sys-auth/hyprpolkitagent" },
        { id: "NetworkManager", unit: "NetworkManager.service", scope: "system", feature: "Network card", required: false,
          pkg: "net-misc/networkmanager" },
        { id: "bluetooth", unit: "bluetooth.service", scope: "system", feature: "Bluetooth card", required: false,
          pkg: "net-wireless/bluez" }
    ]

    readonly property var entries: root.manifest.concat(root.services.map(e => Object.assign({ names: [e.unit] }, e)))

    // Optimistic until the first probe lands, so nothing flashes "missing".
    property bool ready: false
    property var resolved: ({})
    property var problems: []
    readonly property var missing: root.problems
    property double probedAt: 0
    property bool probing: false

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    function entry(id) {
        return root.entries.find(e => e.id === id) ?? null;
    }

    function problem(id) {
        return root.problems.find(p => p.id === id) ?? null;
    }

    function has(id) {
        return !root.ready || root.problem(id) === null;
    }

    // Resolved command name; the id itself until the probe has run.
    function bin(id) {
        return root.resolved[id] || id;
    }

    // Short reason for a launcher/status row, "" when the tool is usable.
    function why(id) {
        const p = root.problem(id);
        if (!p)
            return "";
        const e = root.entry(id);
        const name = e.names[0];
        if (p.reason === "too old")
            return name + " " + p.version + " is too old, need " + e.min + " or newer";
        if (p.reason === "not running")
            return e.unit + " is not running - systemctl" + (e.scope === "user" ? " --user" : "") + " enable --now " + e.unit;
        return name + " not found - install " + e.pkg;
    }

    // Cheap re-probe for the failure path of a feature, so installing the
    // package clears the warning without restarting the shell.
    function recheckIfMissing(id) {
        if (root.ready && !root.has(id) && !root.probing && Date.now() - root.probedAt > 5000)
            root.recheck();
    }

    function recheck() {
        if (root.probing)
            return;
        root.probing = true;
        probe.running = true;
    }

    function start() {
        root.recheck();
    }

    function cmpVersion(a, b) {
        const x = a.split(".").map(Number);
        const y = b.split(".").map(Number);
        for (let i = 0; i < Math.max(x.length, y.length); i++) {
            const d = (x[i] || 0) - (y[i] || 0);
            if (d !== 0)
                return d;
        }
        return 0;
    }

    function apply(output) {
        const found = {};
        const versions = {};
        for (const line of output.split("\n")) {
            const f = line.split("\t");
            if (f.length >= 2) {
                found[f[0]] = f[1];
                versions[f[0]] = f[2] ?? "";
            }
        }

        const list = [];
        for (const e of root.entries) {
            if (e.unit && !found.systemctl)
                continue;
            const base = { id: e.id, feature: e.feature, required: e.required, version: "" };
            if (!found[e.id]) {
                list.push(Object.assign(base, { reason: e.unit ? "not running" : "missing" }));
                continue;
            }
            const m = /\d+(?:\.\d+)+/.exec(versions[e.id] ?? "");
            if (e.min && m && root.cmpVersion(m[0], e.min) < 0)
                list.push(Object.assign(base, { reason: "too old", version: m[0] }));
        }

        root.resolved = found;
        root.problems = list;
        root.probedAt = Date.now();
        root.ready = true;
        root.probing = false;
        root.persist(versions);
        notifyTimer.restart();
    }

    function signature() {
        return root.problems.map(p => p.id + ":" + p.reason).sort().join(",");
    }

    function persist(versions) {
        adapter.checkedAt = new Date().toISOString();
        adapter.resolved = root.resolved;
        adapter.versions = versions;
        adapter.missing = root.problems.map(p => ({ cmd: p.id, feature: p.feature, required: p.required, reason: p.reason }));
        stateFile.writeAdapter();
        chmodProc.running = true;
    }

    // Only the first required problem is named; the rest are counted. Optional
    // tools never notify, they show up in `deps status`.
    function announce() {
        const sig = root.signature();
        if (sig === adapter.notified)
            return;
        adapter.notified = sig;
        stateFile.writeAdapter();
        chmodProc.running = true;

        const req = root.problems.filter(p => p.required);
        if (req.length === 0)
            return;
        const first = req[0];
        const e = root.entry(first.id);
        const rest = root.problems.length - 1;
        const title = "Missing dependency";
        let body = first.reason === "missing"
            ? first.feature + " needs " + e.names[0] + " (package " + e.pkg + ")"
            : first.feature + ": " + root.why(first.id);
        if (rest > 0)
            body += ". " + rest + " more, see `qs ipc call deps status`";
        if (root.has("notify-send"))
            Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "normal", title, body]);
        else
            ToastManager.show(title + ": " + body, "");
    }

    function report() {
        if (!root.ready)
            return "not probed yet";
        if (root.problems.length === 0)
            return "all " + root.entries.length + " dependencies found";
        const rows = root.problems.map(p => {
            const e = root.entry(p.id);
            return (p.required ? "REQUIRED " : "optional ") + p.id.padEnd(20) + p.reason.padEnd(12) + " " + p.feature + " [" + (p.reason === "too old" ? e.min + "+ needed, have " + p.version : e.pkg) + "]";
        });
        return root.problems.length + " of " + root.entries.length + " missing\n" + rows.join("\n");
    }

    // One sh loop over the manifest (passed via the environment, never in the
    // script text). Uses the shell's own PATH, which can differ from a login
    // shell's when Hyprland autostarts it.
    readonly property string probeScript: [
        'mkdir -p -m 700 "$1"',
        'while IFS="|" read -r id names vflag; do',
        '  [ -n "$id" ] || continue',
        '  found=""',
        '  for n in $names; do command -v "$n" >/dev/null 2>&1 && { found=$n; break; }; done',
        '  ver=""',
        '  [ -n "$found" ] && [ -n "$vflag" ] && ver=$("$found" $vflag 2>&1 | head -n 1)',
        '  printf "%s\\t%s\\t%s\\n" "$id" "$found" "$ver"',
        'done <<EOF',
        '$QS_DEPS',
        'EOF',
        'command -v systemctl >/dev/null 2>&1 || exit 0',
        'while IFS="|" read -r id scope unit; do',
        '  [ -n "$id" ] || continue',
        '  if systemctl "--$scope" is-active --quiet "$unit" 2>/dev/null; then printf "%s\\t%s\\t\\n" "$id" "$unit"; else printf "%s\\t\\t\\n" "$id"; fi',
        'done <<EOF',
        '$QS_SERVICES',
        'EOF'
    ].join("\n")

    property var probe: Process {
        command: ["sh", "-c", root.probeScript, "sh", root.stateDir]
        environment: ({
                QS_DEPS: root.manifest.map(e => e.id + "|" + e.names.join(" ") + "|" + (e.min ? "--version" : "")).join("\n"),
                QS_SERVICES: root.services.map(e => e.id + "|" + e.scope + "|" + e.unit).join("\n")
            })
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: code => {
            if (code !== 0)
                root.probing = false;
        }
    }

    // After the probe, so our own notification server is up when notify-send
    // runs on a fresh login.
    property var notifyTimer: Timer {
        interval: 3000
        onTriggered: root.announce()
    }

    property var chmodProc: Process {
        command: ["sh", "-c", 'chmod 700 "$1" && chmod 600 "$1/deps.json"', "sh", root.stateDir]
    }

    property var stateFile: FileView {
        path: root.stateDir + "/deps.json"
        printErrors: false

        JsonAdapter {
            id: adapter
            property string checkedAt: ""
                    property string notified: ""
            property var missing: []
            property var resolved: ({})
            property var versions: ({})
        }
    }

    property var ipc: IpcHandler {
        target: "deps"

        function status(): string {
            return root.report();
        }

        function recheck(): string {
            root.recheck();
            return "rechecking";
        }

        function has(cmd: string): string {
            return root.has(cmd) ? "yes" : root.why(cmd);
        }
    }
}
