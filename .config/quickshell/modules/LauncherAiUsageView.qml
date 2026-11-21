import QtQuick
import Quickshell
import Quickshell.Io
import "AiUsageFmt.js" as F

// AI usage view of the launcher: token usage of the AI coding tools, one tab per provider. Claude also
// shows the 5 h / weekly rate limits (AgentUsage, the same source as the dashboard card). The numbers
// come from scripts/aiusage.py, which reads only what was appended to the transcripts since the last
// run, so opening the view is quick; adding a provider means adding a source class there (see the
// script's header). Read only. Same contract as the other views.
Item {
    id: view

    property int textRender: Text.NativeRendering

    signal closeRequested
    signal leaveRequested

    readonly property int preferredWidth: 1800
    readonly property int preferredHeight: 980

    // parsed script output: { generatedAt, tabs: [...] } or null while the first run is going
    property var usage: null
    property bool failed: false
    property string tabId: "claude"
    property int liveSel: 0
    property real nowSec: Date.now() / 1000

    readonly property var tabs: view.usage ? view.usage.tabs : []
    readonly property var tab: {
        for (const t of view.tabs)
            if (t.id === view.tabId)
                return t;
        return view.tabs.length ? view.tabs[0] : null;
    }
    readonly property int tabIndex: view.tab ? view.tabs.indexOf(view.tab) : 0

    readonly property int gap: 24
    readonly property int colsH: 34 + 10 + 5 * 44
    readonly property int topH: 92

    onTextRenderChanged: GentooStyle.textRender = view.textRender
    Component.onCompleted: GentooStyle.textRender = view.textRender

    readonly property var hints: [[
            { keys: ["Tab", "h", "l"], text: "provider" },
            { keys: ["j", "k"], text: "session" },
            { keys: ["r"], text: "refresh" },
            { keys: ["q"], text: "close" }
        ]]

    function refresh() {
        if (!collector.running)
            collector.running = true;
    }

    function switchTab(delta) {
        if (view.tabs.length < 2)
            return;
        view.tabId = view.tabs[(view.tabIndex + delta + view.tabs.length) % view.tabs.length].id;
        view.liveSel = 0;
    }

    function handleKey(event) {
        const live = view.tab ? view.tab.live.length : 0;
        switch (event.key) {
        case Qt.Key_Tab:
        case Qt.Key_L:
        case Qt.Key_Right:
            view.switchTab(1);
            return true;
        case Qt.Key_Backtab:
        case Qt.Key_H:
        case Qt.Key_Left:
            view.switchTab(-1);
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            view.liveSel = Math.min(view.liveSel + 1, Math.min(live, 4) - 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            view.liveSel = Math.max(view.liveSel - 1, 0);
            return true;
        case Qt.Key_R:
            view.refresh();
            return true;
        case Qt.Key_Q:
            view.leaveRequested();
            return true;
        }
        return false;
    }

    Process {
        id: collector

        command: ["python3", "-I", Quickshell.shellPath("scripts/aiusage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    view.usage = JSON.parse(this.text.trim());
                    view.failed = false;
                    view.nowSec = Date.now() / 1000;
                    view.liveSel = Math.min(view.liveSel, Math.max(0, (view.tab ? view.tab.live.length : 1) - 1));
                } catch (e) {
                    view.failed = true;
                }
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: view.refresh()
    }

    // ---- header: provider tabs ----
    Row {
        id: tabRow

        spacing: 10
        y: 0

        // the dashboard's robot instead of a title word, like the logo of the other views
        Text {
            text: "\uee0d"
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: 38
            font.bold: true
            renderType: view.textRender
            height: 40
            width: 46
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            rightPadding: 0
        }

        Repeater {
            model: view.tabs

            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: modelData.id === (view.tab ? view.tab.id : "")

                width: label.implicitWidth + 36
                height: 38
                radius: 19
                color: on ? Theme.surface2 : GentooStyle.cardColor
                border.width: 1
                border.color: on ? Theme.blue : Theme.surface2

                GText {
                    id: label

                    anchors.centerIn: parent
                    text: modelData.label
                    strong: parent.on
                    color: parent.on ? Theme.text : GentooStyle.dim
                }
            }
        }
    }

    GText {
        anchors.right: parent.right
        y: 6
        height: 28
        text: view.failed ? "could not read the transcripts" : view.usage ? "updated " + F.ago(view.nowSec - view.usage.generatedAt).replace("now", "just now") : "reading transcripts…"
        color: GentooStyle.faint
    }

    // ---- nothing to show ----
    GText {
        visible: view.usage && view.tabs.length === 0
        anchors.centerIn: parent
        text: "No Claude Code or pi transcripts found"
        color: GentooStyle.dim
    }

    // ---- body ----
    Item {
        id: body

        visible: !!view.tab
        y: 56
        width: parent.width
        height: parent.height - 56

        readonly property real colW: (width - 2 * view.gap) / 3

        // limits (Claude) or summary cards (the others)
        Item {
            id: topRow

            width: parent.width
            height: view.topH

            Row {
                visible: !!view.tab && view.tab.limits
                spacing: 50

                AiUsageLimit {
                    width: (topRow.width - 50) / 2
                    title: "Session (5 h)"
                    percent: AgentUsage.ok ? AgentUsage.sessionPercent : -1
                    resetsAt: AgentUsage.sessionResetsAt
                    message: AgentUsage.status === "pending" ? "reading the limit…" : "limit not available (" + AgentUsage.status + ")"
                }

                AiUsageLimit {
                    width: (topRow.width - 50) / 2
                    title: "Weekly (7 d)"
                    percent: AgentUsage.ok ? AgentUsage.weeklyPercent : -1
                    resetsAt: AgentUsage.weeklyResetsAt
                    message: AgentUsage.status === "pending" ? "reading the limit…" : "limit not available (" + AgentUsage.status + ")"
                }
            }

            Row {
                visible: !!view.tab && !view.tab.limits
                spacing: view.gap

                Repeater {
                    model: !view.tab || view.tab.limits ? [] : [
                        { k: "Today", v: F.tok(view.tab.today.tokens), s: view.tab.today.req + " requests" },
                        { k: "Last 7 days", v: F.tok(view.tab.week.tokens), s: view.tab.week.req + " requests" },
                        { k: "Cost, 7 days", v: F.cost(view.tab.week.cost), s: "as reported by the provider" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: body.colW
                        height: view.topH
                        radius: 12
                        color: GentooStyle.cardColor
                        border.width: 1
                        border.color: Theme.surface2

                        GText {
                            x: 20
                            y: 8
                            width: parent.width - 40
                            height: 22
                            text: modelData.k
                            color: GentooStyle.dim
                        }

                        GText {
                            x: 20
                            y: 32
                            width: parent.width - 40
                            height: 32
                            text: modelData.v
                            strong: true
                            size: 26
                        }

                        GText {
                            x: 20
                            y: 64
                            width: parent.width - 40
                            height: 22
                            text: modelData.s
                            color: GentooStyle.faint
                        }
                    }
                }
            }
        }

        // tokens per day (takes the room the rest leaves)
        AiUsageSect {
            id: chartSect

            y: view.topH + view.gap
            width: parent.width
            title: "Tokens per day"
            extra: view.tab ? "last 14 days  ·  today " + F.tok(view.tab.today.tokens) + "  ·  7 days " + F.tok(view.tab.week.tokens) + (view.tab.cacheHit >= 0 ? "  ·  cache hit " + Math.round(view.tab.cacheHit * 100) + " %" : "") : ""
        }

        AiUsageChart {
            x: 0
            y: chartSect.y + 46
            width: parent.width
            height: Math.max(110, body.height - view.colsH - view.gap - y - 8)
            days: view.tab ? view.tab.days : []
        }

        // rankings and live sessions
        Item {
            id: cols

            y: body.height - view.colsH
            width: parent.width
            height: view.colsH

            AiUsageSect {
                width: body.colW
                title: "By model"
                extra: "tokens, 30 days"
            }

            AiUsageRank {
                y: 44
                width: body.colW
                items: view.tab ? view.tab.models : []
                showCost: true
            }

            AiUsageSect {
                x: body.colW + view.gap
                width: body.colW
                title: "By project"
                extra: "tokens, 30 days"
            }

            AiUsageRank {
                x: body.colW + view.gap
                y: 44
                width: body.colW
                items: view.tab ? view.tab.projects : []
                colors: [Theme.teal, Theme.green, Theme.yellow, Theme.maroon, Theme.pink]
            }

            AiUsageSect {
                x: 2 * (body.colW + view.gap)
                width: body.colW
                title: "Live sessions"
                extra: view.tab ? view.tab.live.length + " open" : ""
            }

            Repeater {
                model: view.tab ? view.tab.live.slice(0, 4) : []

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === view.liveSel

                    x: 2 * (body.colW + view.gap)
                    y: 44 + index * 54
                    width: body.colW
                    height: 50
                    radius: 10
                    color: sel ? GentooStyle.cardColor : "transparent"
                    border.width: sel ? 1 : 0
                    border.color: Theme.blue

                    Rectangle {
                        x: 14
                        y: 19
                        width: 12
                        height: 12
                        radius: 6
                        color: modelData.status === "working" ? Theme.green : GentooStyle.faint
                    }

                    GText {
                        x: 40
                        y: 2
                        width: parent.width - 150
                        height: 26
                        text: modelData.name
                        strong: true
                    }

                    GText {
                        x: 40
                        y: 25
                        width: parent.width - 150
                        height: 22
                        text: modelData.status + "  ·  " + (modelData.via === "pi" ? "via pi" : "terminal") + (modelData.ctx > 0 ? "  ·  ctx " + F.tok(modelData.ctx) : "")
                        color: GentooStyle.faint
                    }

                    GText {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 12
                        height: 26
                        text: F.ago(view.nowSec - modelData.since)
                        color: GentooStyle.dim
                    }
                }
            }

            GText {
                visible: !!view.tab && view.tab.live.length === 0
                x: 2 * (body.colW + view.gap) + 14
                y: 52
                text: "No session is running"
                color: GentooStyle.faint
            }
        }
    }
}
