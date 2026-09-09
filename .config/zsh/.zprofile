# prepend path entries once
typeset -U path PATH
path=(
  "$HOME/.config/tmux/plugins/tmuxifier/bin"
  "$HOME/.local/bin"
  "$HOME/bin"
  $path
)
export PATH
