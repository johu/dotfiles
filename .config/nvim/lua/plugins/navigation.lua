require('project_nvim').setup {}

local harpoon = require 'harpoon'
harpoon:setup {
  menu = {
    width = vim.api.nvim_win_get_width(0) - 4,
  },
  settings = {
    save_on_toggle = true,
  },
}

require('oil').setup {
  view_options = {
    show_hidden = true,
  },
}

require('fzf-lua').setup {}

vim.keymap.set('n', '<leader>H', function()
  harpoon:list():add()
end, { desc = 'Harpoon File' })

vim.keymap.set('n', '<leader>h', function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = 'Harpoon Quick Menu' })

for index, shortcut in ipairs { 'h', 'j', 'k', 'l' } do
  vim.keymap.set('n', '<A-' .. shortcut .. '>', function()
    harpoon:list():select(index)
  end, { desc = 'Harpoon to File ' .. index })
end

vim.keymap.set('n', '-', require('oil').open, { desc = 'Open file explorer' })

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config-fzf-terminal-keys', { clear = true }),
  pattern = 'fzf',
  callback = function(event)
    vim.keymap.set('t', '<c-j>', '<c-j>', { buffer = event.buf, nowait = true })
    vim.keymap.set('t', '<c-k>', '<c-k>', { buffer = event.buf, nowait = true })
  end,
})

local fzf = require 'fzf-lua'

vim.keymap.set('n', '<leader>fb', function() fzf.buffers() end, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>ff', function() fzf.files() end, { desc = 'Files' })
vim.keymap.set('n', '<leader>fg', function() fzf.git_files() end, { desc = 'Git Files' })
vim.keymap.set('n', '<leader>fk', function() fzf.keymaps() end, { desc = 'Keymaps' })
vim.keymap.set('n', '<leader>fh', function() fzf.helptags() end, { desc = 'Help' })
vim.keymap.set('n', '<leader>fr', function() fzf.oldfiles() end, { desc = 'Recent' })
vim.keymap.set('n', '<leader>fu', function() fzf.builtin() end, { desc = 'Builtin' })
vim.keymap.set('n', '<leader>sb', function() fzf.lgrep_curbuf() end, { desc = 'Buffer' })
vim.keymap.set('n', '<leader>sg', function() fzf.live_grep() end, { desc = 'Grep' })
vim.keymap.set('n', '<leader>sw', function() fzf.grep_cword() end, { desc = 'Current Word' })
vim.keymap.set('n', '<leader>sW', function() fzf.grep_cWORD() end, { desc = 'Current WORD' })
vim.keymap.set('n', '<leader>sd', function() fzf.diagnostics_document() end, { desc = 'Diagnostics' })
vim.keymap.set('n', '<leader>sD', function() fzf.diagnostics_workspace() end, { desc = 'Diagnostics (Workspace)' })
vim.keymap.set('n', '<leader>sR', function() fzf.resume() end, { desc = 'Resume' })
vim.keymap.set('n', '<leader>gc', function() fzf.git_commits() end, { desc = 'Commits' })
vim.keymap.set('n', '<leader>gs', function() fzf.git_status() end, { desc = 'Status' })
vim.keymap.set('n', '<leader>ec', function() fzf.files { cwd = vim.fn.stdpath 'config' } end, { desc = 'Neovim Config' })
vim.keymap.set('n', '<leader>ep', function() fzf.files { cwd = vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'pack', 'core', 'opt') } end, { desc = 'Packages' })
vim.keymap.set('n', '<leader>/', function() fzf.live_grep() end, { desc = '[/] Grep' })
vim.keymap.set('n', '<leader>,', function() fzf.buffers { sort_mru = true, sort_lastused = true } end, { desc = 'Switch Buffer' })
vim.keymap.set('n', '<leader>:', function() fzf.command_history() end, { desc = 'Command History' })
vim.keymap.set('n', '<leader><leader>', function() fzf.files() end, { desc = 'Find Files' })

vim.keymap.set('n', '<leader>st', function()
  require('todo-comments.fzf').todo()
end, { desc = 'Todo' })

vim.keymap.set('n', '<leader>sT', function()
  require('todo-comments.fzf').todo() { keywords = { 'TODO', 'FIX', 'FIXME' } }
end, { desc = 'Todo/Fix/Fixme' })
