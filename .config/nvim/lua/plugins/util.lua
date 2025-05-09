return {
  -- startup time profiler
  {
    'dstein64/vim-startuptime',
    cmd = 'StartupTime',
    config = function()
      vim.g.startuptime_tries = 10
    end,
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
    dependencies = {
      'MunifTanjim/nui.nvim',
      'nvim-lua/plenary.nvim',
    },
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
}
