#!/bin/bash
# Install the tracked TokyoNight Moon KDE color scheme and apply it to
# kdeglobals. Safe to re-run: does nothing when already up to date.

name=TokyoNightMoon
src="$HOME/.config/hypr/colors/tokyonight-moon.colors"
dst="$HOME/.local/share/color-schemes/$name.colors"

[ -f "$src" ] || exit 1
command -v plasma-apply-colorscheme >/dev/null || exit 0

if ! cmp -s "$src" "$dst" || ! grep -qx "ColorScheme=$name" "$HOME/.config/kdeglobals" 2>/dev/null; then
  mkdir -p "${dst%/*}"
  cp "$src" "$dst"
  plasma-apply-colorscheme "$name"
fi
