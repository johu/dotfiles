#!/usr/bin/env bash
# Wraps the Hunt: Showdown launch command: bumps NVIDIA digital vibrance via
# nvibrant (driver-level, outside the EAC-monitored game process) and enables
# a compositor-side CAS sharpen shader (Hyprland only) right before launch,
# then reverts both once the game exits, so normal desktop use stays
# unaffected. Positional args map to physical display ports as reported by
# `uvx nvibrant` on this machine; only port 7 (the main monitor) is connected.
ON=(0 0 0 0 0 0 512 0)
OFF=(0 0 0 0 0 0 0 0)
CAS_SHADER="$HOME/.config/hypr/shaders/cas.frag"

set_shader() {
  [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl eval "hl.config({decoration={screen_shader='$1'}})" >/dev/null 2>&1
}

uvx nvibrant "${ON[@]}" >/dev/null 2>&1
set_shader "$CAS_SHADER"

cleanup() {
  uvx nvibrant "${OFF[@]}" >/dev/null 2>&1
  set_shader ""
}
trap cleanup EXIT

"$@"
