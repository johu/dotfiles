#!/usr/bin/env bash
# Wraps the Hunt: Showdown launch command: bumps NVIDIA digital vibrance via
# nvibrant (driver-level, outside the EAC-monitored game process), enables
# a compositor-side CAS sharpen shader (Hyprland only), and routes audio
# through an EasyEffects compressor (tames loud gunshots/footsteps, mirrors
# the old Windows ReaComp chain) - all right before launch, then reverts
# everything once the game exits, so normal desktop use stays unaffected.
# Positional args map to physical display ports as reported by `uvx
# nvibrant` on this machine; only port 7 (the main monitor) is connected.
ON=(0 0 0 0 0 0 512 0)
OFF=(0 0 0 0 0 0 0 0)
CAS_SHADER="$HOME/.config/hypr/shaders/cas.frag"
EE_PRESET="hunt-compressor"
EE_SINK="easyeffects_sink"

set_shader() {
  [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl eval "hl.config({decoration={screen_shader='$1'}})" >/dev/null 2>&1
}

uvx nvibrant "${ON[@]}" >/dev/null 2>&1
set_shader "$CAS_SHADER"

prev_sink="$(pactl get-default-sink 2>/dev/null)"
ee_started_by_us=0
if ! pgrep -xf 'easyeffects --service-mode --hide-window' >/dev/null 2>&1; then
  nohup easyeffects --service-mode --hide-window >/dev/null 2>&1 &
  disown
  ee_started_by_us=1
  sleep 2
fi
easyeffects -l "$EE_PRESET" >/dev/null 2>&1
pactl set-default-sink "$EE_SINK" >/dev/null 2>&1

cleanup() {
  uvx nvibrant "${OFF[@]}" >/dev/null 2>&1
  set_shader ""
  [ -n "$prev_sink" ] && pactl set-default-sink "$prev_sink" >/dev/null 2>&1
  if [ "$ee_started_by_us" = 1 ]; then
    easyeffects -q >/dev/null 2>&1
  fi
}
trap cleanup EXIT

"$@"
