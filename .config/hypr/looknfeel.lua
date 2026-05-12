local active_border_color = require('globals').active_border_color
local inactive_border_color = require('globals').inactive_border_color
local blend_color = require('globals').blend_color
local shadow_color = require('globals').shadow_color

hl.animation { leaf = 'global', enabled = false }

hl.config {
  general = {
    gaps_in = 5,
    gaps_out = 5,
    border_size = 2,

    col = {
      active_border = { colors = { active_border_color, blend_color }, angle = 45 },
      inactive_border = inactive_border_color,
    },

    resize_on_border = false,
    allow_tearing = false,
    layout = 'dwindle',
  },

  decoration = {
    rounding = 8,
    rounding_power = 2,

    active_opacity = 1.0,
    inactive_opacity = 1.0,

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = shadow_color,
    },

    blur = {
      enabled = true,
      size = 3,
      passes = 1,
      vibrancy = 0.1696,
    },
  },

  animations = {
    enabled = false,
  },

  dwindle = {
    preserve_split = true,
  },

  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
    vrr = 1,
  },
}
