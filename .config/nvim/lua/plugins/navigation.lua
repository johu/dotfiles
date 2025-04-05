return {
  {
    'christoomey/vim-tmux-navigator',
  },
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    opts = {
      menu = {
        width = vim.api.nvim_win_get_width(0) - 4,
      },
      settings = {
        save_on_toggle = true,
      },
    },
    keys = function()
      local keys = {
        {
          '<leader>H',
          function()
            require('harpoon'):list():add()
          end,
          desc = 'Harpoon File',
        },
        {
          '<leader>h',
          function()
            local harpoon = require 'harpoon'
            harpoon.ui:toggle_quick_menu(harpoon:list())
          end,
          desc = 'Harpoon Quick Menu',
        },
      }

      local shortcuts = { 'h', 'j', 'k', 'l' }
      for i, shortcut in ipairs(shortcuts) do
        table.insert(keys, {
          '<C-' .. shortcut .. '>',
          function()
            require('harpoon'):list():select(i)
          end,
          desc = 'Harpoon to File ' .. i,
        })
      end
      return keys
    end,
  },
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      local nvimtree = require 'nvim-tree'

      -- recommended settings from nvim-tree documentation
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1

      nvimtree.setup {
        view = {
          width = 35,
          relativenumber = false,
        },
        -- change folder arrow icons
        renderer = {
          indent_markers = {
            enable = true,
          },
          icons = {
            glyphs = {
              folder = {
                arrow_closed = '',
                arrow_open = '',
              },
            },
          },
        },
        -- disable window_picker for explorer to work well with window splits
        actions = {
          open_file = {
            window_picker = {
              enable = false,
            },
          },
        },
        filters = {
          custom = { '.DS_Store' },
        },
        git = {
          ignore = false,
        },
      }

      local keymap = vim.keymap
      keymap.set('n', '<leader>ee', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle file explorer' })
      keymap.set('n', '<leader>ef', '<cmd>NvimTreeFindFileToggle<CR>', { desc = 'Toggle file explorer on current file' })
      keymap.set('n', '<leader>ec', '<cmd>NvimTreeCollapse<CR>', { desc = 'Collapse file explorer' })
      keymap.set('n', '<leader>er', '<cmd>NvimTreeRefresh<CR>', { desc = 'Refresh file explorer' })
    end,
  },
  {
    'stevearc/oil.nvim',
    config = function()
      local oil = require 'oil'
      oil.setup()
      vim.keymap.set('n', '-', oil.toggle_float, {})
    end,
  },
}
