#!/usr/bin/env bash
# Single external DP monitor (ASUS VG27A), no laptop backlight device —
# brightnessctl has nothing to control, and Hyprland's sdrbrightness is an
# SDR-under-HDR reference-luminance knob with no visible effect on a plain
# `cm = srgb` desktop (confirmed: readback changes, pixels never do). Real
# hardware brightness is set over DDC/CI via ddcutil (VCP feature 0x10),
# which this monitor supports without needing the NVIDIA RMUseSwI2c
# registry tweak.
set -euo pipefail

STEP="10"
MIN="0"
MAX="100"

current=$(ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}')

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

ddcutil setvcp 10 "$next" > /dev/null
