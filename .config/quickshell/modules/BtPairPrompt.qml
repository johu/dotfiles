import QtQuick
import QtQuick.Layouts

// Prompt for BtAgent: shows the pending question (confirm / PIN / passkey /
// authorize) or the code to type on the device, and answers through `agent`.
// Fixed height so a launcher view does not jump when it appears.
Rectangle {
    id: root

    required property var agent
    readonly property var req: agent.request
    readonly property var disp: agent.display
    readonly property bool active: req !== null || disp !== null

    implicitHeight: 96
    radius: Theme.radius
    color: Theme.mantle
    border.color: Theme.blue
    border.width: 1
    visible: active

    function pad(n, w) {
        return String(n).padStart(w, "0");
    }

    readonly property string title: {
        if (req) {
            const n = req.name;
            switch (req.kind) {
            case "confirm":
                return "Pair with " + n + "?";
            case "pin":
                return "Enter PIN for " + n;
            case "passkey":
                return "Enter passkey for " + n;
            case "authorize":
                return "Allow " + n + " to connect?";
            case "service":
                return "Allow " + n + " to use a service?";
            }
        }
        if (disp)
            return disp.passkey !== undefined ? "Type on " + disp.name + ": " + pad(disp.passkey, 6) + "  (" + disp.entered + "/6)" : "Type on " + disp.name + ": " + disp.pin;
        return "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
        Text {
            visible: root.req !== null && root.req.kind === "confirm"
            text: root.req && root.req.passkey !== undefined ? root.pad(root.req.passkey, 6) : ""
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 6
            font.bold: true
        }
        TextInput {
            id: input
            visible: root.req !== null && (root.req.kind === "pin" || root.req.kind === "passkey")
            Layout.fillWidth: true
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            inputMethodHints: root.req && root.req.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNoPredictiveText
            maximumLength: root.req && root.req.kind === "passkey" ? 6 : 16
            focus: visible
            onVisibleChanged: if (visible)
                text = ""
            Keys.onReturnPressed: root.agent.submit(text)
        }
        RowLayout {
            visible: root.req !== null
            spacing: 12
            Text {
                text: root.req && (root.req.kind === "pin" || root.req.kind === "passkey") ? "Enter: send   Esc: cancel" : "Enter: yes   Esc: no"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.minFontSize
            }
        }
    }

    // Keyboard answers, active only while a question is pending.
    Keys.onReturnPressed: if (req && req.kind !== "pin" && req.kind !== "passkey")
        agent.accept()
    Keys.onEscapePressed: agent.reject()
    focus: req !== null
}
