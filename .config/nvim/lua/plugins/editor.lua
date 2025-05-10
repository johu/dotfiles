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
    dependencies = {
      'JoosepAlviste/nvim-ts-context-commentstring',
    },
    config = function()
      local ts_context_commentstring = require 'ts_context_commentstring.integrations.comment_nvim'
      require('Comment').setup {
        -- for commenting tsx, jsx, svelte, html files
        pre_hook = ts_context_commentstring.create_pre_hook(),
      }
    end,
  },
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local todo_comments = require 'todo-comments'

      local keymap = vim.keymap
      keymap.set('n', ']t', function()
        todo_comments.jump_next()
      end, { desc = 'Next todo comment' })

      keymap.set('n', '[t', function()
        todo_comments.jump_prev()
      end, { desc = 'Previous todo comment' })

      todo_comments.setup()
    end,
  },
  -- surround
  {
    'kylechui/nvim-surround',
    event = { 'BufReadPre', 'BufNewFile' },
    version = '*',
    config = true,
  },
  -- substitute
  {
    'gbprod/substitute.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local substitute = require 'substitute'
      substitute.setup()

      local keymap = vim.keymap
      keymap.set('n', 's', substitute.operator, { desc = 'Substitute with motion' })
      keymap.set('n', 'ss', substitute.line, { desc = 'Substitute line' })
      keymap.set('n', 'S', substitute.eol, { desc = 'Substitute to end of line' })
      keymap.set('x', 's', substitute.visual, { desc = 'Substitute in visual mode' })
    end,
  },
  -- color codes colored
  {
    'brenoprata10/nvim-highlight-colors',
    opts = {},
  },
}
