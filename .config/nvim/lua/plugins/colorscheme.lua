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
          blink_cmp = true,
          cmp = false,
          dap = true,
          dap_ui = true,
          dashboard = true,
          fzf = true,
          harpoon = true,
          indent_blankline = { enabled = true },
          lsp_trouble = true,
          markdown = true,
          mason = true,
          mini = true,
          native_lsp = {
            enabled = true,
            underlines = {
              errors = { 'undercurl' },
              hints = { 'undercurl' },
              warnings = { 'undercurl' },
              information = { 'undercurl' },
            },
          },
          noice = true,
          notify = true,
          snacks = true,
          telescope = false,
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
      'echasnovski/mini.icons',
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
