return {
  -- escape mapping (key combos like 'jk')
  {
    'max397574/better-escape.nvim',
    opts = {},
  },
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
    opts = {},
  },
  -- indent line
  {
    'lukas-reineke/indent-blankline.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    main = 'ibl',
    opts = {
      indent = { char = '┊' },
    },
  },
  -- comments
  {
    'numToStr/Comment.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
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
    opts = {},
  },
}
