import QtQuick
import QtQuick.Layouts

// Detail card; presentational, backed by the AgentUsage {} instance owned
// via AgentUsageRow.qml. Mirrors SystemResourcesCard.qml's layout.
Rectangle {
    id: root

    property bool ok: false
    property string status: "pending"
    property real sessionPercent: -1
    property string sessionResetsAt: ""
    property real weeklyPercent: -1
    property string weeklyResetsAt: ""

    function accentFor(percent) {
        if (percent >= 90)
            return Theme.red;
        if (percent >= 70)
            return Theme.yellow;
        return Theme.green;
    }

    function resetsIn(iso) {
        if (!iso)
            return "";
        const target = new Date(iso);
        if (isNaN(target.getTime()))
            return "";
        const deltaMs = Math.max(0, target.getTime() - Date.now());
        const totalMinutes = Math.round(deltaMs / 60000);
        const days = Math.floor(totalMinutes / 1440);
        const hours = Math.floor((totalMinutes % 1440) / 60);
        const minutes = totalMinutes % 60;
        let formatted;
        if (days > 0)
            formatted = days + "d " + hours + "h";
        else if (hours > 0)
            formatted = hours + "h " + minutes + "m";
        else
            formatted = minutes + "m";
        return "resets in " + formatted;
    }

    function helpText() {
        if (root.status === "auth")
            return "Waiting for auth\nRun `claude auth login` in a terminal.";
        if (root.status === "stale")
            return "Access token lapsed\nStart Claude Code once to refresh it.";
        if (root.status === "unreachable")
            return "Couldn't reach Anthropic's usage endpoint.";
        if (root.status === "no-creds")
            return "Not signed in to Claude Code.";
        return "";
    }

    radius: Theme.radius
    color: Theme.surface2
    implicitWidth: rows.implicitWidth + 24
    implicitHeight: rows.implicitHeight + 20

    ColumnLayout {
        id: rows
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        ResourceRow {
            icon: "\uf017"
            value: root.ok ? Math.round(root.sessionPercent) + "%" : "\u2014"
            tooltip: root.ok ? "Session (5-hour)\n" + root.resetsIn(root.sessionResetsAt) : root.helpText()
            percent: root.ok ? root.sessionPercent : -1
            accentColor: root.accentFor(root.sessionPercent)
        }

        ResourceRow {
            icon: "\uf073"
            value: root.ok ? Math.round(root.weeklyPercent) + "%" : "\u2014"
            tooltip: root.ok ? "Weekly (7-day)\n" + root.resetsIn(root.weeklyResetsAt) : root.helpText()
            percent: root.ok ? root.weeklyPercent : -1
            accentColor: root.accentFor(root.weeklyPercent)
        }
    }
}
