local mod = require('globals').mod
local terminal = require('globals').terminal
local file_manager = require('globals').file_manager

hl.bind(mod .. ' + Return', hl.dsp.exec_cmd(terminal .. ' +new-window'), { desc = 'Terminal' })
hl.bind(mod .. ' + W', hl.dsp.window.close(), { desc = 'Close window' })
hl.bind(mod .. ' + Q', hl.dsp.exec_cmd 'wlogout')
hl.bind(mod .. ' + E', hl.dsp.exec_cmd(file_manager))
hl.bind(mod .. ' + Y', hl.dsp.window.float { action = 'toggle' }, { desc = 'Toggle window floating/tiling' })
hl.bind(mod .. ' + F', hl.dsp.window.fullscreen { mode = 'fullscreen' }, { desc = 'Fullscreen' })
hl.bind(mod .. ' + SPACE', hl.dsp.exec_cmd 'qs -p ~/.config/quickshell ipc call launcher toggle', { desc = 'Application launcher' })
-- bind = $mainMod, P, pseudo, # dwindle
hl.bind(mod .. ' + T', hl.dsp.layout 'togglesplit') -- dwindle only
hl.bind(mod .. ' + F1', hl.dsp.exec_cmd '~/.config/hypr/scripts/keybinds.sh', { desc = 'Show keybinds' })
hl.bind('CTRL + ALT + L', hl.dsp.exec_cmd 'hyprlock', { desc = 'Lock screen' })
hl.bind('PRINT', hl.dsp.exec_cmd 'hyprshot -m window', { desc = 'Screenshot' })
hl.bind(mod .. ' + PRINT', hl.dsp.exec_cmd 'hyprshot -m window', { desc = 'Screenshot window' })
hl.bind('PRINT', hl.dsp.exec_cmd 'hyprshot -m output', { desc = 'Screenshot' })
hl.bind(mod .. ' + SHIFT + S', hl.dsp.exec_cmd 'hyprshot -m output', { desc = 'Screenshot' })
hl.bind(mod .. ' + S', hl.dsp.exec_cmd 'hyprshot -m region', { desc = 'Screenshot region' })
hl.bind(mod .. ' + V', hl.dsp.exec_cmd '~/.config/hypr/scripts/clipboard.sh', { desc = 'Clipboard' })
hl.bind(mod .. ' + B', hl.dsp.exec_cmd 'killall -SIGUSR1 waybar', { desc = 'Toggle waybar' })

-- D2R run counter
hl.bind(mod .. ' + F9', hl.dsp.exec_cmd '~/.config/hypr/scripts/d2runs.sh inc', { desc = 'D2R: log run' })
hl.bind(mod .. ' + SHIFT + F9', hl.dsp.exec_cmd '~/.config/hypr/scripts/d2runs.sh dec', { desc = 'D2R: undo run' })

-- # media keys
hl.bind('XF86MonBrightnessUp', hl.dsp.exec_cmd '~/.config/hypr/scripts/brightness.sh up', { desc = 'Brightness up' })
hl.bind('XF86MonBrightnessDown', hl.dsp.exec_cmd '~/.config/hypr/scripts/brightness.sh down', { desc = 'Brightness down' })
hl.bind('XF86AudioRaiseVolume', hl.dsp.exec_cmd 'pactl set-sink-volume @DEFAULT_SINK@ +5%', { desc = 'Raise volume' })
hl.bind('XF86AudioLowerVolume', hl.dsp.exec_cmd 'pactl set-sink-volume @DEFAULT_SINK@ -5%', { desc = 'Lower volume' })
hl.bind('XF86AudioMute', hl.dsp.exec_cmd 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle', { desc = 'Mute' })
hl.bind('XF86AudioPlay', hl.dsp.exec_cmd 'playerctl play-pause', { desc = 'Play' })
hl.bind('XF86AudioPause', hl.dsp.exec_cmd 'playerctl plause', { desc = 'Pause' })
hl.bind('XF86AudioNext', hl.dsp.exec_cmd 'playerctl next', { desc = 'Next' })
hl.bind('XF86AudioPrev', hl.dsp.exec_cmd 'playerctl previous', { desc = 'Previous' })
hl.bind('XF86AudioMicMute', hl.dsp.exec_cmd 'playerctl previous', { desc = 'Previous' })
-- hl.bind('XF86Lock', hl.dsp.exec_cmd 'hyprlock', { desc = 'Lock screen' })

-- Move focus with mod + vim keys
hl.bind(mod .. ' + h', hl.dsp.focus { direction = 'left' })
hl.bind(mod .. ' + j', hl.dsp.focus { direction = 'down' })
hl.bind(mod .. ' + k', hl.dsp.focus { direction = 'up' })
hl.bind(mod .. ' + l', hl.dsp.focus { direction = 'right' })

-- Move window with mod + SHIFT + vim keys
hl.bind(mod .. ' + SHIFT + h', hl.dsp.window.move { direction = 'left' })
hl.bind(mod .. ' + SHIFT + j', hl.dsp.window.move { direction = 'down' })
hl.bind(mod .. ' + SHIFT + k', hl.dsp.window.move { direction = 'up' })
hl.bind(mod .. ' + SHIFT + l', hl.dsp.window.move { direction = 'right' })

-- Switch workspaces with mod + [0-9]
-- Move active window to a workspace with mod + SHIFT + [0-9]
for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mod .. ' + ' .. key, hl.dsp.focus { workspace = i })
  hl.bind(mod .. ' + SHIFT + ' .. key, hl.dsp.window.move { workspace = i })
end

-- Example special workspace (scratchpad)
-- hl.bind(mod .. ' + S', hl.dsp.workspace.toggle_special 'magic')
-- hl.bind(mod .. ' + SHIFT + S', hl.dsp.window.move { workspace = 'special:magic' })

-- # Scroll through existing workspaces with mod + scroll
hl.bind(mod .. ' + mouse_down', hl.dsp.focus { workspace = 'e+1' })
hl.bind(mod .. ' + mouse_up', hl.dsp.focus { workspace = 'e-1' })

-- Move/resize windows with mod + LMB/RMB and dragging
hl.bind(mod .. ' + mouse:272', hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. ' + mouse:273', hl.dsp.window.resize(), { mouse = true })

-- Minimize windows using special workspaces
hl.bind(mod .. ' + x', function()
  if hl.get_workspace 'special:minimized' then
    hl.dispatch(hl.dsp.window.move { workspace = hl.get_active_workspace(), window = 'tag:minimized' })
    hl.dispatch(hl.dsp.window.clear_tags { window = 'tag:minimized' })
  else
    hl.dispatch(hl.dsp.window.tag { tag = 'minimized', window = hl.get_active_window() })
    hl.dispatch(hl.dsp.window.move { workspace = 'special:minimized', follow = false })
  end
end)

-- Global keybinds
hl.bind('SUPER + F10', hl.dsp.pass { window = 'class:^(discord)$' })

-- Game mode
-- Seed from the cache file so game_mode survives a `hyprctl reload`
-- (which re-executes this file) instead of always starting false.
local gamemode_cache_path = os.getenv 'HOME' .. '/.cache/gamemode'

local function gamemode_cache_exists()
  local f = io.open(gamemode_cache_path, 'r')
  if f then
    f:close()
    return true
  end
  return false
end

local game_mode = gamemode_cache_exists()

local function enable_game_mode()
  if game_mode then
    return
  end

  game_mode = true
  local f = io.open(gamemode_cache_path, 'w')
  if f then
    f:close()
  end
  hl.notification.create { text = 'Gamemode enabled', timeout = 2000, color = 'rgba(9ece6aee)' }

  hl.config {
    general = {
      gaps_in = 0,
      gaps_out = 0,
      border_size = 1,
    },

    decoration = {
      rounding = 0,
      shadow = { enabled = false },
      blur = { enabled = false },
    },

    animations = {
      enabled = false,
    },
  }
end

local function disable_game_mode()
  if not game_mode then
    return
  end

  game_mode = false
  os.remove(gamemode_cache_path)
  hl.notification.create { text = 'Gamemode disabled', timeout = 2000, color = 'rgba(f7768eee)' }
  hl.exec_cmd 'hyprctl reload'
end

local function toggle_game_mode()
  if game_mode then
    disable_game_mode()
  else
    enable_game_mode()
  end
end

hl.bind('SUPER + F2', toggle_game_mode, { desc = 'Gamemode' })

-- Automatically enable game mode while a Steam game is running, and
-- disable it again once the last one closes. steam_app_<appid> is the
-- class Steam assigns to a game's window.
local function is_steam_game(class)
  return class ~= nil and class:match '^steam_app_%d+$' ~= nil
end

local function any_steam_game_running()
  for _, w in ipairs(hl.get_windows()) do
    if is_steam_game(w.class) then
      return true
    end
  end
  return false
end

hl.on('window.open', function(w)
  if w and is_steam_game(w.class) then
    enable_game_mode()
  end
end)

-- w is always nil here on Hyprland 0.56.2; use the event only as a
-- "something closed" trigger and re-check the live window list.
hl.on('window.destroy', function()
  if game_mode and not any_steam_game_running() then
    disable_game_mode()
  end
end)
