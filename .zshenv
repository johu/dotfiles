#!/bin/sh

[ -f "$HOME/.config/env.sh" ] && source "${HOME}/.config/env.sh"
[ -f "$HOME/.config/env.work.sh" ] && source "${HOME}/.config/env.work.sh"

# ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi
