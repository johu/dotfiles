import QtQuick

// One-line input of the Clock view (the launcher view has no TextInput of its own): label, typed
// text with a cursor, and a hint on the right. The page owns the keys: it calls handle(event) while
// `active` and decides what Enter and Esc do.
Rectangle {
    id: input

    property string label: ""
    property string text: ""
    property string hint: ""
    property string placeholder: ""
    // shown while the input is not active (e.g. the current value of what it edits)
    property string idleText: ""
    property bool active: false
    property int maxLength: 48

    height: 52
    radius: 14
    color: Theme.base
    border.width: input.active ? 2 : 1
    border.color: input.active ? Theme.blue : Theme.surface2

    // true when the key was text editing (typing, Backspace, Ctrl-U)
    function handle(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Backspace) {
            input.text = input.text.slice(0, -1);
            return true;
        }
        if (ctrl && event.key === Qt.Key_U) {
            input.text = "";
            return true;
        }
        if (!ctrl && event.text.length === 1 && event.text >= " ") {
            if (input.text.length < input.maxLength)
                input.text += event.text;
            return true;
        }
        return false;
    }

    GText {
        id: labelText

        x: 20
        width: implicitWidth
        height: parent.height
        text: input.label
        color: GentooStyle.dim
        size: Theme.fontSize + 2
    }

    GText {
        x: labelText.x + labelText.width + 16
        width: parent.width - x - hintText.width - 40
        height: parent.height
        text: input.active ? input.text + "▏" : (input.idleText !== "" ? input.idleText : input.placeholder)
        color: input.active ? Theme.yellow : (input.idleText !== "" ? Theme.text : GentooStyle.faint)
        size: Theme.fontSize + 6
        strong: input.active ? input.text !== "" : input.idleText !== ""
        elide: Text.ElideLeft
    }

    GText {
        id: hintText

        x: parent.width - width - 20
        width: Math.min(implicitWidth, parent.width * 0.55)
        height: parent.height
        horizontalAlignment: Text.AlignRight
        text: input.hint
        color: GentooStyle.dim
        size: Theme.fontSize + 2
    }
}
