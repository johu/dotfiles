require('nvim-treesitter').setup {
  auto_install = false,
  sync_install = false,
  highlight = { enable = true },
  indent = { enable = true },
  autotag = { enable = true },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<Enter>',
      node_incremental = '<Enter>',
      scope_incremental = false,
      node_decremental = '<BS>',
    },
  },
  ensure_installed = {
    'bash',
    'c',
    'cmake',
    'cpp',
    'css',
    'desktop',
    'devicetree',
    'diff',
    'dockerfile',
    'git_config',
    'git_rebase',
    'gitattributes',
    'gitcommit',
    'gitignore',
    'go',
    'gomod',
    'gosum',
    'gpg',
    'html',
    'hyprlang',
    'ini',
    'java',
    'javascript',
    'json',
    'jsonc',
    'jq',
    'lua',
    'markdown',
    'markdown_inline',
    'ninja',
    'passwd',
    'properties',
    'python',
    'query',
    'ssh_config',
    'tmux',
    'toml',
    'tsx',
    'typescript',
    'udev',
    'vim',
    'vimdoc',
    'xml',
    'yaml',
    'zig',
  },
}

require('nvim-ts-autotag').setup {}

local textobjects = require 'nvim-treesitter-textobjects'
local select = require 'nvim-treesitter-textobjects.select'
local swap = require 'nvim-treesitter-textobjects.swap'

textobjects.setup {
  select = {
    lookahead = true,
    selection_modes = {
      ['@parameter.outer'] = 'v',
      ['@function.outer'] = 'V',
      ['@class.outer'] = '<c-v>',
    },
    include_surrounding_whitespace = true,
  },
}

local map = function(mode, lhs, query, query_group, callback, desc)
  vim.keymap.set(mode, lhs, function()
    callback(query, query_group)
  end, { desc = desc })
end

map({ 'x', 'o' }, 'af', '@function.outer', 'textobjects', select.select_textobject, 'Select outer function')
map({ 'x', 'o' }, 'if', '@function.inner', 'textobjects', select.select_textobject, 'Select inner function')
map({ 'x', 'o' }, 'ac', '@class.outer', 'textobjects', select.select_textobject, 'Select outer class')
map({ 'x', 'o' }, 'ic', '@class.inner', 'textobjects', select.select_textobject, 'Select inner class')
map({ 'x', 'o' }, 'ao', '@comment.outer', 'textobjects', select.select_textobject, 'Select comment')
map({ 'x', 'o' }, 'as', '@local.scope', 'locals', select.select_textobject, 'Select language scope')
map('n', '<leader>a', '@parameter.inner', 'textobjects', swap.swap_next, 'Swap with next parameter')
map('n', '<leader>A', '@parameter.inner', 'textobjects', swap.swap_previous, 'Swap with previous parameter')
