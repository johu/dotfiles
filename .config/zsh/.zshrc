# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
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
zinit light Aloxaf/fzf-tab
zinit ice depth=1;zinit light romkatv/powerlevel10k
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

# to customize prompt, run `p10k configure` or edit p10k.zsh.
[[ ! -f ~/.config/zsh/themes/p10k.zsh ]] || source ~/.config/zsh/themes/p10k.zsh

# keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

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
alias config='dotbare'
alias cfg='config'
alias diff="colordiff"
alias cat="bat"
alias ls="eza --icons=always --group-directories-first"
alias ll="ls -l"
alias la="ls -la"
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
