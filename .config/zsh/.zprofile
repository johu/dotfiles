# prepend path if ~/.local/bin and ~/bin to $PATH unless it is already there
if ! [[ "$PATH" =~ "$HOME/bin" ]]; then
  PATH="$HOME/bin:$PATH"
fi
if ! [[ "$PATH" =~ "$HOME/.local/bin" ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi
# prepend path with custom binary locations
if ! [[ "$PATH" =~ "$HOME/.config/tmux/plugins/tmuxifier/bin" ]]; then
  PATH="$HOME/.config/tmux/plugins/tmuxifier/bin/:$PATH"
fi

export PATH
