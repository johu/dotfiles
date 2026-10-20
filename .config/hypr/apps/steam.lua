hl.window_rule { match = { class = 'steam' }, float = true }
hl.window_rule { match = { class = 'steam', title = 'Steam' }, center = true }
hl.window_rule { match = { class = 'steam.*' }, tag = '-default-opacity' }
hl.window_rule { match = { class = 'steam.*' }, opacity = '1 1' }
hl.window_rule { match = { class = 'steam', title = 'Steam' }, size = { 1100, 700 } }
hl.window_rule { match = { class = 'steam', title = 'Friends List' }, size = { 460, 800 } }
hl.window_rule { match = { class = 'steam' }, idle_inhibit = 'fullscreen' }

-- Keep Steam games off the same workspace as the Steam client itself.
-- Hyprland has an open upstream bug (hyprwm/Hyprland#7155) where an
-- XWayland game can lose keyboard focus after another XWayland window
-- (Steam) shares its workspace; separating them avoids triggering it.
hl.window_rule { match = { class = 'steam_app_.*' }, workspace = '5' }
