return {
  {
    'folke/which-key.nvim',
    opts = {
      spec = {
        { '<BS>', desc = 'Decrement Selection', mode = 'x' },
        { '<Enter>', desc = 'Increment Selection', mode = { 'x', 'n' } },
      },
    },
  },
  {
    'nvim-treesitter/nvim-treesitter',
    event = { 'BufReadPre', 'BufNewFile', 'VeryLazy' },
    build = ':TSUpdate',
    lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
    init = function(plugin)
      -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
      -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
      -- no longer trigger the **nvim-treesitter** module to be loaded in time.
      -- Luckily, the only things that those plugins need are the custom queries, which we make available
      -- during startup.
      require('lazy.core.loader').add_to_rtp(plugin)
      require 'nvim-treesitter.query_predicates'
    end,
    cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },
    keys = {
      { '<Enter>', desc = 'Increment Selection' },
      { '<BS>', desc = 'Decrement Selection', mode = 'x' },
    },
    opts_extend = { 'ensure_installed' },
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
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
    },
    config = function(_, opts)
      require('nvim-treesitter.configs').setup(opts)
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = 'VeryLazy',
    enable = true,
    config = function()
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
