#!/usr/bin/env bash

STATE="$HOME/.cache/gamemode"

if [[ -f "$STATE" ]]; then
    hyprctl reload
    rm -f "$STATE"
    hyprctl notify 1 10000 "rgb(ff757f)" "Gamemode OFF"
else
    hyprctl keyword general:gaps_in 0
    hyprctl keyword general:gaps_out 0
    hyprctl keyword decoration:rounding 0
    hyprctl dispatch 'hl.config { general = { gaps_in = 0, gaps_out = 0, border_size = 1 }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } }, animations = { enabled = false } }'
    touch "$STATE"

    hyprctl notify 1 10000 "rgb(c3e88d)" "Gamemode ON"
fi
