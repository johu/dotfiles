-- leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

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

-- move visual selection
keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move lines down in visual selection' })
keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move lines up in visual selection' })

-- remaps for centering
keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Move down in buffer with cursor centered' })
keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Move up in buffer with cursor centered' })
keymap.set('n', 'n', 'nzzzv')
keymap.set('n', 'N', 'Nzzzv')
keymap.set('n', 'J', 'mzJ`z')

-- indent visual selection
keymap.set('v', '<', '<gv', opts)
keymap.set('v', '>', '>gv', opts)

-- remap for keeping yank content after paste
keymap.set('x', '<leader>p', [["_dP]])
keymap.set('v', 'p', '"_dp', opts)

-- copies or yank to system clipboard
keymap.set('n', '<leader>Y', [["+Y]], opts)

-- leader d delete wont remember as yanked/clipboard when delete pasting
keymap.set({ 'n', 'v' }, '<leader>d', [["_d]])
