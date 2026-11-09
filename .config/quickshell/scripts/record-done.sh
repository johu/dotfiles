#!/bin/sh
# Announce a finished screen recording with Open / Show folder actions.
# Called by modules/Recorder.qml. $1 = saved video file.
f=$1
[ -f "$f" ] || exit 1

# notify-send --wait blocks until the notification closes, so detach it.
setsid sh -c '
    f=$1
    action=$(notify-send -a "Screen recording" -i video-x-generic \
        -A open=Open -A folder="Show folder" --wait \
        "Recording saved" "${f##*/}")
    case $action in
    open) xdg-open "$f" ;;
    folder) xdg-open "$(dirname "$f")" ;;
    esac
' sh "$f" >/dev/null 2>&1 </dev/null &
exit 0
