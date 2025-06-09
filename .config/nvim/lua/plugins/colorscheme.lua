return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    opts = { style = 'moon' },
    config = function()
      require('tokyonight').setup {}
      vim.cmd.colorscheme 'tokyonight'
    end,
  },
  {
    'catppuccin/nvim',
    enabled = false,
    name = 'catppuccin',
    lazy = true,
    otps = {
      flavour = 'mocha',
      transparent_background = true,
      integrations = {
        blink_cmp = true,
        cmp = false,
        dap = true,
        dap_ui = true,
        dashboard = true,
        fzf = true,
        grug_far = true,
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
    },
  },
  -- color scheme chooser
  {
    'zaldih/themery.nvim',
    enabled = false,
    lazy = false,
    config = function()
      require('themery').setup {
        themes = { 'catppuccin', 'tokyonight' },
        livePreview = true,
      }
    end,
  },
}
