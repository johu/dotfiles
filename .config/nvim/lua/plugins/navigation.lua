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
    'stevearc/oil.nvim',
    config = function()
      local oil = require 'oil'
      oil.setup()
      vim.keymap.set('n', '-', oil.toggle_float, {})
    end,
  },
}
