# install oh my posh if it doesn't exist
BIN_DIR="${XDG_BIN_HOME:-$HOME:/.local/bin}"
if [[ ! -e "${BIN_DIR}/oh-my-posh" ]]; then
  mkdir -p "${BIN_DIR}"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ${BIN_DIR} >/dev/null
fi

# download plugin manager if it doesn't exist
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# init plugin manager
source "${ZINIT_HOME}/zinit.zsh"

# plugins
zinit light jeffreytse/zsh-vi-mode
zinit light Aloxaf/fzf-tab
zinit light kazhala/dotbare
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zpm-zsh/colors
zinit light zpm-zsh/colorize

# snippets
zinit snippet OMZP::gpg-agent
zinit snippet OMZP::sudo

# load completions
autoload -Uz compinit && compinit

# load oh my posh
eval "$(oh-my-posh -c $XDG_CONFIG_HOME/ohmyposh/config.toml init zsh)"

# keybindings
bindkey -v

# history setup
HISTFILE=$HOME/.config/zsh/.zhistory
HISTSIZE=5000
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# completion style
zstyle ':completion:*:git-checkout:*' sort false
# zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group '<' '>'
# zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

# aliases
alias zsh-reload="source ~/.config/zsh/.zshrc"
alias zsh-edit="nvim ~/.config/zsh/.zshrc"
alias sudo='sudo '
alias config='dotbare'
alias cfg='config'
alias diff="colordiff"
alias cat="bat"
alias ls="eza --icons=always --group-directories-first"
alias ll="ls -l"
alias la="ls -la"
alias nvim-kickstart='NVIM_APPNAME=nvim-kickstart nvim'
alias nvim-lazy='NVIM_APPNAME=nvim-lazy nvim'
alias vim="nvim"
alias nvidia-settings="nvidia-settings --config=~/.config/nvidia/settings"
alias wget="wget --hsts-file=$XDG_CACHE_HOME/wget-hsts"

# shell integrations
eval $(tmuxifier init -)
eval $(thefuck --alias)
eval $(thefuck --alias fk)
eval $(fzf --zsh)
eval "$(zoxide init --cmd cd zsh)"

source ~/.config/zsh/plugins/fzf.plugin.zsh
