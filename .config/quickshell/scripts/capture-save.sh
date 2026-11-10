#!/bin/sh
# Capture a region, save it, copy it, and announce it with a notification
# that has Open / Edit actions. Called by modules/Capture.qml.
#   $1 output directory   $2 grim geometry ("X,Y WxH")
#   $3 optional frozen full-output PNG (consumed)   $4 crop "WxH+X+Y" of it
dir=$1
geom=$2
frozen=$3
crop=$4

mkdir -p "$dir" || exit 1
f="$dir/$(date +%F-%H%M%S).png"
if [ -n "$frozen" ]; then
    magick "$frozen" -crop "$crop" +repage "$f"
    rc=$?
    rm -f "$frozen"
    [ $rc -eq 0 ] || exit 1
else
    grim -g "$geom" "$f" || exit 1
fi
wl-copy --type image/png <"$f" || exit 1

# notify-send --wait blocks until the notification closes and prints the
# invoked action id, so run it detached: the caller must not wait on it.
setsid sh -c '
    f=$1
    action=$(notify-send -a Screenshot -i "$f" \
        -A open=Open -A edit=Edit --wait \
        "Screenshot saved" "Copied to clipboard · ${f##*/}")
    case $action in
    open) xdg-open "$f" ;;
    edit)
        if command -v satty >/dev/null; then
            satty --filename "$f"
        elif command -v swappy >/dev/null; then
            swappy -f "$f"
        else
            gimp "$f"
        fi
        ;;
    esac
' sh "$f" >/dev/null 2>&1 </dev/null &
exit 0
