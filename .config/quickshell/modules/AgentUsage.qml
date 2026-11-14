import QtQuick
import Quickshell.Io

// Logic-only: polls Anthropic's OAuth usage endpoint (as Claude Code does)
// for session (5h) and weekly (7d) rate-limit percentages. UI is in
// AgentUsageCard.qml.
Item {
    id: root

    readonly property int pollInterval: 5 * 60 * 1000

    property bool ok: false
    // "ok" | "auth" | "stale" | "unreachable" | "no-creds" | "pending"
    property string status: "pending"
    property real sessionPercent: -1
    property string sessionResetsAt: ""
    property real weeklyPercent: -1
    property string weeklyResetsAt: ""

    // Reads the token Claude Code keeps refreshed (CLAUDE_CONFIG_DIR, default
    // ~/.claude) and asks the usage endpoint directly; local transcripts only
    // give token counts, not rate-limit percentages.
    readonly property string collectorScript: `
import json, os, sys, time, urllib.request
from pathlib import Path

def normalize_percent(value, percent_scale):
    try:
        n = float(value)
    except Exception:
        return -1.0
    if n < 0:
        return -1.0
    if percent_scale or n > 1:
        return min(100.0, n)
    return min(100.0, n * 100.0)

env_cfg = os.environ.get("CLAUDE_CONFIG_DIR")
# No login-shell env here: try the override, its default, then the
# legacy ~/.claude, using whichever has credentials.
candidates = [Path(env_cfg)] if env_cfg else []
candidates += [Path.home() / ".config" / "claude", Path.home() / ".claude"]

creds = None
for cfg in candidates:
    try:
        creds = json.loads((cfg / ".credentials.json").read_text())["claudeAiOauth"]
        break
    except Exception:
        continue
if creds is None:
    print(json.dumps({"ok": False, "status": "no-creds"}))
    sys.exit(0)

token = creds.get("accessToken") or ""
expires_at = creds.get("expiresAt") or 0
if not token:
    print(json.dumps({"ok": False, "status": "auth"}))
    sys.exit(0)
if expires_at and expires_at <= time.time() * 1000:
    print(json.dumps({"ok": False, "status": "stale"}))
    sys.exit(0)

req = urllib.request.Request(
    "https://api.anthropic.com/api/oauth/usage",
    headers={
        "Authorization": "Bearer " + token,
        "anthropic-beta": "oauth-2025-04-20",
        "Accept": "application/json",
    },
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        payload = json.loads(resp.read().decode("utf-8", "replace"))
except Exception:
    print(json.dumps({"ok": False, "status": "unreachable"}))
    sys.exit(0)

session = payload.get("five_hour")
weekly = payload.get("seven_day_oauth_apps") or payload.get("seven_day")
raw = [(session or {}).get("utilization"), (weekly or {}).get("utilization")]
percent_scale = any(isinstance(v, (int, float)) and v > 1 for v in raw)

result = {"ok": True, "status": "ok"}
if isinstance(session, dict):
    result["sessionPercent"] = normalize_percent(session.get("utilization"), percent_scale)
    result["sessionResetsAt"] = session.get("resets_at") or ""
if isinstance(weekly, dict):
    result["weeklyPercent"] = normalize_percent(weekly.get("utilization"), percent_scale)
    result["weeklyResetsAt"] = weekly.get("resets_at") or ""

print(json.dumps(result))
`

    Process {
        id: poll
        command: ["python3", "-c", root.collectorScript]
        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(this.text.trim());
                } catch (e) {
                    return;
                }
                root.ok = !!data.ok;
                root.status = data.status ?? "";
                root.sessionPercent = data.sessionPercent ?? -1;
                root.sessionResetsAt = data.sessionResetsAt ?? "";
                root.weeklyPercent = data.weeklyPercent ?? -1;
                root.weeklyResetsAt = data.weeklyResetsAt ?? "";
            }
        }
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }
}
