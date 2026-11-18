import QtQuick

// Status symbol without a background shape: check (ok), play (active), warning, cross (error),
// pause, dot (idle / waiting). Each kind has its own silhouette, so they stay apart at a glance.
Item {
    id: icon

    property string kind: "ok"
    property int size: 24

    readonly property var spec: ({
            ok: { c: Theme.green, g: "", dy: 1 },
            active: { c: Theme.green, g: "", dy: 2 },
            warn: { c: Theme.yellow, g: "", dy: 0 },
            error: { c: Theme.red, g: "", dy: 2 },
            paused: { c: Theme.yellow, g: "", dy: 2 },
            idle: { c: GentooStyle.faint, g: "", dy: 1 }
        })[kind] ?? { c: Theme.green, g: "", dy: 0 }

    width: size
    height: size

    Text {
        anchors.centerIn: parent
        // The glyphs sit 1-2 px above the middle of the text line next to them (measured per glyph).
        anchors.verticalCenterOffset: icon.spec.dy
        text: icon.spec.g
        color: icon.spec.c
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(icon.size * (icon.kind === "idle" ? 0.5 : 0.82))
        renderType: GentooStyle.textRender
    }
}
