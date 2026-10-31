#!/bin/bash

# Forces Hyprland workspace 1 to be created (workspace.lua's
# on_created_empty spawns the herdr terminal there if it isn't already
# running), then waits for the herdr "emerge" tab's pane to exist before
# injecting eix-sync into it, so the sync output is visible live instead
# of going to a systemd journal nobody looks at.

GENTOO_WORKSPACE="w3"
EMERGE_TAB="w3:t1"
EMERGE_PANE="w3:p1"

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
if pgrep -x emerge -a 2>/dev/null \
    | grep -v -- '-pvuDN @world' \
    | grep -q .; then
  echo "portage-sync.sh: emerge already running, skipping" >&2
  exit 0
fi

previous_workspace=$(hyprctl -j activeworkspace | jq -r '.id')

hyprctl dispatch "hl.dsp.focus({ workspace = 1 })"

for _ in $(seq 1 30); do
  if herdr pane list --workspace "$GENTOO_WORKSPACE" 2>/dev/null \
      | jq -e --arg tab "$EMERGE_TAB" '.result.panes[] | select(.tab_id == $tab)' >/dev/null; then
    herdr pane run "$EMERGE_PANE" eix-sync
    hyprctl dispatch "hl.dsp.focus({ workspace = $previous_workspace })"
    exit 0
  fi
  sleep 0.5
done

hyprctl dispatch "hl.dsp.focus({ workspace = $previous_workspace })"
echo "portage-sync.sh: herdr pane $EMERGE_PANE never appeared, giving up" >&2
exit 1
