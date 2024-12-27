#!/bin/sh

# lang
export LANG=en_US.UTF-8

# xdg settings
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# default programs
export EDITOR="nvim"
export TERMINAL="ghostty"
export BROWSER="firefox"

# dotfile management
export DOTBARE_DIR="$HOME/.cfg"
export DOTBARE_TREE="$HOME"

# flatpak
export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$XDG_DATA_HOME/flatpak/exports/share"

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
export WGETRC="$XDG_CONFIG_HOME/wgetrc"
export ICEAUTHORITY="$XDG_CACHE_HOME"/ICEauthority
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java
export GOPATH="$XDG_DATA_HOME"/go
export GOMODCACHE="$XDG_CACHE_HOME"/go/mod
export MYSQL_HISTFILE="$XDG_DATA_HOME"/mysql_history
export CUDA_CACHE_PATH="$XDG_CACHE_HOME"/nv
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config
export NPM_CONFIG_USERCONFIG=$XDG_CONFIG_HOME/npm/npmrc
