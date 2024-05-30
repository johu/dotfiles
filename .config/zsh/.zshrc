# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.config/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme

# to customize prompt, run `p10k configure` or edit p10k.zsh.
[[ ! -f ~/.config/zsh/themes/p10k.zsh ]] || source ~/.config/zsh/themes/p10k.zsh

# plugins
[[ -s "/usr/share/zsh/site-functions/zsh-autosuggestions.zsh" ]] && source "/usr/share/zsh/site-functions/zsh-autosuggestions.zsh"
[[ -s "/usr/share/zsh/site-functions/zsh-syntax-highlighting.zsh" ]] && source "/usr/share/zsh/site-functions/zsh-syntax-highlighting.zsh"

# load completions
autoload -U compinit && compinit

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

# alias
alias zsh-reload="source ~/.config/zsh/.zshrc"
alias zsh-edit="nvim ~/.config/zsh/.zshrc"
eval $(thefuck --alias)
eval $(thefuck --alias fk)
# eval $(zoxide init zsh)
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias cfg='config'
alias diff="colordiff"
alias cat="bat"
alias ls="eza --icons=always --group-directories-first"
alias vim="nvim"
# alias cd="z"
alias nvidia-settings="nvidia-settings --config=~/.config/nvidia/settings"

# set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

