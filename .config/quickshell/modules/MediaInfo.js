.pragma library

// Turns `ffprobe -of default` output ([STREAM] / [FORMAT] sections with
// key=value lines) into a short aligned summary for the file preview.

function parse(text) {
    var streams = [];
    var format = {};
    var cur = null;
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim();
        if (l === "[STREAM]") {
            cur = {};
            streams.push(cur);
        } else if (l === "[FORMAT]") {
            cur = format;
        } else if (l.charAt(0) === "[") {
            cur = null;
        } else if (cur && l.indexOf("=") > 0) {
            var k = l.slice(0, l.indexOf("="));
            cur[k] = l.slice(l.indexOf("=") + 1);
        }
    }
    return { streams: streams, format: format };
}

function clock(sec) {
    var s = Math.round(parseFloat(sec));
    if (!isFinite(s))
        return "";
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var r = s % 60;
    var two = function (n) {
        return n < 10 ? "0" + n : "" + n;
    };
    return h > 0 ? h + ":" + two(m) + ":" + two(r) : m + ":" + two(r);
}

function fps(rate) {
    var p = (rate || "").split("/");
    var n = parseFloat(p[0]);
    var d = parseFloat(p[1]);
    if (!isFinite(n) || !isFinite(d) || d === 0 || n === 0)
        return "";
    var v = n / d;
    if (v > 240)
        return "";
    return (Math.round(v * 100) / 100) + " fps";
}

function channels(n) {
    return n === "1" ? "mono" : (n === "2" ? "stereo" : (n ? n + " channels" : ""));
}

var COVER = { mjpeg: true, png: true, bmp: true, gif: true, webp: true };

function row(label, value) {
    return value ? (label + "          ").slice(0, 10) + value : "";
}

function format(text) {
    var info = parse(text);
    var f = info.format;
    var audio = null;
    var video = null;
    for (var i = 0; i < info.streams.length; i++) {
        var s = info.streams[i];
        if (s.codec_type === "audio" && !audio)
            audio = s;
        else if (s.codec_type === "video" && !video && !(COVER[s.codec_name] && info.streams.length > 1))
            video = s;
    }
    var out = [
        row("Title", f["TAG:title"]),
        row("Artist", f["TAG:artist"]),
        row("Album", f["TAG:album"]),
        row("Year", f["TAG:date"]),
        row("Genre", f["TAG:genre"]),
        row("Track", f["TAG:track"]),
        row("Duration", clock(f.duration)),
        row("Bitrate", f.bit_rate ? Math.round(parseFloat(f.bit_rate) / 1000) + " kb/s" : ""),
        row("Format", f.format_long_name)
    ];
    if (video)
        out.push(row("Video", [video.codec_name, video.width && video.height ? video.width + "x" + video.height : "", fps(video.r_frame_rate)].filter(Boolean).join("  ")));
    if (audio)
        out.push(row("Audio", [audio.codec_name, audio.sample_rate ? (Math.round(parseFloat(audio.sample_rate) / 100) / 10) + " kHz" : "", channels(audio.channels)].filter(Boolean).join("  ")));
    return out.filter(Boolean).join("\n");
}
