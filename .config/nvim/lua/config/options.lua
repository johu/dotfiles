vim.cmd 'let g:netrw_liststyle = 3'

local opt = vim.opt

-- turn off swap files
opt.swapfile = false

-- save undo history
opt.undofile = true

-- line numbers
opt.relativenumber = true
opt.number = true

-- mouse support (can be useful for resizing splits for example)
opt.mouse = 'a'

-- tabs & indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.autoindent = true
opt.wrap = false
opt.breakindent = true

-- search & replace
opt.ignorecase = true
opt.smartcase = true
opt.cursorline = true
opt.iskeyword:append '-'
opt.inccommand = 'split'
opt.scrolloff = 10

-- colors
opt.termguicolors = true
opt.background = 'dark'
opt.signcolumn = 'yes'

-- keys
opt.backspace = 'indent,eol,start'

-- clipboard
opt.clipboard:append 'unnamedplus'

-- splitting
opt.splitright = true
opt.splitbelow = true

-- decrease update time
opt.updatetime = 250

-- decrease mapped sequence wait time
-- displays which-key popup sooner
opt.timeoutlen = 300

-- rounded borders in floating windows
-- vim.o.winborder = 'rounded'

-- highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- diagnostics
vim.diagnostic.config {
  -- Use the default configuration
  virtual_lines = true,

  -- Alternatively, customize specific options
  -- virtual_lines = {
  --  -- Only show virtual line diagnostics for the current cursor line
  --  current_line = true,
  -- },
}

-- file type detection
vim.filetype.add {
  pattern = { ['.*/hypr/.*%.conf'] = 'hyprlang' },
}
