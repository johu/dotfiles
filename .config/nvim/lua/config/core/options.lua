vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt

-- turn off swap files
opt.swapfile = false

-- line numbers
opt.relativenumber = true
opt.number = true

-- tabs & indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.autoindent = true
opt.wrap = false

-- search
opt.ignorecase = true
opt.smartcase = true
opt.cursorline = true
opt.iskeyword:append("-")

-- colors
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

-- keys
opt.backspace = "indent,eol,start"

-- clipboard
opt.clipboard:append("unnamedplus")

-- splitting
opt.splitright = true
opt.splitbelow = true
