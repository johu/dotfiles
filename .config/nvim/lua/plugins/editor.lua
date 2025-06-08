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
  -- Flash enhances the built-in search functionality by showing labels
  -- at the end of each match, letting you quickly jump to a specific
  -- location.
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },
      { 'S', mode = { 'n', 'o', 'x' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },
      { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
      { '<c-s>', mode = { 'c' }, function() require('flash').toggle() end, desc = 'Toggle Flash Search' },
    },
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
