local mod = require('globals').mod
local terminal = require('globals').terminal
local file_manager = require('globals').file_manager

hl.bind(mod .. ' + Return', hl.dsp.exec_cmd(terminal .. ' +new-window'), { desc = 'Terminal' })
hl.bind(mod .. ' + W', hl.dsp.window.close(), { desc = 'Close window' })
hl.bind(mod .. ' + Q', hl.dsp.exec_cmd 'wlogout')
hl.bind(mod .. ' + E', hl.dsp.exec_cmd(file_manager))
hl.bind(mod .. ' + Y', hl.dsp.window.float { action = 'toggle' }, { desc = 'Toggle window floating/tiling' })
hl.bind(mod .. ' + F', hl.dsp.window.fullscreen { mode = 'fullscreen' }, { desc = 'Fullscreen' })
hl.bind(mod .. ' + SPACE', hl.dsp.exec_cmd 'rofi -show drun -replace -i', { desc = 'Application launcher' })
-- bind = $mainMod, P, pseudo, # dwindle
hl.bind(mod .. ' + T', hl.dsp.layout 'togglesplit') -- dwindle only
hl.bind(mod .. ' + F1', hl.dsp.exec_cmd '~/.config/hypr/scripts/keybinds.sh', { desc = 'Show keybinds' })
hl.bind('CTRL + ALT + G', hl.dsp.exec_cmd '~/.config/hypr/scripts/gamemode.sh', { desc = 'Gamemode' })
hl.bind('CTRL + ALT + L', hl.dsp.exec_cmd 'hyprlock', { desc = 'Lock screen' })
hl.bind('PRINT', hl.dsp.exec_cmd 'hyprshot -m window', { desc = 'Screenshot' })
hl.bind(mod .. ' + PRINT', hl.dsp.exec_cmd 'hyprshot -m window', { desc = 'Screenshot window' })
hl.bind('PRINT', hl.dsp.exec_cmd 'hyprshot -m output', { desc = 'Screenshot' })
hl.bind(mod .. ' + SHIFT + S', hl.dsp.exec_cmd 'hyprshot -m output', { desc = 'Screenshot' })
hl.bind(mod .. ' + S', hl.dsp.exec_cmd 'hyprshot -m region', { desc = 'Screenshot region' })
hl.bind(mod .. ' + V', hl.dsp.exec_cmd '~/.config/hypr/scripts/clipboard.sh', { desc = 'Clipboard' })
hl.bind(mod .. ' + B', hl.dsp.exec_cmd 'killall -SIGUSR1 waybar', { desc = 'Toggle waybar' })

-- # media keys
hl.bind('XF86MonBrightnessUp', hl.dsp.exec_cmd 'brightnessctl -q s +10%', { desc = 'Brightness up' })
hl.bind('XF86MonBrightnessDown', hl.dsp.exec_cmd 'brightnessctl -q s 10%-', { desc = 'Brightness down' })
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
