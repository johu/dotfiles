#!/bin/bash
# Types a command into the first pane of herdr's "emerge" tab (workspace "gentoo"), starting the
# herdr terminal first when nobody is attached. Shared by portage-sync.sh and the quickshell Gentoo
# view, so both use the same terminal and session.
#
# usage: herdr-emerge-run.sh [--background] COMMAND
#   (default)     leave Hyprland on workspace 1 and focus the herdr tab, so the user sees the output
#   --background  only visit workspace 1 to get herdr running and return to the previous workspace
# exit: 0 sent, 3 another portage / flatpak process is running (reason on stderr), 1 herdr never appeared

# herdr ids (w3, w3:t1, w3:p1) differ between machines, so resolve them by label each poll.
GENTOO_LABEL="gentoo"
EMERGE_TAB_LABEL="emerge"

# systemd user services run with a minimal $PATH that does not include herdr.
HERDR="$HOME/.local/bin/herdr"

background=0
if [ "$1" = "--background" ]; then
  background=1
  shift
fi
cmd="$*"
[ -n "$cmd" ] || { echo "herdr-emerge-run.sh: no command given" >&2; exit 2; }

# A second portage process would fight over the db lock and a sync / clean would race a build.
# Pretend runs (-p, --pretend) are read only and are ours (update check, depclean), so they do not count.
busy_reason() {
  local line
  line=$(pgrep -af '(^|/)(emerge|eclean-dist|eclean-pkg|eclean-kernel|smart-live-rebuild|dispatch-conf)( |$)' 2>/dev/null \
    | grep -Ev -- ' -[a-zA-Z]*p[a-zA-Z]* |--pretend' | head -n1)
  if [ -z "$line" ]; then
    line=$(pgrep -af '(^|/)flatpak (update|install|uninstall)( |$)' 2>/dev/null | head -n1)
  fi
  [ -n "$line" ] || return 1
  # "1234 /usr/bin/python3.14 /usr/lib/python-exec/python3.14/emerge --sync" -> "emerge --sync"
  echo "$line" | sed -E 's/^[0-9]+ //; s#[^ ]*/(emerge|eclean-dist|eclean-pkg|eclean-kernel|smart-live-rebuild|dispatch-conf|flatpak)#\1#' | cut -c1-90
}

if reason=$(busy_reason); then
  echo "busy: $reason" >&2
  exit 3
fi

previous_workspace=$(hyprctl -j activeworkspace | jq -r '.id')

hyprctl dispatch "hl.dsp.focus({ workspace = 1 })" >/dev/null

back() {
  [ "$background" = 1 ] && hyprctl dispatch "hl.dsp.focus({ workspace = $previous_workspace })" >/dev/null
}

# The herdr *server* keeps running after its terminal is closed, so the pane lookup below can
# succeed with nobody watching. A client is any herdr process whose cmdline lacks "server".
herdr_client_running() {
  local pid
  for pid in $(pgrep -x herdr); do
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -qw server || return 0
  done
  return 1
}

# Terminal-agnostic: $TERMINAL, then the systemd user environment, then hypr/globals.lua's
# `terminal = '...'`, then the first known terminal on PATH.
resolve_terminal() {
  local t="${TERMINAL:-}"
  [ -n "$t" ] || t=$(systemctl --user show-environment 2>/dev/null \
    | sed -n 's/^TERMINAL=//p')
  [ -n "$t" ] || t=$(sed -n "s/^ *terminal *= *'\([^']*\)'.*/\1/p" \
    "$HOME/.config/hypr/globals.lua" 2>/dev/null | head -n1)
  if [ -z "$t" ] || ! command -v "$t" >/dev/null 2>&1; then
    t=""
    for c in ghostty kitty alacritty foot wezterm; do
      command -v "$c" >/dev/null 2>&1 && { t=$c; break; }
    done
  fi
  printf '%s' "$t"
}

# Focusing an empty workspace 1 makes workspace.lua spawn the herdr terminal itself; give that a
# few seconds so we don't launch a second one, then spawn our own if nothing attached.
for _ in $(seq 1 8); do
  herdr_client_running && break
  sleep 1
done
if ! herdr_client_running; then
  term=$(resolve_terminal)
  if [ -z "$term" ]; then
    back
    echo "herdr-emerge-run.sh: no herdr client and no terminal found to start one" >&2
    exit 1
  fi
  echo "herdr-emerge-run.sh: no herdr client attached, launching $term" >&2
  hyprctl dispatch "hl.dsp.exec_cmd('$term -e zsh -c herdr')" >/dev/null
fi

# Sets WS, TAB and PANE for the first pane of the emerge tab of the gentoo workspace.
find_emerge_pane() {
  WS=$("$HERDR" workspace list 2>/dev/null \
    | jq -er --arg l "$GENTOO_LABEL" \
      '[.result.workspaces[] | select(.label == $l)][0].workspace_id') || return 1
  TAB=$("$HERDR" tab list --workspace "$WS" 2>/dev/null \
    | jq -er --arg l "$EMERGE_TAB_LABEL" \
      '[.result.tabs[] | select(.label == $l)][0].tab_id') || return 1
  PANE=$("$HERDR" pane list --workspace "$WS" 2>/dev/null \
    | jq -er --arg t "$TAB" \
      '[.result.panes[] | select(.tab_id == $t)][0].pane_id') || return 1
}

# Up to 90s: herdr's cold start competes with the rest of autostart.lua at session start.
for _ in $(seq 1 90); do
  if find_emerge_pane; then
    "$HERDR" pane run "$PANE" "$cmd"
    if [ "$background" = 1 ]; then
      back
    else
      "$HERDR" workspace focus "$WS" >/dev/null
      "$HERDR" tab focus "$TAB" >/dev/null
    fi
    exit 0
  fi
  sleep 1
done

back
echo "herdr-emerge-run.sh: herdr workspace '$GENTOO_LABEL' / tab '$EMERGE_TAB_LABEL' never appeared, giving up" >&2
exit 1
