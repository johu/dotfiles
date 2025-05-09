return {
  -- tmux
  {
    'christoomey/vim-tmux-navigator',
  },
  -- splits
  {
    'szw/vim-maximizer',
    keys = {
      { '<leader>sm', '<cmd>MaximizerToggle<CR>', desc = 'Maximize/minimize a split' },
    },
  },
  -- quick buffer navigation
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
  -- file explorer
  {
    'stevearc/oil.nvim',
    config = function()
      local oil = require 'oil'
      oil.setup()
      vim.keymap.set('n', '-', oil.toggle_float, {})
    end,
  },
  -- fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      'nvim-tree/nvim-web-devicons',
      'folke/todo-comments.nvim',
    },
    config = function()
      local telescope = require 'telescope'
      local actions = require 'telescope.actions'
      local transform_mod = require('telescope.actions.mt').transform_mod

      local trouble = require 'trouble'
      local trouble_telescope = require 'trouble.sources.telescope'

      -- or create your custom action
      local custom_actions = transform_mod {
        open_trouble_qflist = function(prompt_bufnr)
          trouble.toggle 'quickfix'
        end,
      }

      telescope.setup {
        defaults = {
          path_display = { 'smart' },
          mappings = {
            i = {
              ['<c-k>'] = actions.move_selection_previous, -- move to prev result
              ['<c-j>'] = actions.move_selection_next, -- move to next result
              ['<c-q>'] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
              ['<c-t>'] = trouble_telescope.open,
            },
          },
        },
        extensions = {
          fzf = {},
        },
      }

      telescope.load_extension 'fzf'

      local functions = require 'telescope.builtin'
      local keymap = vim.keymap
      keymap.set('n', '<leader>fc', functions.grep_string, { desc = 'find string under cursor in cwd' })
      keymap.set('n', '<leader>ff', functions.find_files, { desc = 'find files in cwd' })
      keymap.set('n', '<leader>fh', functions.help_tags, { desc = 'find help' })
      keymap.set('n', '<leader>fr', functions.oldfiles, { desc = 'find recent files' })
      keymap.set('n', '<leader>fs', functions.live_grep, { desc = 'find string in cwd' })
      keymap.set('n', '<leader>ft', '<cmd>todotelescope<cr>', { desc = 'find todos' })
      keymap.set('n', '<leader>en', function()
        functions.find_files {
          cwd = vim.fn.stdpath 'config',
        }
      end, { desc = 'edit neovim config' })
      keymap.set('n', '<leader>ep', function()
        functions.find_files {
          cwd = vim.fs.joinpath(vim.fn.stdpath 'data', 'lazy'),
        }
      end, { desc = 'edit packages' })
    end,
  },
  -- todo & co navigation
  -- TODO: check if this can be dropped, fzf-lua maybe more useful
  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'folke/todo-comments.nvim' },
    opts = {},
    keys = {
      { '<leader>xx', '<cmd>TroubleToggle<CR>', desc = 'Open/close trouble list' },
      { '<leader>xw', '<cmd>TroubleToggle workspace_diagnostics<CR>', desc = 'Open trouble workspace diagnostics' },
      { '<leader>xd', '<cmd>TroubleToggle document_diagnostics<CR>', desc = 'Open trouble document diagnostics' },
      { '<leader>xq', '<cmd>TroubleToggle quickfix<CR>', desc = 'Open trouble quickfix list' },
      { '<leader>xl', '<cmd>TroubleToggle loclist<CR>', desc = 'Open trouble location list' },
      { '<leader>xt', '<cmd>TodoTrouble<CR>', desc = 'Open todos in trouble' },
    },
  },
}
