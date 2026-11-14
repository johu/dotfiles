import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: root

    property var notif

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 16
    radius: Theme.radius
    color: Theme.surface1

    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: 150
        }
    }
    Component.onCompleted: opacity = 1

    readonly property string accent: notif.urgency === NotificationUrgency.Critical ? Theme.red : (notif.urgency === NotificationUrgency.Low ? Theme.subtext1 : Theme.blue)

    // "default" is the spec's action for clicking the notification itself;
    // invoke it on body click like other daemons instead of showing a button.
    readonly property bool hasDefaultAction: root.notif.actions.some(a => a.identifier === "default")
    readonly property var visibleActions: root.notif.actions.filter(a => a.identifier !== "default")

    MouseArea {
        anchors.fill: parent
        enabled: root.hasDefaultAction
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifications.invokeAction(root.notif.key, "default")
    }

    Rectangle {
        width: 3
        radius: 1.5
        color: root.accent
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 8
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // leftMargin and spacing are equal so the icon sits centered between the
        // card border and the text; leftMargin only has to clear the accent bar
        // (8 + 3 = 11px).
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 14

        Item {
            // Fixed-width gutter wider than the icon, always reserved so title and body
            // share a left edge across cards.
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 42
            Layout.preferredHeight: 36

            ResolvedIcon {
                anchors.centerIn: parent
                iconSource: root.notif.iconSource
                size: 36
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    id: titleText
                    Layout.fillWidth: true
                    text: root.notif.summary
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                FontMetrics {
                    id: titleMetrics
                    font: titleText.font
                }

                Text {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Math.max(0, (titleMetrics.height - implicitHeight) / 2)
                    text: "\uf1f8"
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconFontSize - 2
                    renderType: Text.NativeRendering

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.dismissPopup(root.notif.key)
                    }
                }
            }

            Text {
                id: bodyText
                visible: root.notif.body.length > 0
                Layout.fillWidth: true
                text: root.notif.richBody
                textFormat: Text.StyledText
                linkColor: Theme.blue
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.small(-1)
                font.weight: Theme.smallWeight
                renderType: Text.NativeRendering
                wrapMode: Text.Wrap
                onLinkActivated: link => Apps.openUrl(link)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: bodyText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            Rectangle {
                visible: root.notif.previewImage.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: Theme.radius / 2
                color: "transparent"
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.notif.previewImage
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }
            }

            RowLayout {
                visible: root.visibleActions.length > 0
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.visibleActions

                    Rectangle {
                        radius: Theme.radius / 2
                        color: Theme.surface2
                        implicitWidth: actionText.implicitWidth + 16
                        implicitHeight: actionText.implicitHeight + 8

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.small(-2)
                            font.weight: Theme.smallWeight
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.invokeAction(root.notif.key, modelData.identifier)
                        }
                    }
                }
            }
        }
    }
}
