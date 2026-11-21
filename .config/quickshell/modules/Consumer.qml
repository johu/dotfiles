import QtQuick

// Usage: Consumer { target: SystemData; active: view.visible }
// Increments target.<counter> while active; decrements on deactivate and
// on destruction, so reloads/destroyed views cannot leak a count.
QtObject {
    id: root

    property var target
    property bool active: false
    property string counter: "consumers"

    // Whether this instance currently holds a count (exactly once per
    // transition, regardless of binding evaluation order).
    property bool held_: false

    function sync_() {
        const want = root.active && root.target !== null && root.target !== undefined;
        if (want === root.held_)
            return;
        root.held_ = want;
        root.target[root.counter] += want ? 1 : -1;
    }

    onActiveChanged: sync_()
    onTargetChanged: sync_()
    Component.onCompleted: sync_()
    Component.onDestruction: {
        if (root.held_ && root.target) {
            root.held_ = false;
            root.target[root.counter] -= 1;
        }
    }
}
