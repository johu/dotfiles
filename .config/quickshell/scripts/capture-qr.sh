#!/bin/sh
# Decode a QR code in a region, copy it to the clipboard, print it on
# stdout. Links also get a notification with an Open action.
# Called by modules/Capture.qml.
#   $1 grim geometry ("X,Y WxH") used when there is no frozen image
#   $2 optional frozen full-output PNG (consumed)   $3 crop "WxH+X+Y"
geom=$1
frozen=$2
crop=$3

tmp=$(mktemp --suffix=.png) || exit 1
trap 'rm -f "$tmp"' EXIT

if [ -n "$frozen" ]; then
    magick "$frozen" -crop "$crop" +repage "$tmp"
    rc=$?
    rm -f "$frozen"
    [ $rc -eq 0 ] || exit 1
else
    grim -g "$geom" "$tmp" || exit 1
fi

text=$(zbarimg -q --raw -Sdisable -Sqrcode.enable "$tmp" 2>/dev/null)
[ -n "$text" ] || exit 2
printf '%s' "$text" | wl-copy
printf '%s\n' "$text"

case $text in
http://* | https://*)
    # notify-send --wait blocks until the notification closes: detach.
    setsid sh -c '
        action=$(notify-send -a Screenshot -i qrscanner-symbolic -A open=Open --wait \
            "QR code copied" "$1")
        [ "$action" = open ] && xdg-open "$1"
    ' sh "$text" >/dev/null 2>&1 </dev/null &
    ;;
esac
exit 0
