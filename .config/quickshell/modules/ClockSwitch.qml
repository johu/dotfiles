import QtQuick

// On / off switch (display only; the page toggles it with Space).
Rectangle {
    id: sw

    property bool on: false

    width: 46
    height: 24
    radius: 12
    // on = blue, off = grey-blue (lighter than the selection bar, so it stands out on a selected row too).
    // One geometry and one dark knob for both states: only the track colour and the knob side differ.
    color: sw.on ? Theme.blue : "#565f89"

    Rectangle {
        x: sw.on ? sw.width - 6 - width : 6
        y: (sw.height - height) / 2
        width: 16
        height: 16
        radius: 8
        color: Theme.base
    }
}
