#!/bin/sh
if [ -z "$__ENV_SH_SOURCED" ]; then
  [ -f "$HOME/.config/env.sh" ] && source "${HOME}/.config/env.sh"
  [ -f "$HOME/.config/env.private.sh" ] && source "${HOME}/.config/env.private.sh"
  export __ENV_SH_SOURCED=1
fi

if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi
