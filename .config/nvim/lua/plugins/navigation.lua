return {
  -- tmux
  {
    'christoomey/vim-tmux-navigator',
    enabled = false, -- TODO: same shortcuts as harpoon
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
          '<A-' .. shortcut .. '>',
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
    -- stylua: ignore
    keys = function()
      local fzf = require 'fzf-lua'
      local keys = {
        { '<c-j>', '<c-j>', ft = 'fzf', mode = 't', nowait = true },
        { '<c-k>', '<c-k>', ft = 'fzf', mode = 't', nowait = true },
        -- find
        { '<leader>fb', function() fzf.buffers() end, desc = 'Buffers', },
        { '<leader>ff', function() fzf.files() end, desc = 'Files', },
        { '<leader>fg', function() fzf.git_files() end, desc = 'Git Files', },
        { '<leader>fk', function() fzf.keymaps() end, desc = 'Keymaps', },
        { '<leader>fh', function() fzf.helptags() end, desc = 'Help', },
        { '<leader>fr', function() fzf.oldfiles() end, desc = 'Recent', },
        { '<leader>fu', function() fzf.builtin() end, desc = 'Builtin', },
        -- search
        { '<leader>sb', function() fzf.lgrep_curbuf() end, desc = 'Buffer', },
        { '<leader>sg', function() fzf.live_grep() end, desc = 'Grep', },
        { '<leader>sw', function() fzf.grep_cword() end, desc = 'Current Word', },
        { '<leader>sW', function() fzf.grep_cWORD() end, desc = 'Current WORD', },
        { '<leader>sd', function() fzf.diagnostics_document() end, desc = 'Diagnostics', },
        { '<leader>sD', function() fzf.diagnostics_workspace() end, desc = 'Diagnostics (Workspace)', },
        { '<leader>sR', function() fzf.resume() end, desc = 'Resume', },
        -- git
        { '<leader>gc', function() fzf.git_commits() end, desc = 'Commits', },
        { '<leader>gs', function() fzf.git_status() end, desc = 'Status', },
        -- edit
        { '<leader>ec', function() fzf.files { cwd = vim.fn.stdpath 'config' } end, desc = 'Neovim Config', },
        { '<leader>ep', function() fzf.files { cwd = vim.fs.joinpath(vim.fn.stdpath 'config', 'lazy') } end, desc = 'Packages', },
        -- misc
        { '<leader>/', function() fzf.live_grep() end, desc = '[/] Grep', },
        { '<leader>,', function() fzf.buffers { sort_mru = true, sort_lastused = true } end, desc = 'Switch Buffer', },
        { '<leader>:', function() fzf.command_history() end, desc = 'Command History', },
        { '<leader><leader>', function() fzf.files() end, desc = 'Find Files' },
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
      { '<leader>st', function() require('todo-comments.fzf').todo() end, desc = 'Todo', },
      { '<leader>sT', function() require('todo-comments.fzf').todo() { keywords = { 'TODO', 'FIX', 'FIXME' } } end, desc = 'Todo/Fix/Fixme', },
    },
  },
}
