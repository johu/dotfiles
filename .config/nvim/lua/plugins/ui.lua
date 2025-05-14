return {
  -- TODO: deprecated upstream -> replace /w snacks.nvim
  -- general ui improvement
  {
    'stevearc/dressing.nvim',
    event = 'VeryLazy',
  },
  -- icon theme
  {
    'echasnovski/mini.icons',
    config = function()
      local icons = require 'mini.icons'
      icons.setup()
      icons.mock_nvim_web_devicons()
    end,
  },
  -- top bar
  {
    'akinsho/bufferline.nvim',
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
    dependencies = {
      'echasnovski/mini.icons',
    },
    config = function()
      require('lualine').setup {
        options = {
          theme = 'auto',
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
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 500
    end,
    opts = {},
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
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
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
  -- dashboard
  {
    'snacks.nvim',
    ---@type snacks.Config
    opts = {
      dashboard = {
        preset = {
          header = [[

          ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗         
          ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║         
          ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║         
          ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║         
          ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║         
          ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝         

          ]],
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
      },
    },
  },
}
