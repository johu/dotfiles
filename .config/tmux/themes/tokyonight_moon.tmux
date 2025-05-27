#!/usr/bin/env bash

set -g mode-style "fg=#82aaff,bg=#3b4261"

set -g message-style "fg=#82aaff,bg=#3b4261"
set -g message-command-style "fg=#82aaff,bg=#3b4261"

set -g pane-border-style "fg=#3b4261"
set -g pane-active-border-style "fg=#82aaff"

set -g status "on"
set -g status-justify "left"

set -g status-style "fg=#82aaff,bg=#222336"

set -g status-left-length "100"
set -g status-right-length "100"

set -g status-left-style NONE
set -g status-right-style NONE

set -g status-left ""
set -g status-right "#[fg=#222336,bg=#222336,nobold,nounderscore,noitalics]#[fg=#82aaff,bg=#222336] #{prefix_highlight} #[fg=#82aaff,bg=#222336,nobold,nounderscore,noitalics]#[fg=#1b1d2b,bg=#82aaff,bold]#S#[fg=#82aaff,bg=#222336,nobold,nounderscore,noitalics]#[fg=#222336,bg=#222336,nobold,nounderscore,noitalics] "

setw -g window-status-activity-style "underscore,fg=#828bb8,bg=#222336"
setw -g window-status-separator ""
setw -g window-status-style "NONE,fg=#828bb8,bg=#222336"
setw -g window-status-format " #[fg=#3b4261,bg=#222336,nobold,nounderscore,noitalics]#[fg=#222336,bg=#3b4261,nobold,nounderscore,noitalics]#[fg=#82aaff,bg=#3b4261,bold]#W █#[fg=#3b4261,bg=#82aaff,bold]#I#[fg=#82aaff,bg=#222336,nobold,nounderscore,noitalics]"
setw -g window-status-current-format " #[fg=#3b4261,bg=#222336,nobold,nounderscore,noitalics]#[fg=#222336,bg=#3b4261,nobold,nounderscore,noitalics]#[fg=#82aaff,bg=#3b4261,bold]#W #[fg=#ff9e64,bg=#222336,nobold,nounderscore,noitalics]█#[fg=#3b4261,bg=#ff9e64,bold]#I#[fg=#ff9e64,bg=#222336,nobold,nounderscore,noitalics]"

# tmux-plugins/tmux-prefix-highlight support
set -g @prefix_highlight_output_prefix "#[fg=#ffc777]#[bg=#222336]#[fg=#222336]#[bg=#ffc777]"
set -g @prefix_highlight_output_suffix "#[fg=#ffc777]#[bg=#222336] "
