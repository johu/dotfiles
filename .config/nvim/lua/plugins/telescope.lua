return {
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
            ['<C-k>'] = actions.move_selection_previous, -- move to prev result
            ['<C-j>'] = actions.move_selection_next, -- move to next result
            ['<C-q>'] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
            ['<C-t>'] = trouble_telescope.open,
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
    keymap.set('n', '<leader>fc', functions.grep_string, { desc = 'Find string under cursor in cwd' })
    keymap.set('n', '<leader>ff', functions.find_files, { desc = 'Find files in cwd' })
    keymap.set('n', '<leader>fh', functions.help_tags, { desc = 'Find help' })
    keymap.set('n', '<leader>fr', functions.oldfiles, { desc = 'Find recent files' })
    keymap.set('n', '<leader>fs', functions.live_grep, { desc = 'Find string in cwd' })
    keymap.set('n', '<leader>ft', '<cmd>TodoTelescope<cr>', { desc = 'Find todos' })
    keymap.set('n', '<leader>en', function()
      functions.find_files {
        cwd = vim.fn.stdpath 'config',
      }
    end, { desc = 'Edit neovim config' })
    keymap.set('n', '<leader>ep', function()
      functions.find_files {
        cwd = vim.fs.joinpath(vim.fn.stdpath 'data', 'lazy'),
      }
    end, { desc = 'Edit packages' })
  end,
}
