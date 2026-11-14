import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

PopupWindow {
    id: root

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"

    implicitWidth: 400
    implicitHeight: 440

    // Date.now()-based text doesn't re-evaluate on its own; this tick
    // refreshes it while open.
    property int clockTick: 0

    Timer {
        running: root.visible
        repeat: true
        interval: 30000
        onTriggered: root.clockTick++
    }

    // Collapse runs of same-app entries beyond the preview count into an
    // expandable "+N more" row, so one noisy app doesn't bury the rest.
    property int groupPreviewNum: 3
    property var expandedGroups: ({})

    readonly property var groupedModel: root.buildGroupedModel(Notifications.history, root.groupPreviewNum, root.expandedGroups)

    function buildGroupedModel(history, previewNum, expanded) {
        const result = [];
        let i = 0;
        while (i < history.length) {
            const appName = history[i].appName;
            let j = i;
            while (j < history.length && history[j].appName === appName)
                j++;
            const runLength = j - i;
            const groupKey = "group-" + history[i].key;
            if (runLength <= previewNum || expanded[groupKey]) {
                for (let k = i; k < j; k++)
                    result.push(Object.assign({
                                type: "notif"
                            }, history[k]));
            } else {
                for (let k = i; k < i + previewNum; k++)
                    result.push(Object.assign({
                                type: "notif"
                            }, history[k]));
                result.push({
                    type: "group",
                    key: groupKey,
                    appName: appName,
                    count: runLength - previewNum,
                    iconSource: history[i + previewNum].iconSource
                });
            }
            i = j;
        }
        return result;
    }

    function expandGroup(key) {
        const next = Object.assign({}, root.expandedGroups);
        next[key] = true;
        root.expandedGroups = next;
    }

    function open(item) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, item.width, item.height);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x - card.implicitWidth;
        root.anchor.rect.y = Theme.barHeight + 8;
        root.visible = true;
        list.positionViewAtBeginning();
        Notifications.markSeen();
    }

    function toggle(item) {
        if (root.visible)
            root.visible = false;
        else
            open(item);
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.mantle

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "Notifications"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                renderType: Text.NativeRendering
                font.bold: true
                Layout.fillWidth: true
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                clip: true
                model: root.groupedModel
                rightMargin: 14

                ScrollBar.vertical: ScrollBar {
                    policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.surface2
                    }

                    background: Item {}
                }

                delegate: Rectangle {
                    // Explicit height and top anchor, not verticalCenter: the delegate's
                    // wrapped content settles a layout pass late, and centering in the
                    // 0-height rect clipped the first row.
                    //
                    // Width follows the ListView's rightMargin to stay clear of the scrollbar.
                    width: ListView.view.width - list.rightMargin
                    height: (modelData.type === "group" ? groupRow.implicitHeight : entryRow.implicitHeight) + 20
                    radius: Theme.radius / 2
                    color: Theme.surface1

                    Item {
                        id: groupRow
                        visible: modelData.type === "group"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 10
                        anchors.leftMargin: 0
                        implicitHeight: groupContent.implicitHeight

                        RowLayout {
                            id: groupContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 8

                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 28

                                ResolvedIcon {
                                    anchors.centerIn: parent
                                    iconSource: modelData.iconSource
                                    size: 28
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "+" + modelData.count + " more from " + modelData.appName
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.small(-2)
                                font.weight: Theme.smallWeight
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandGroup(modelData.key)
                        }
                    }

                    RowLayout {
                        id: entryRow
                        visible: modelData.type !== "group"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // Zero left margin: the outer layout's 12px margin already pads the icon,
                        // and another 10px doubled the gap.
                        anchors.topMargin: 10
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 10
                        anchors.leftMargin: 0
                        spacing: 8

                        Item {
                            // Fixed-width gutter wider than the icon; see NotificationCard.qml.
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 28

                            ResolvedIcon {
                                anchors.centerIn: parent
                                iconSource: modelData.iconSource
                                size: 28
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    id: titleText
                                    Layout.fillWidth: true
                                    text: modelData.summary
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.small(-1)
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
                                    text: (root.clockTick, Notifications.relativeTime(modelData.time))
                                    color: Theme.subtext1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.small(-3)
                                    font.weight: Theme.smallWeight
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Math.max(0, (titleMetrics.height - implicitHeight) / 2)
                                    Layout.leftMargin: 6
                                    text: "\uf1f8"
                                    color: Theme.subtext1
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.small(-2)
                                    font.weight: Theme.smallWeight
                                    renderType: Text.NativeRendering

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifications.removeHistory(modelData.key)
                                    }
                                }
                            }

                            Text {
                                id: bodyText
                                visible: modelData.body.length > 0
                                Layout.fillWidth: true
                                text: modelData.richBody
                                textFormat: Text.StyledText
                                linkColor: Theme.blue
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.small(-2)
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
                                visible: modelData.previewImage.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 110
                                radius: Theme.radius / 2
                                color: "transparent"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.previewImage
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: Notifications.history.length === 0
                Layout.alignment: Qt.AlignHCenter
                text: "No notifications"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.small(-1)
                font.weight: Theme.smallWeight
                renderType: Text.NativeRendering
            }

            Item {
                // Plain Item wrapper: anchoring a child of a RowLayout conflicts with
                // the layout.
                visible: Notifications.history.length > 0
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: clearRow.implicitWidth
                implicitHeight: clearRow.implicitHeight

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "\uf1f8"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.small(-3)
                        font.weight: Theme.smallWeight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "Clear all"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.small(-2)
                        font.weight: Theme.smallWeight
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.clearHistory()
                }
            }
        }
    }
}
