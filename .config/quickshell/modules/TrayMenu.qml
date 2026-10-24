import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Renders a tray item's context menu entirely in QML instead of invoking
// the native Qt PlatformMenuEntry, whose icon resolution is pure C++ with
// no QML hook to apply ResolvedIcon's icon-fix workaround.
PopupWindow {
    id: root

    property var rootHandle: null
    property var stack: []
    readonly property var currentHandle: root.stack.length > 0 ? root.stack[root.stack.length - 1] : root.rootHandle

    // Tracks which tray icon currently owns the open menu, so a second
    // right-click on the same icon closes it via toggle(). open() always
    // closes and reopens rather than just moving the anchor, since
    // PopupWindow's anchor is only evaluated once when the window
    // transitions to visible.
    property var currentItem: null
    property var pendingHandle: null

    function toggle(item, handle) {
        if (root.visible && root.currentItem === item) {
            root.close();
        } else {
            root.open(item, handle);
        }
    }

    function open(item, handle) {
        root.currentItem = item;
        root.pendingHandle = handle;
        if (root.visible) {
            root.visible = false;
            reopenTimer.restart();
        } else {
            root.applyOpen(item, handle);
        }
    }

    function close() {
        root.visible = false;
    }

    function applyOpen(item, handle) {
        const win = item.QsWindow;
        const pos = win.mapFromItem(item, 0, item.height);
        root.anchor.window = win.window;
        root.anchor.rect.x = pos.x;
        root.anchor.rect.y = pos.y + 4;
        root.rootHandle = handle;
        root.stack = [];
        root.visible = true;
    }

    Timer {
        id: reopenTimer
        interval: 1
        onTriggered: root.applyOpen(root.currentItem, root.pendingHandle)
    }

    function pushSubmenu(entry) {
        root.stack = root.stack.concat([entry]);
    }

    function popSubmenu() {
        root.stack = root.stack.slice(0, -1);
    }

    onVisibleChanged: if (!root.visible) {
        root.stack = [];
        root.rootHandle = null;
        root.currentItem = null;
    }

    grabFocus: false
    color: "transparent"
    implicitWidth: 220
    implicitHeight: list.implicitHeight + 12

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.visible = false
    }

    QsMenuOpener {
        id: opener
        menu: root.currentHandle
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface1
        border.color: Theme.surface2
        border.width: 1

        ColumnLayout {
            id: list
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Rectangle {
                visible: root.stack.length > 0
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Theme.radius
                color: backHover.hovered ? Theme.surface2 : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6
                    Text {
                        text: "\uf060"
                        color: Theme.text
                        font.family: Theme.fontFamily
                    }
                    Text {
                        text: "Back"
                        color: Theme.text
                        font.family: Theme.fontFamily
                    }
                }

                HoverHandler { id: backHover }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.popSubmenu()
                }
            }

            Repeater {
                model: opener.children

                delegate: Loader {
                    id: entryLoader
                    required property var modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData.isSeparator ? separatorComponent : itemComponent

                    Component {
                        id: separatorComponent
                        Rectangle {
                            implicitHeight: 1
                            color: Theme.surface2
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }
                    }

                    Component {
                        id: itemComponent
                        Rectangle {
                            implicitHeight: 28
                            radius: Theme.radius
                            color: entryHover.hovered ? Theme.surface2 : "transparent"
                            opacity: entryLoader.modelData.enabled ? 1 : 0.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                ResolvedIcon {
                                    visible: entryLoader.modelData.icon.length > 0
                                    iconSource: entryLoader.modelData.icon
                                    size: 16
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: entryLoader.modelData.text
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: entryLoader.modelData.hasChildren
                                    text: "\uf105"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                }
                            }

                            HoverHandler { id: entryHover }
                            MouseArea {
                                anchors.fill: parent
                                enabled: entryLoader.modelData.enabled
                                onClicked: {
                                    if (entryLoader.modelData.hasChildren) {
                                        root.pushSubmenu(entryLoader.modelData);
                                    } else {
                                        entryLoader.modelData.triggered();
                                        root.visible = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
