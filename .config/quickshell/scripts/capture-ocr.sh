#!/bin/sh
# OCR a region, copy the text to the clipboard, print it on stdout.
# Called by modules/Capture.qml.
#   $1 grim geometry ("X,Y WxH") used when there is no frozen image
#   $2 optional frozen full-output PNG (consumed)   $3 crop "WxH+X+Y"
# Language: $QS_OCR_LANG (tesseract -l syntax, e.g. eng+deu), else eng.
geom=$1
frozen=$2
crop=$3

tmp=$(mktemp --suffix=.png) || exit 1
trap 'rm -f "$tmp"' EXIT

if [ -n "$frozen" ]; then
    magick "$frozen" -crop "$crop" +repage -resize 200% "$tmp"
    rc=$?
    rm -f "$frozen"
    [ $rc -eq 0 ] || exit 1
else
    grim -g "$geom" "$tmp" || exit 1
    magick "$tmp" -resize 200% "$tmp" || exit 1
fi

text=$(tesseract "$tmp" stdout -l "${QS_OCR_LANG:-eng}" --psm 6 2>/dev/null | sed -e 's/[[:space:]]*$//' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
[ -n "$text" ] || exit 2
printf '%s' "$text" | wl-copy
printf '%s\n' "$text"
