#!/bin/bash
# Validate the Hyprland + uwsm session setup.
#
#   validate-session.sh static    offline checks (config/units/env files)
#   validate-session.sh runtime   checks of the live, uwsm-managed session
#   validate-session.sh           both
#
# Exit status is the number of failed checks.

fails=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
check() { # check "<description>" <command...>
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}

HYPR=$HOME/.config/hypr
UWSM=$HOME/.config/uwsm
UNITS=$HOME/.config/systemd/user

static() {
  echo "== static: uwsm installation"
  check "uwsm is installed" command -v uwsm
  check "hyprland-uwsm.desktop session entry exists" \
    test -f /usr/share/wayland-sessions/hyprland-uwsm.desktop
  check "hyprland.desktop (uwsm target) exists" \
    test -f /usr/share/wayland-sessions/hyprland.desktop

  echo "== static: uwsm env files"
  local f out
  for f in "$UWSM"/env "$UWSM"/env-hyprland; do
    [ -f "$f" ] || { fail "$f missing"; continue; }
    check "$(basename "$f"): bash syntax is valid" bash -n "$f"
    # Sourcing must not execute stray commands or print anything.
    out=$(env -i HOME="$HOME" PATH="$PATH" bash -c ". '$f'" 2>&1)
    if [ -z "$out" ]; then pass "$(basename "$f"): sources silently"
    else fail "$(basename "$f"): sourcing printed: $out"; fi
  done
  # Values must come out as intended (catches unquoted ';' and stray chars).
  out=$(env -i HOME="$HOME" PATH="$PATH" bash -c \
    ". '$UWSM/env' 2>/dev/null; printf '%s|%s|%s' \"\$QT_QPA_PLATFORM\" \"\$GDK_SCALE\" \"\$GDK_BACKEND\"")
  [ "$out" = "wayland;xcb|1|wayland,x11,*" ] \
    && pass "env: QT_QPA_PLATFORM/GDK_SCALE/GDK_BACKEND have intended values" \
    || fail "env: unexpected QT_QPA_PLATFORM|GDK_SCALE|GDK_BACKEND = '$out'"

  local a b
  a=$(sed -n "s/^export QT_QPA_PLATFORMTHEME=//p" "$UWSM/env")
  b=$(sed -n "s/.*hl.env('QT_QPA_PLATFORMTHEME', '\\([^']*\\)').*/\\1/p" "$HYPR/env.lua")
  [ -n "$a" ] && [ "$a" = "$b" ] && pass "QT_QPA_PLATFORMTHEME consistent (uwsm/env = env.lua = $a)" \
    || fail "QT_QPA_PLATFORMTHEME differs: uwsm/env='$a' env.lua='$b'"

  echo "== static: Hyprland config"
  if command -v Hyprland >/dev/null; then
    out=$(Hyprland --verify-config -c "$HYPR/hyprland.lua" 2>&1)
    if echo "$out" | grep -qiE 'error|fail|invalid' ; then
      fail "Hyprland --verify-config: $(echo "$out" | grep -iE 'error|fail|invalid' | head -3)"
    else pass "Hyprland --verify-config"; fi
  fi
  if grep -qE 'dbus-update-activation-environment|systemctl --user import-environment' "$HYPR/autostart.lua"; then
    fail "autostart.lua still exports env manually (uwsm does this; redundant and races)"
  else pass "autostart.lua has no manual environment export"
  fi
  # Long-running daemons belong in systemd units, not exec_cmd (no restart,
  # no cgroup, can't be checked). One-shot scripts in autostart are fine.
  if grep -qE "exec_cmd '(nm-applet|hyprpaper|hypridle|wl-paste --watch)" "$HYPR/autostart.lua"; then
    fail "autostart.lua launches daemons directly; use systemd units"
  else pass "autostart.lua launches no long-running daemons directly"
  fi
  for u in nm-applet cliphist hypridle hyprpaper xwaylandvideobridge; do
    check "$u.service enabled" systemctl --user is-enabled "$u.service"
  done

  echo "== static: systemd units"
  local u
  for u in "$UNITS"/*.service "$UNITS"/*.timer; do
    [ -f "$u" ] || continue
    out=$(systemd-analyze --user verify "$u" 2>&1)
    [ -z "$out" ] && pass "verify $(basename "$u")" \
      || fail "verify $(basename "$u"): $(echo "$out" | head -2 | tr '\n' ' ')"
  done
  check "hyprsunset.service enabled" systemctl --user is-enabled hyprsunset.service
  for u in quickshell.service quickshell-watchdog.service; do
    if grep -q '^PartOf=graphical-session.target' "$UNITS/$u" \
       && grep -q '^After=graphical-session.target' "$UNITS/$u"; then
      pass "$u bound to graphical-session.target (PartOf+After)"
    else fail "$u lacks PartOf=/After=graphical-session.target"; fi
  done
  check "portage-sync.sh: bash syntax valid" bash -n "$HYPR/scripts/portage-sync.sh"
  check "portage-sync.sh: re-run guard present (stamp + interval)" \
    grep -q 'MIN_INTERVAL' "$HYPR/scripts/portage-sync.sh"
  local tmp; tmp=$(mktemp -d); touch "$tmp/portage-sync.stamp"
  check "portage-sync.sh: skips when last sync is recent" bash -c \
    "XDG_CACHE_HOME='$tmp' PATH=/usr/bin:/bin '$HYPR/scripts/portage-sync.sh' 2>&1 | grep -q 'skipping'"
  rm -rf "$tmp"
  check "hyprsunset.conf parses (profiles present)" grep -q '^profile' "$HYPR/hyprsunset.conf"
}

runtime() {
  echo "== runtime: uwsm session"
  check "session started by uwsm (wayland-wm@hyprland.desktop unit active)" \
    systemctl --user is-active --quiet wayland-wm@hyprland.desktop.service
  check "uwsm reports a running compositor" uwsm check is-active
  check "graphical-session.target active" \
    systemctl --user is-active --quiet graphical-session.target

  echo "== runtime: environment in systemd user manager"
  local v env
  env=$(systemctl --user show-environment)
  for v in WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE \
           XCURSOR_THEME QT_QPA_PLATFORMTHEME HYPRCURSOR_THEME; do
    grep -q "^$v=" <<<"$env" && pass "$v present" || fail "$v missing"
  done
  # systemd prints values containing ';' in $'...' quoting
  grep -qE "^QT_QPA_PLATFORM=(\\\$')?wayland;xcb'?$" <<<"$env" \
    && pass "QT_QPA_PLATFORM=wayland;xcb" || fail "QT_QPA_PLATFORM wrong/missing"

  echo "== runtime: services"
  local s
  for s in hyprsunset hyprpolkitagent nm-applet cliphist hypridle hyprpaper xwaylandvideobridge quickshell quickshell-watchdog pipewire wireplumber; do
    check "$s.service active" systemctl --user is-active --quiet "$s.service"
  done
  # take the signature from the systemd manager so a stale shell env can't mislead
  local sig
  sig=$(systemctl --user show-environment | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')
  check "hyprsunset answers on its socket" \
    env HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl hyprsunset temperature
  check "videobridge tray icon is filtered in Tray.qml" \
    grep -q 'Xwayland Video Bridge' "$HOME/.config/quickshell/modules/Tray.qml"
  check "no conflicting second polkit agent running" \
    bash -c '! pgrep -f "^/usr/libexec/polkit-gnome" >/dev/null'
  # XDG autostart units that must stay masked (the generator ignores
  # Hidden=true overrides, so they are masked in ~/.config/systemd/user).
  local m
  for m in 'polkit\x2dgnome\x2dauthentication\x2dagent\x2d1' 'geoclue\x2ddemo\x2dagent' \
           com.mitchellh.ghostty org.kde.xwaylandvideobridge 'nm\x2dapplet'; do
    [ "$(systemctl --user is-enabled "app-${m}@autostart.service" 2>&1)" = masked ] \
      && pass "autostart app-${m} masked" || fail "autostart app-${m} not masked"
    check "autostart app-${m} not running" \
      bash -c "! systemctl --user is-active --quiet 'app-${m}@autostart.service'"
  done
  for m in nm-applet hyprpaper hypridle xwaylandvideobridge; do
    check "exactly one $m process" bash -c "[ \"\$(pgrep -fc \"^/usr/bin/$m( |\$)\")\" -eq 1 ]"
  done
  check "exactly one ghostty window-daemon (no autostart duplicate)" bash -c \
    '[ "$(pgrep -fc "^ghostty --gtk-single-instance")" -eq 1 ]' 
  check "no failed user units" bash -c \
    '[ -z "$(systemctl --user --failed --no-legend)" ]'
  check "portage-sync.timer active" systemctl --user is-active --quiet portage-sync.timer
}

case "${1:-all}" in
  static)  static ;;
  runtime) runtime ;;
  all)     static; runtime ;;
  *) echo "usage: $0 [static|runtime]" >&2; exit 2 ;;
esac

echo
[ "$fails" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$fails CHECK(S) FAILED"
exit "$fails"
