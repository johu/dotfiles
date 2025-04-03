-- leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local keymap = vim.keymap

keymap.set('i', 'jk', '<ESC>', { desc = 'Exit instert mode with jk' })
keymap.set('n', 'x', '"_x') -- delete without saving in buffer
keymap.set('n', '<ESC>', ':nohlsearch<CR>')
keymap.set('n', '<leader><leader>x', '<cmd>source %<CR>')
keymap.set('n', '<leader>x', ':.lua<CR>')
keymap.set('v', '<leader>x', ':lua<CR>')

-- numbers
keymap.set('n', '<leader>+', '<C-a>', { desc = 'Increment number' })
keymap.set('n', '<leader>-', '<C-x>', { desc = 'Decrement number' })

-- window management
keymap.set('n', '<leader>sv', '<C-w>v', { desc = 'Split window vertically' })
keymap.set('n', '<leader>sh', '<C-w>s', { desc = 'Split window horizontally' })
keymap.set('n', '<leader>se', '<C-w>=', { desc = 'Make splits equal size' })
keymap.set('n', '<leader>sx', ':close<CR>', { desc = 'Close current split' })

keymap.set('n', '<leader>to', ':tabnew<CR>', { desc = 'Open new tab' })
keymap.set('n', '<leader>tx', ':tabclose<CR>', { desc = 'Close current tab' })
keymap.set('n', '<leader>tn', ':tabn<CR>', { desc = 'Go to next tab' })
keymap.set('n', '<leader>tp', ':tabp<CR>', { desc = 'Go to previous tab' })
keymap.set('n', '<leader>tf', '<cmd>tabnew %<CR>', { desc = 'Open current buffer in new tab' })
