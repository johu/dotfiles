#!/usr/bin/env bash
# Picks a backend at runtime: brightnessctl (kernel /sys/class/backlight
# sysfs) when a backlight device exists (laptop panel), else ddcutil
# (DDC/CI) for an external monitor with no backlight device. See
# docs/ideas/brightness-laptop-backend.md.
set -euo pipefail

STEP="10"
MIN="0"
MAX="100"

backlight_device=$(ls /sys/class/backlight 2>/dev/null | head -n1)

if [[ -n "$backlight_device" ]]; then
    backend="brightnessctl"
    current=$(brightnessctl -m -d "$backlight_device" | awk -F, '{gsub("%", "", $4); print $4}')
else
    backend="ddcutil"
    current=$(ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}')
fi

case "${1:?usage: brightness.sh up|down}" in
    up)
        next=$((current + STEP))
        [[ $next -gt $MAX ]] && next=$MAX
        ;;
    down)
        next=$((current - STEP))
        [[ $next -lt $MIN ]] && next=$MIN
        ;;
    *)
        echo "usage: brightness.sh up|down" >&2
        exit 1
        ;;
esac

if [[ "$backend" == "brightnessctl" ]]; then
    brightnessctl -d "$backlight_device" set "${next}%" > /dev/null
else
    ddcutil setvcp 10 "$next" > /dev/null
fi
