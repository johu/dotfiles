require('nvim-autopairs').setup {
  check_ts = true,
  ts_config = {
    lua = { 'string' },
    javascript = { 'template_string' },
    java = false,
  },
}

require('guess-indent').setup {}
require('ts-comments').setup {}
require('todo-comments').setup {}
require('grug-far').setup { headerMaxWidth = 80 }
require('flash').setup {}
require('nvim-surround').setup {}
require('nvim-highlight-colors').setup {}
require('lazydev').setup {
  library = {
    { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    { path = 'snacks.nvim', words = { 'Snacks' } },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>sr', function()
  local grug = require 'grug-far'
  local ext = vim.bo.buftype == '' and vim.fn.expand '%:e'
  grug.open {
    transient = true,
    prefills = {
      filesFilter = ext and ext ~= '' and '*.' .. ext or nil,
    },
  }
end, { desc = 'Search and Replace' })

vim.keymap.set({ 'n', 'x', 'o' }, 's', function()
  require('flash').jump()
end, { desc = 'Flash' })

vim.keymap.set({ 'n', 'o', 'x' }, 'S', function()
  require('flash').treesitter()
end, { desc = 'Flash Treesitter' })

vim.keymap.set('o', 'r', function()
  require('flash').remote()
end, { desc = 'Remote Flash' })

vim.keymap.set({ 'o', 'x' }, 'R', function()
  require('flash').treesitter_search()
end, { desc = 'Treesitter Search' })

vim.keymap.set('c', '<c-s>', function()
  require('flash').toggle()
end, { desc = 'Toggle Flash Search' })
