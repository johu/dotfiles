return {
  -- tmux
  {
    'christoomey/vim-tmux-navigator',
    enabled = false, -- TODO: same shortcuts as harpoon
  },
  -- splits
  {
    'szw/vim-maximizer',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      { '<leader>sm', '<cmd>MaximizerToggle<CR>', desc = 'Maximize/minimize a split' },
    },
  },
  -- auto project root detection
  {
    'Spelis/project.nvim',
    main = 'project_nvim',
    event = 'VeryLazy',
    opts = {},
    priority = 900,
  },
  -- quick buffer navigation
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      menu = {
        width = vim.api.nvim_win_get_width(0) - 4,
      },
      settings = {
        save_on_toggle = true,
      },
    },
    keys = function()
      local harpoon = require 'harpoon'
    -- stylua: ignore
      local keys = {
        { '<leader>H', function() harpoon:list():add() end, desc = 'Harpoon File', },
        { '<leader>h', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, desc = 'Harpoon Quick Menu', },
      }

      local shortcuts = { 'h', 'j', 'k', 'l' }
      for i, shortcut in ipairs(shortcuts) do
        table.insert(keys, {
          '<C-' .. shortcut .. '>',
          function()
            harpoon:list():select(i)
          end,
          desc = 'Harpoon to File ' .. i,
        })
      end
      return keys
    end,
  },
  -- file explorer
  {
    'stevearc/oil.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    ---@module 'oil'
    --@type oil.SetupOpts
    opts = {
      view_options = {
        show_hidden = true,
      },
    },
    lazy = false,
    keys = function()
      local oil = require 'oil'
      oil.setup {}
      local keys = {
        {
          '-',
          oil.open,
          { desc = 'Open file explorer' },
        },
      }
      return keys
    end,
  },
  -- fuzzy finder
  {
    'ibhagwan/fzf-lua',
    event = 'VeryLazy',
    opts = {},
    keys = function()
      local fzf = require 'fzf-lua'
      local keys = {
        {
          '<leader>ff',
          function()
            fzf.files()
          end,
          desc = 'Files',
        },
        {
          '<leader>fo',
          function()
            fzf.oldfiles()
          end,
          desc = 'Old Files',
        },
        {
          '<leader>fs',
          function()
            fzf.live_grep()
          end,
          desc = 'String',
        },
        {
          '<leader>fw',
          function()
            fzf.grep_cword()
          end,
          desc = 'current Word',
        },
        {
          '<leader>fW',
          function()
            fzf.grep_cWORD()
          end,
          desc = 'current WORD',
        },
        {
          '<leader>fh',
          function()
            fzf.helptags()
          end,
          desc = 'Help',
        },
        {
          '<leader>fk',
          function()
            fzf.keymaps()
          end,
          desc = 'Keymaps',
        },
        {
          '<leader>fb',
          function()
            fzf.buffers()
          end,
          desc = 'Buffer',
        },
        {
          '<leader>fd',
          function()
            fzf.diagnostics_document()
          end,
          desc = 'Diagnostics',
        },
        {
          '<leader>fr',
          function()
            fzf.resume()
          end,
          desc = 'Resume',
        },
        {
          '<leader>fu',
          function()
            fzf.builtin()
          end,
          desc = 'Builtin',
        },
        {
          '<leader>/',
          function()
            fzf.lgrep_curbuf()
          end,
          desc = '[/] Find String in current Buffer',
        },
        {
          '<leader>ec',
          function()
            fzf.files { cwd = vim.fn.stdpath 'config' }
          end,
          desc = 'Neovim Config',
        },
        {
          '<leader>ep',
          function()
            fzf.files { cwd = vim.fs.joinpath(vim.fn.stdpath 'config', 'lazy') }
          end,
          desc = 'Packages',
        },
      }
      return keys
    end,
  },
  -- todo comments fzf integration
  {
    'folke/todo-comments.nvim',
    -- PERF: extra config to properly lazy load todo comments plugin
    optional = true,
    -- stylua: ignore
    keys = {
      { '<leader>ft', function() require('todo-comments.fzf').todo() end, desc = 'Todo', },
      { '<leader>fT', function() require('todo-comments.fzf').todo() { keywords = { 'TODO', 'FIX', 'FIXME' } } end, desc = 'Todo/Fix/Fixme', },
    },
  },
}
