#!/bin/bash
# Restarts quickshell whenever a real monitor (re)appears.
#
# When a monitor goes idle (DPMS off, or the display itself powers down and
# drops signal), Hyprland can remove all real outputs and briefly run on a
# headless "FALLBACK" monitor. Quickshell survives this but its bar windows
# stay bound to the vanished outputs and never reattach when the real
# monitor comes back, leaving a dead process with no visible bar. Restarting
# quickshell on the next real monitoraddedv2 event fixes it without relying
# on quickshell exiting (which never happens, so systemd's Restart= alone
# can't catch this).
set -euo pipefail

SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
last_restart=0

socat -u UNIX-CONNECT:"$SOCK" - | while IFS= read -r line; do
  case "$line" in
    monitoraddedv2\>\>*,FALLBACK,*) continue ;;
    monitoraddedv2\>\>*)
      now=$(date +%s)
      if (( now - last_restart >= 2 )); then
        last_restart=$now
        systemctl --user restart quickshell.service
      fi
      ;;
  esac
done
