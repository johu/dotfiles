-- leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set('n', 'x', '"_x') -- delete without saving in buffer
keymap.set('n', '<ESC>', '<cmd>nohlsearch<CR>')
keymap.set('n', '<leader>cx', '<cmd>source %<CR>', { desc = 'Source File' })

-- plugin manager
keymap.set('n', '<leader>l', '<cmd>Lazy<CR>', { desc = 'Lazy' })

-- numbers
keymap.set('n', '<leader>+', '<C-a>', { desc = 'Increment number' })
keymap.set('n', '<leader>-', '<C-x>', { desc = 'Decrement number' })

-- window management
keymap.set('n', '<leader>wv', '<C-w>v', { desc = 'Split window vertically' })
keymap.set('n', '<leader>wh', '<C-w>s', { desc = 'Split window horizontally' })
keymap.set('n', '<leader>we', '<C-w>=', { desc = 'Make splits equal size' })
keymap.set('n', '<leader>wx', '<cmd>close<CR>', { desc = 'Close current split' })

keymap.set('n', '<leader><tab><tab>', '<cmd>tabnew<CR>', { desc = 'New Tab' })
keymap.set('n', '<leader><tab>d', '<cmd>tabclose<CR>', { desc = 'Close Tab' })
keymap.set('n', '<leader><tab>f', '<cmd>tabfirst<CR>', { desc = 'First Tab' })
keymap.set('n', '<leader><tab>j', '<cmd>tabnext<CR>', { desc = 'Next Tab' })
keymap.set('n', '<leader><tab>k', '<cmd>tabprevious<CR>', { desc = 'Previous Tab' })
keymap.set('n', '<leader><tab>l', '<cmd>tablast<CR>', { desc = 'Last Tab' })
keymap.set('n', '<leader><tab>o', '<cmd>tabonly<CR>', { desc = 'Close Other Tabs' })

-- move visual selection
keymap.set('v', 'J', "<cmd>m '>+1<CR>gv=gv", { desc = 'Move lines down in visual selection' })
keymap.set('v', 'K', "<cmd>m '<-2<CR>gv=gv", { desc = 'Move lines up in visual selection' })

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

-- quit
keymap.set('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit All' })
