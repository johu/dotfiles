return {
  -- neovim configuration file support
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      {
        'folke/neoconf.nvim',
        cmd = 'Neoconf',
        opts = {},
      },
    },
  },
  -- show pressed keys
  {
    'nvzone/showkeys',
    cmd = 'ShowkeysToggle',
    opts = {
      timeout = 1,
      maxkeys = 5,
    },
    enabled = false,
  },
  -- motions game
  {
    'ThePrimeagen/vim-be-good',
    event = 'VeryLazy',
    enabled = false,
  },
  -- prevent inefficient motions
  {
    'm4xshen/hardtime.nvim',
    opts = {},
    enabled = false,
  },
  -- hints for vertical and horizontal motions
  {
    'tris203/precognition.nvim',
    event = 'VeryLazy',
    opts = {},
    enabled = false,
  },
  -- plugin collection
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {},
  },
  -- session management
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
    -- stylua: ignore
    keys = {
      { '<leader>qs', function() require('persistence').load() end, desc = 'Restore Session' },
      { '<leader>qS', function() require('persistence').select() end,desc = 'Select Session' },
      { '<leader>ql', function() require('persistence').load({ last = true }) end, desc = 'Restore Last Session' },
      { '<leader>qd', function() require('persistence').stop() end, desc = 'Dont Save Current Session' },
    },
  },

  -- library used by other plugins
  { 'nvim-lua/plenary.nvim', lazy = true },
}
