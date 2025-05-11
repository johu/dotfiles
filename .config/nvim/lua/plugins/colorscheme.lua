return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup {
        flavour = 'mocha',
        transparent_background = true,
        integrations = {
          alpha = true,
          cmp = true,
          dap = true,
          dap_ui = true,
          fzf = true,
          indent_blankline = true,
          markdown = true,
          mason = true,
          notify = true,
          treesitter = true,
          treesitter_context = true,
          which_key = true,
        },
      }

      -- vim.cmd.colorscheme 'catppuccin'
    end,
  },
  {
    'folke/tokyonight.nvim',
    lazy = false,
    opts = { style = 'moon' },
    config = function()
      -- vim.cmd.colorscheme 'tokyonight'
    end,
  },
  -- color scheme chooser
  {
    'zaldih/themery.nvim',
    lazy = false,
    config = function()
      require('themery').setup {
        themes = { 'catppuccin', 'tokyonight' },
        livePreview = true,
      }
    end,
  },
  -- TODO: adjust color based on selected theme?
  -- INFO: hard coded theme catppuccin
  {
    'rachartier/tiny-devicons-auto-colors.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    event = 'VeryLazy',
    config = function()
      local theme_colors = require('catppuccin.palettes').get_palette 'macchiato'
      require('tiny-devicons-auto-colors').setup {
        colors = theme_colors,
      }
    end,
  },
}
