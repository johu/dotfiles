return {
  -- ui components
  { 'MunifTanjim/nui.nvim', lazy = true },
  -- general ui improvement
  {
    'snacks.nvim',
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      input = { enabled = true },
      quickfile = { enabled = true },
    },
  },
  -- icon theme
  {
    'echasnovski/mini.icons',
    lazy = true,
    opts = {
      file = {
        ['.keep'] = { glyph = '󰊢', hl = 'MiniIconsGrey' },
      },
      filetype = {
        dotenv = { glyph = '', hl = 'MiniIconsYellow' },
      },
    },
    init = function()
      package.preload['nvim-web-devicons'] = function()
        local icons = require 'mini.icons'
        -- icons.setup()
        icons.mock_nvim_web_devicons()
        return package.loaded['nvim-web-devicons']
      end
    end,
  },
  -- top bar
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    dependencies = {
      'echasnovski/mini.icons',
    },
    version = '*',
    opts = {
      options = {
        mode = 'tabs',
      },
    },
  },
  -- bottom bar
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    init = function()
      vim.g.lualine_laststatus = vim.o.laststatus
      if vim.fn.argc(-1) > 0 then
        -- set an empty statusline till lualine loads
        vim.o.statusline = ' '
      else
        -- hide the statusline on the starter page
        vim.o.laststatus = 0
      end
    end,
    config = function()
      require('lualine').setup {
        options = {
          theme = 'auto',
          globalstatus = vim.o.laststatus == 3,
          disabled_filetypes = { statusline = { 'snacks_dashboard' } },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = { 'filename' },
          lualine_x = { 'lsp_status', 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      }
    end,
  },
  -- keymap help
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts_extend = { 'spec' },
    opts = {
      preset = 'helix',
      spec = {
        {
          mode = { 'n', 'v' },
          { '<leader><tab>', group = 'tabs' },
          { '<leader>c', group = 'code' },
          { '<leader>d', group = 'debug' },
          { '<leader>dp', group = 'profiler' },
          { '<leader>e', group = 'edit' },
          { '<leader>f', group = 'find' },
          { '<leader>g', group = 'git' },
          { '<leader>gh', group = 'hunks' },
          { '<leader>q', group = 'quit/session' },
          { '<leader>s', group = 'search' },
          { '<leader>u', group = 'ui', icon = { icon = '󰙵 ', color = 'cyan' } },
          { '<leader>x', group = 'diagnostics/quickfix', icon = { icon = '󱖫 ', color = 'green' } },
          { '[', group = 'prev' },
          { ']', group = 'next' },
          { 'g', group = 'goto' },
          { 'gs', group = 'surround' },
          { 'z', group = 'fold' },
          {
            '<leader>b',
            group = 'buffer',
            expand = function()
              return require('which-key.extras').expand.buf()
            end,
          },
          {
            '<leader>w',
            group = 'windows',
            proxy = '<c-w>',
            expand = function()
              return require('which-key.extras').expand.win()
            end,
          },
          { 'gx', desc = 'Open with system app' },
        },
      },
    },
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show { global = false }
        end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },
  -- notifications
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    opts = {},
    config = function()
      require('noice').setup {
        lsp = {
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
            ['vim.lsp.util.stylize_markdown'] = true,
            ['cmp.entry.get_documentation'] = true,
          },
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = false,
          lsp_doc_border = false,
        },
      }
    end,
  },
  {
    'snacks.nvim',
    ---@type snacks.Config
    opts = {
      notifier = { enabled = true },
    },
    -- stylua: ignore
    keys = {
      { '<leader>n', function()
        if Snacks.config.picker and Snacks.config.picker.enabled then
          Snacks.picker.notifications()
        else
          Snacks.notifier.show_history()
        end
      end, desc = 'Notification History' },
      { '<leader>un', function() Snacks.notifier.hide() end, desc = 'Dismiss All Notifications' },
    },
  },
  -- dashboard
  {
    'snacks.nvim',
    ---@type snacks.Config
    opts = {
      dashboard = {
        preset = {
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
            { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' },
            { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy' },
            { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
          },
        },
        sections = {
          {
            -- ascii experiment
            -- {
            --   pane = 1,
            --   section = 'terminal',
            --   cmd = 'ascii-image-converter -C -c --dimensions 40,20 ~/.config/images/neovim-mark.png; sleep .1',
            --   height = 20,
            --   padding = 5,
            -- },
            {
              pane = 1,
              { section = 'header' },
              { icon = ' ', title = 'Keymaps', section = 'keys', indent = 2, padding = 1 },
              { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
              { icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
              { section = 'startup' },
            },
          },
        },
      },
    },
  },
}
