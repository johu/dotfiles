return {
  -- automatically add closing character
  {
    'windwp/nvim-autopairs',
    event = { 'InsertEnter' },
    config = function()
      require('nvim-autopairs').setup {
        check_ts = true,
        ts_config = {
          lua = { 'string' },
          javascript = { 'template_string' },
          java = false,
        },
      }
    end,
  },
  -- auto indent (based on style in the file if no configuration is found like editorconfig etc)
  {
    'nmac427/guess-indent.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
  -- indent line
  {
    'snacks.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    ---@type snacks.Config
    opts = {
      ---@class snacks.indent.Config
      indent = {
        enabled = true,
        -- TODO: check why the char is not working
        char = '┊',
        animate = {
          enabled = false,
        },
      },
    },
  },
  -- comments
  {
    'folke/ts-comments.nvim',
    event = 'VeryLazy',
    opts = {},
  },
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
  -- surround
  {
    'kylechui/nvim-surround',
    event = { 'BufReadPre', 'BufNewFile' },
    version = '*',
    config = true,
  },
  -- color codes colored
  {
    'brenoprata10/nvim-highlight-colors',
    event = 'VeryLazy',
    opts = {},
  },
  -- configures Lua LSP for your Neovim config, runtime and plugins
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    cmd = 'LazyDev',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        { path = 'LazyVim', words = { 'LazyVim' } },
        { path = 'lazy.nvim', words = { 'LazyVim' } },
        { path = 'snacks.nvim', words = { 'Snacks' } },
      },
    },
  },
}
