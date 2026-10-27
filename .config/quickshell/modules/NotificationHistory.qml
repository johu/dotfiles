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
                font.bold: true
                Layout.fillWidth: true
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                clip: true
                model: Notifications.history
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
                    // Explicit height (not just implicitHeight) and a
                    // top anchor on the content below, not verticalCenter -
                    // a ListView delegate with dynamic (wrap-driven)
                    // content height settles its real size a layout pass
                    // after first paint, and centering content in a
                    // not-yet-settled 0-height Rectangle clipped the first
                    // row's text in half until the second pass caught up.
                    //
                    // Delegate width follows the ListView's rightMargin (not
                    // the raw view width) so the card doesn't extend under
                    // the scrollbar track - without this the scrollbar sat
                    // flush against (overlapping) the card's right edge.
                    width: ListView.view.width - list.rightMargin
                    height: entryRow.implicitHeight + 20
                    radius: Theme.radius / 2
                    color: Theme.surface1

                    RowLayout {
                        id: entryRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // Delegates are the same fill color as the card
                        // itself (no visible border between them), so the
                        // outer ColumnLayout's own 12px margin (shared
                        // with the title/Clear-all rows) reads as part of
                        // the same visible gap before the icon - stacking
                        // a full 10px margin here on top of that made the
                        // card-edge-to-icon gap roughly double the
                        // icon-to-text gap. Drop the left margin to 0 here
                        // so the visible padding ends up close to even.
                        anchors.topMargin: 10
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 10
                        anchors.leftMargin: 0
                        spacing: 8

                        Item {
                            // Fixed-width gutter wider than the icon - see
                            // NotificationCard.qml for why.
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
                                    font.pixelSize: Theme.fontSize - 1
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
                                    font.pixelSize: Theme.fontSize - 2

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
                                font.pixelSize: Theme.fontSize - 2
                                wrapMode: Text.Wrap
                                onLinkActivated: link => Qt.openUrlExternally(link)

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
                font.pixelSize: Theme.fontSize - 1
            }

            Item {
                // A plain Item (not layout-managed) wraps the row + click
                // target, so the MouseArea's anchors.fill is safe - giving
                // anchors to a RowLayout's own direct child conflicts with
                // the layout positioning it (Qt warns "Detected anchors
                // on an item that is managed by a layout").
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
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Text {
                        text: "Clear all"
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
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
