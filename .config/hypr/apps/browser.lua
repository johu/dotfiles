-- Browser types
hl.window_rule { match = { class = '((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)' }, tag = '+chromium-based-browser' }
hl.window_rule { match = { class = '([fF]irefox|zen|librewolf)' }, tag = '+firefox-based-browser' }
-- Force chromium-based browsers into a tile to deal with --app bug
hl.window_rule { match = { tag = 'chromium-based-browser' }, tile = true }

-- Hide the screen-sharing notification bar (the "Hide" button on it is broken on Wayland)
hl.window_rule { match = { title = '.*is sharing.*' }, workspace = 'special silent' }
