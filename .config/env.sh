#!/bin/sh

# extend path
export PATH=$HOME/bin:$HOME/.config/tmux/plugins/tmuxifier/bin:/usr/local/bin:$PATH

# xdg settings
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# default programs
export EDITOR="nvim"
export TERMINAL="alacritty"
export BROWSER="firefox"

# java
export JAVA_HOME=/opt/openjdk-bin-11
export ANT_RESPECT_JAVA_HOME=y
export _JAVA_AWT_WM_NONREPARENTING=1

# ~ cleanup
export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority" # this will break some dms
export LESSHISTFILE="-"
export ZDOTDIR="$HOME/.config/zsh"
export GNUPGHOME="$HOME/.config/gnupg"
export PASSWORD_STORE_DIR="$HOME/.local/share/password-store"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/gtkrc-2.0"
export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java
