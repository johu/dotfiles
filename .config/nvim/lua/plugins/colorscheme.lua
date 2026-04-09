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
}
