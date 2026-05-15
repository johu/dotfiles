local main = require('globals').main_monitor
local second = require('globals').second_monitor
local terminal = require('globals').terminal
local browser = require('globals').browser

hl.workspace_rule { workspace = '1', monitor = main, default = true, on_created_empty = terminal .. ' -e tmux new-session -A -s gentoo +new-window' }
hl.workspace_rule { workspace = '2', monitor = main, on_created_empty = browser }
hl.workspace_rule { workspace = '3', monitor = main }
hl.workspace_rule { workspace = '4', monitor = main }
hl.workspace_rule { workspace = '5', monitor = main }
hl.workspace_rule { workspace = '6', monitor = second }
hl.workspace_rule { workspace = '7', monitor = second }
hl.workspace_rule { workspace = '8', monitor = second }
hl.workspace_rule { workspace = '9', monitor = second }
