import QtQuick

// Progress ring: a track and an arc of `frac` (0..1) in `color`, starting at twelve o'clock.
Canvas {
    id: ring

    property real frac: 0
    property color color: Theme.blue
    property color track: Theme.surface2
    property int lineWidth: 7

    width: 60
    height: 60
    onFracChanged: requestPaint()
    onColorChanged: requestPaint()
    onTrackChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const r = (Math.min(width, height) - ring.lineWidth) / 2, cx = width / 2, cy = height / 2;
        ctx.lineWidth = ring.lineWidth;
        ctx.lineCap = "butt";
        ctx.strokeStyle = ring.track;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.stroke();
        if (ring.frac > 0) {
            ctx.strokeStyle = ring.color;
            ctx.beginPath();
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, ring.frac));
            ctx.stroke();
        }
    }
}
