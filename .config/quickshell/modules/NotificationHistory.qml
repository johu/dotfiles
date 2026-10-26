import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

PopupWindow {
    id: root

    anchor.adjustment: PopupAdjustment.Slide
    grabFocus: false
    color: "transparent"

    implicitWidth: 340
    implicitHeight: 420

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
                    height: entryColumn.implicitHeight + 20
                    radius: Theme.radius / 2
                    color: Theme.surface1

                    ColumnLayout {
                        id: entryColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            ResolvedIcon {
                                visible: modelData.appIcon.length > 0
                                iconSource: "image://icon/" + modelData.appIcon
                                size: 14
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appName
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "\uf00d"
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
                            Layout.fillWidth: true
                            text: modelData.summary
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: modelData.body.length > 0
                            Layout.fillWidth: true
                            text: modelData.body
                            textFormat: Text.PlainText
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
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

            Text {
                visible: Notifications.history.length > 0
                Layout.alignment: Qt.AlignHCenter
                text: "Clear all"
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2

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
