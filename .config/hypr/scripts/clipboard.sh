#!/bin/bash

case $1 in
-d | --delete)
  cliphist list | rofi -dmenu -replace -config ~/.config/rofi/config-clipboard.rasi | cliphist delete
  ;;
-c | --clear)
  if [ "$(echo -e "Clear\nCancel" | rofi -dmenu -config ~/.config/rofi/config-short.rasi)" == "Clear" ]; then
    cliphist wipe
  fi
  ;;
*)
  cliphist list | rofi -dmenu -replace -config ~/.config/rofi/config-clipboard.rasi | cliphist decode | wl-copy
  ;;
esac
