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
  -- auto project root detection
  {
    'Spelis/project.nvim',
    main = 'project_nvim',
    opts = {},
    priority = 900,
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
      local harpoon = require 'harpoon'
      local keys = {
        {
          '<leader>H',
          function()
            harpoon:list():add()
          end,
          desc = 'Harpoon File',
        },
        {
          '<leader>h',
          function()
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
    ---@module 'oil'
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
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
    dependencies = {
      'echasnovski/mini.icons',
      'folke/todo-comments.nvim',
    },
    opts = {},
    keys = function()
      local fzf = require 'fzf-lua'
      local keys = {
        {
          '<leader>ff',
          function()
            fzf.files()
          end,
          desc = '[F]ind [F]iles',
        },
        {
          '<leader>fo',
          function()
            fzf.oldfiles()
          end,
          desc = '[F]ind [O]ld Files',
        },
        {
          '<leader>fs',
          function()
            fzf.live_grep()
          end,
          desc = '[F]ind [S]tring',
        },
        {
          '<leader>fw',
          function()
            fzf.grep_cword()
          end,
          desc = '[F]ind current [W]ord',
        },
        {
          '<leader>fW',
          function()
            fzf.grep_cWORD()
          end,
          desc = '[F]ind current [W]ORD',
        },
        {
          '<leader>fh',
          function()
            fzf.helptags()
          end,
          desc = '[F]ind [H]elp',
        },
        {
          '<leader>fk',
          function()
            fzf.keymaps()
          end,
          desc = '[F]ind [K]eymaps',
        },
        {
          '<leader>fb',
          function()
            fzf.buffers()
          end,
          desc = '[F]ind [B]uffer',
        },
        {
          '<leader>fd',
          function()
            fzf.diagnostics_document()
          end,
          desc = '[F]ind [D]iagnostics',
        },
        {
          '<leader>fr',
          function()
            fzf.resume()
          end,
          desc = '[F]ind [R]esume',
        },
        {
          '<leader>ft',
          '<Cmd>TodoFzfLua<CR>',
          function()
            fzf.builtin()
          end,
          desc = '[F]ind [T]odo',
        },
        {
          '<leader>fu',
          function()
            fzf.builtin()
          end,
          desc = '[F]ind B[u]iltin',
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
          desc = '[E]dit Neovim [C]onfig',
        },
        {
          '<leader>ep',
          function()
            fzf.files { cwd = vim.fs.joinpath(vim.fn.stdpath 'config', 'lazy') }
          end,
          desc = '[E]dit [P]ackages',
        },
      }
      return keys
    end,
  },
}
