import QtQuick
import QtQuick.Layouts

// Claude Code usage summary; click expands the AgentUsageCard. Backed by
// an invisible AgentUsage {} owned by the caller. Same shape as
// WeatherRow.qml.
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
                    // fillWidth + elide is required, not cosmetic: without it the icon column
                    // is mis-positioned by a varying offset (footguns.md #19).
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

    // Reserve-then-fade sequencing as in SystemResourcesRow.qml.
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
