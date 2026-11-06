#!/usr/bin/env bash
# Wraps the Hunt: Showdown launch command: bumps NVIDIA digital vibrance via
# nvibrant (driver-level, outside the EAC-monitored game process), enables
# a compositor-side CAS sharpen shader (Hyprland only), routes audio through
# an EasyEffects compressor (tames loud gunshots/footsteps, mirrors the old
# Windows ReaComp chain), and shows a click-through crosshair overlay via
# layer-shell (Hyprland and Plasma) - all right before launch, then reverts
# everything once the game exits, so normal desktop use stays unaffected.
# Positional args map to physical display ports as reported by `uvx
# nvibrant` on this machine; only port 7 (the main monitor) is connected.
ON=(0 0 0 0 0 0 512 0)
OFF=(0 0 0 0 0 0 0 0)
CAS_SHADER="$HOME/.config/hypr/shaders/cas.frag"
CROSSHAIR="$HOME/.config/hypr/scripts/hunt-crosshair.py"
# gtk4-layer-shell must be preloaded ahead of libwayland-client or it
# silently falls back to a regular (non-click-through) window - see
# https://github.com/wmww/gtk4-layer-shell/blob/main/linking.md
CROSSHAIR_PRELOAD="/usr/lib64/libgtk4-layer-shell.so.0"
EE_PRESET="hunt-compressor"
EE_SINK="easyeffects_sink"
EE_TARGET_DEVICE="alsa_output.usb-JDS_Labs_JDS_Labs_UAC2_DAC__XU208_-00.iec958-stereo"
EE_CONFIG="$HOME/.config/easyeffects/db/easyeffectsrc"

set_shader() {
  [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl eval "hl.config({decoration={screen_shader='$1'}})" >/dev/null 2>&1
}

uvx nvibrant "${ON[@]}" >/dev/null 2>&1
set_shader "$CAS_SHADER"

prev_sink="$(pactl get-default-sink 2>/dev/null)"

# Pin EasyEffects' output target to the JDS Labs DAC before (re)starting it -
# it otherwise tracks whatever sink happened to be default last time it
# saved its config, which silently routes game audio to the wrong device
# if the default sink had changed (e.g. onboard audio) since.
if pgrep -xf 'easyeffects --service-mode --hide-window' >/dev/null 2>&1; then
  easyeffects -q >/dev/null 2>&1
  sleep 1
fi
if [ -f "$EE_CONFIG" ]; then
  sed -i "s|^outputDevice=.*|outputDevice=$EE_TARGET_DEVICE|" "$EE_CONFIG"
fi
nohup easyeffects --service-mode --hide-window >/dev/null 2>&1 &
disown
ee_started_by_us=1
sleep 2
easyeffects -l "$EE_PRESET" >/dev/null 2>&1
pactl set-default-sink "$EE_SINK" >/dev/null 2>&1

if [ -r "$CROSSHAIR_PRELOAD" ]; then
  LD_PRELOAD="$CROSSHAIR_PRELOAD" nohup python3 "$CROSSHAIR" >/dev/null 2>&1 &
else
  nohup python3 "$CROSSHAIR" >/dev/null 2>&1 &
fi
crosshair_pid=$!
disown

cleanup() {
  uvx nvibrant "${OFF[@]}" >/dev/null 2>&1
  set_shader ""
  [ -n "$prev_sink" ] && pactl set-default-sink "$prev_sink" >/dev/null 2>&1
  if [ "$ee_started_by_us" = 1 ]; then
    easyeffects -q >/dev/null 2>&1
  fi
  kill "$crosshair_pid" >/dev/null 2>&1
}
trap cleanup EXIT

"$@"
