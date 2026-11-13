import QtQuick
import QtQuick.Layouts

// Always-visible Claude Code usage summary for Dashboard.qml; click
// toggles the detailed AgentUsageCard (session + weekly meters) below it.
// Backed by an invisible AgentUsage {} logic instance owned by the caller.
// Mirrors WeatherRow.qml's summary/expand/fade shape.
ColumnLayout {
    id: root

    property bool ok: false
    property string status: "pending"
    property real sessionPercent: -1
    property string sessionResetsAt: ""
    property real weeklyPercent: -1
    property string weeklyResetsAt: ""

    property string summaryText: {
        if (root.status === "pending")
            return "Loading…";
        if (!root.ok) {
            if (root.status === "auth" || root.status === "stale")
                return "Waiting for auth";
            if (root.status === "unreachable")
                return "Can't reach Anthropic";
            return "Not signed in";
        }
        return "Session " + Math.round(root.sessionPercent) + "% · Weekly " + Math.round(root.weeklyPercent) + "%";
    }

    property bool expanded: false

    spacing: 6

    Rectangle {
        Layout.fillWidth: true
        // Matches the other dashboard card rows' background.
        color: Qt.lighter(Theme.surface1, 1.3)
        radius: Theme.radius
        implicitHeight: summaryRow.implicitHeight + 16

        RowLayout {
            id: summaryRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            Text {
                text: "\uee0d"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: Theme.iconFontSize
                renderType: Text.NativeRendering
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "AI Usage"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                    font.bold: true
                }

                Text {
                    // Layout.fillWidth + elide here isn't just cosmetic
                    // overflow handling - omitting it mis-positions the
                    // icon column to this Text's left by a non-constant
                    // offset (footguns.md #19). Always pair a dynamic-
                    // width subtitle Text in one of these summary rows
                    // with both properties.
                    Layout.fillWidth: true
                    text: root.summaryText
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.small(-2)
                    font.weight: Theme.smallWeight
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Same reserve-then-fade sequencing as SystemResourcesRow.qml/
    // WeatherRow.qml - see either file's comment for why this two-step
    // (grow box, then fade content in) is needed instead of a plain
    // opacity Behavior.
    property bool reserved: false

    onExpandedChanged: {
        if (root.expanded) {
            fadeOut.stop();
            root.reserved = true;
            growDelay.restart();
        } else {
            growDelay.stop();
            fadeIn.stop();
            fadeOut.restart();
        }
    }

    Timer {
        id: growDelay
        interval: 180
        onTriggered: fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: detailCard
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: detailCard
        property: "opacity"
        to: 0
        duration: 150
        easing.type: Easing.OutCubic
        onStopped: if (!root.expanded)
            root.reserved = false
    }

    AgentUsageCard {
        id: detailCard
        Layout.fillWidth: true
        visible: root.reserved
        opacity: 0
        ok: root.ok
        status: root.status
        sessionPercent: root.sessionPercent
        sessionResetsAt: root.sessionResetsAt
        weeklyPercent: root.weeklyPercent
        weeklyResetsAt: root.weeklyResetsAt
    }
}
