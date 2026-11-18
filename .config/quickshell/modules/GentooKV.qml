import QtQuick

// "label   value" row with a fixed label column.
Item {
    id: kv

    property string label: ""
    property string value: ""
    property color valueColor: Theme.text
    property int labelWidth: 150
    property int size: Theme.fontSize + 1

    width: parent ? parent.width : 300
    height: size + 14

    GText {
        width: kv.labelWidth
        height: parent.height
        text: kv.label
        color: GentooStyle.dim
        size: kv.size - 1
    }

    GText {
        x: kv.labelWidth
        width: parent.width - kv.labelWidth
        height: parent.height
        text: kv.value
        color: kv.valueColor
        size: kv.size
    }
}
