return {
  {
    'nvim-treesitter/nvim-treesitter',
    event = { 'BufReadPre', 'BufNewFile', 'VeryLazy' },
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
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
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = 'VeryLazy',
    init = function()
      local config = require 'nvim-treesitter.configs'
      config.setup {
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ao'] = '@comment.outer',
              ['ic'] = { query = '@class.inner', desc = 'Select inner part of a class region' },
              ['as'] = { query = '@local.scope', query_group = 'locals', desc = 'Select language scope' },
            },
            selection_modes = {
              ['@parameter.outer'] = 'v', -- charwise
              ['@function.outer'] = 'V', -- linewise
              ['@class.outer'] = '<c-v>', -- blockwise
            },
            include_surrounding_whitespace = true,
          },
          swap = {
            enable = true,
            swap_next = {
              ['<leader>a'] = { query = '@parameter.inner', desc = 'Swap with next parameter' },
            },
            swap_previous = {
              ['<leader>A'] = { '@parameter.inner', desc = 'Swap with previous parameter' },
            },
          },
        },
      }
    end,
  },
  -- Automatically add closing tags for HTML and JSX
  {
    'windwp/nvim-ts-autotag',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
}
