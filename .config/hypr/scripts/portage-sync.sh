#!/bin/bash

# Forces Hyprland workspace 1 to be created (workspace.lua's
# on_created_empty spawns the herdr terminal there if it isn't already
# running), then waits for the herdr "emerge" tab's pane to exist before
# injecting eix-sync into it, so the sync output is visible live instead
# of going to a systemd journal nobody looks at.

# herdr ids (w3, w3:t1, w3:p1) differ between machines, so resolve them
# by label each poll instead of hard-coding them.
GENTOO_LABEL="gentoo"
EMERGE_TAB_LABEL="emerge"

# systemd user services run with a minimal $PATH (no ~/.local/bin) that
# doesn't include herdr - every herdr call below was silently failing
# with "command not found" under the service's 2>/dev/null, which looked
# identical to the pane genuinely never appearing. Resolve it explicitly
# instead of trusting $PATH.
HERDR="$HOME/.local/bin/herdr"

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

# Up to 90s: herdr's cold start (ghostty + zsh + herdr client attaching
# and restoring its session) competes with the rest of autostart.lua at
# session start and can genuinely take longer than a few seconds under
# that load - the old 15s window gave up before herdr had even attached.
# Prints the pane id of the first pane in the emerge tab of the gentoo
# workspace, or nothing (non-zero) if any of them doesn't exist yet.
find_emerge_pane() {
  local ws tab
  ws=$("$HERDR" workspace list 2>/dev/null \
    | jq -er --arg l "$GENTOO_LABEL" \
      '[.result.workspaces[] | select(.label == $l)][0].workspace_id') || return 1
  tab=$("$HERDR" tab list --workspace "$ws" 2>/dev/null \
    | jq -er --arg l "$EMERGE_TAB_LABEL" \
      '[.result.tabs[] | select(.label == $l)][0].tab_id') || return 1
  "$HERDR" pane list --workspace "$ws" 2>/dev/null \
    | jq -er --arg t "$tab" \
      '[.result.panes[] | select(.tab_id == $t)][0].pane_id'
}

for _ in $(seq 1 90); do
  if EMERGE_PANE=$(find_emerge_pane); then
    "$HERDR" pane run "$EMERGE_PANE" eix-sync
    hyprctl dispatch "hl.dsp.focus({ workspace = $previous_workspace })"
    exit 0
  fi
  sleep 1
done

hyprctl dispatch "hl.dsp.focus({ workspace = $previous_workspace })"
echo "portage-sync.sh: herdr workspace '$GENTOO_LABEL' / tab '$EMERGE_TAB_LABEL' never appeared, giving up" >&2
exit 1
