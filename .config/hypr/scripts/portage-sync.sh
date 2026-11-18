#!/bin/bash

# Forces Hyprland workspace 1 to be created (workspace.lua's
# on_created_empty spawns the herdr terminal there if it isn't already
# running), then waits for the herdr "emerge" tab's pane to exist before
# injecting eix-sync into it, so the sync output is visible live instead
# of going to a systemd journal nobody looks at.

# The herdr lookup (workspace "gentoo", tab "emerge") and all its notes live in herdr-emerge-run.sh.

# Guard against surprise re-runs: a systemd daemon-reload re-arms the
# timer's OnActiveSec=, so every reload (login, enabling a unit, ...)
# would otherwise trigger another eix-sync ~90s later. Skip if a sync was
# started less than MIN_INTERVAL seconds ago. The stamp is only written
# after the sync was actually sent, so skips (game mode, emerge running,
# herdr never appearing) don't suppress the next attempt.
STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/portage-sync.stamp"
MIN_INTERVAL=$((3 * 3600))

# Same ~/.cache/gamemode flag NightLight.qml and PortageUpdates.qml's own
# pretend-check already respect (see hypr/keybinds.lua's SUPER+F2 toggle).
# This script forces a workspace switch below, which would yank focus out
# of a running game - skip the whole sync while gaming, not just the
# dependency-resolution check.
if [ -f ~/.cache/gamemode ]; then
  echo "portage-sync.sh: game mode active, skipping" >&2
  exit 0
fi

# Same real-build detection PortageUpdates.qml's statusCheck uses: pgrep
# -x emerge also matches our own pretend check (and eix-sync's internal
# `emerge --sync`), so exclude both before deciding something is already
# running. eix-sync itself calls emerge --sync - running it concurrently
# with a real build risks portage db lock contention, on top of it also
# forcing a workspace switch over whatever the user is watching build.
if [ -f "$STAMP" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$STAMP") ))
  if [ "$age" -lt "$MIN_INTERVAL" ]; then
    echo "portage-sync.sh: last sync ${age}s ago (< ${MIN_INTERVAL}s), skipping" >&2
    exit 0
  fi
fi

if pgrep -x emerge -a 2>/dev/null \
    | grep -v -- '-pvuDN @world' \
    | grep -q .; then
  echo "portage-sync.sh: emerge already running, skipping" >&2
  exit 0
fi

# Switching to workspace 1, making sure herdr runs, typing eix-sync into the emerge tab and switching
# back is shared with the quickshell Gentoo view: see herdr-emerge-run.sh.
if "$(dirname "$(readlink -f "$0")")/herdr-emerge-run.sh" --background eix-sync; then
  touch "$STAMP"
  exit 0
fi
exit 1
