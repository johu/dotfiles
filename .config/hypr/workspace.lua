local main = require('globals').main_monitor
local second = require('globals').second_monitor
local terminal = require('globals').terminal
local browser = require('globals').browser

hl.workspace_rule { workspace = '1', monitor = main, default = true }
hl.workspace_rule { workspace = '2', monitor = main }
hl.workspace_rule { workspace = '3', monitor = main }
hl.workspace_rule { workspace = '4', monitor = main }
hl.workspace_rule { workspace = '5', monitor = main }
hl.workspace_rule { workspace = '6', monitor = second }
hl.workspace_rule { workspace = '7', monitor = second }
hl.workspace_rule { workspace = '8', monitor = second }
hl.workspace_rule { workspace = '9', monitor = second }

local on_created_empty = {
  ['1'] = terminal .. ' -e zsh -c herdr',
  ['2'] = browser,
}

hl.on('workspace.created', function(ws)
  if ws.is_empty and on_created_empty[ws.name] then
    hl.exec_cmd(on_created_empty[ws.name])
  end
end)
