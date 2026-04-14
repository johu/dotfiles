vim.cmd 'let g:netrw_liststyle = 3'

local opt = vim.opt

-- general
opt.number = true
opt.relativenumber = true
opt.signcolumn = 'yes'
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 10
opt.sidescrolloff = 8

-- indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smarttab = true
opt.autoindent = true
opt.smartindent = true
opt.breakindent = true

-- search & replace
opt.ignorecase = true
opt.smartcase = true
opt.iskeyword:append '-'
opt.incsearch = true
opt.inccommand = 'split'

-- Visual settings
opt.termguicolors = true
opt.background = 'dark'
opt.showmatch = true
opt.matchtime = 2
opt.cmdheight = 1
opt.showmode = false -- mode handled by status line
opt.pumheight = 10
opt.pumblend = 10
opt.winblend = 0
opt.completeopt = 'menu,menuone,noselect'
opt.conceallevel = 2
opt.confirm = true
opt.concealcursor = ''
opt.ruler = false
opt.virtualedit = 'block'
opt.winminwidth = 5

-- file handling
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undolevels = 10000
opt.ttimeoutlen = 0
opt.autoread = true
-- opt.autowrite = true

-- behavior
opt.hidden = true
opt.errorbells = false
opt.backspace = 'indent,eol,start'
opt.autochdir = false
opt.path:append '**'
opt.diffopt:append 'linematch:60'
opt.selection = 'exclusive'
opt.mouse = 'a' -- enable mouse support
opt.modifiable = true
opt.encoding = 'UTF-8'

-- clipboard
-- only set clipboard if not in ssh, to make sure the OSC 52
-- integration works automatically.
opt.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus'

-- folding
opt.smoothscroll = true
vim.wo.foldmethod = 'expr'
opt.foldlevel = 99 -- start with all folds open
opt.formatoptions = 'jcroqlnt'
opt.grepformat = '%f:%l:%c:%m'
opt.grepprg = 'rg --vimgrep'

-- splitting
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = 'screen'

-- command-line
opt.wildmenu = true
opt.wildmode = 'longest:full,full'
opt.wildignore:append { '*.o', '*.obj', '*.pyc', '*.class', '*.jar' }

-- whitespace characters
opt.list = true
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- fill characters
opt.fillchars = {
  foldopen = '',
  foldclose = '',
  fold = ' ',
  foldsep = ' ',
  diff = '╱',
  eob = ' ',
}

-- performance
opt.synmaxcol = 300
opt.updatetime = 300
opt.redrawtime = 10000
opt.maxmempattern = 20000

-- decrease mapped sequence wait time
-- displays which-key popup sooner
opt.timeoutlen = 300

-- rounded borders in floating windows
-- vim.o.winborder = 'rounded'

-- spell checking
opt.spelllang = { 'en_us' }
opt.spell = true

vim.g.autoformat = true
vim.g.trouble_lualine = true
vim.g.markdown_recommended_style = 0

opt.jumpoptions = 'view'
opt.laststatus = 3
opt.linebreak = true
opt.shiftround = true
-- opt.shortmess:append({ W = true, I = true, c = true, C = true })

-- file types
vim.filetype.add {
  pattern = { ['.*/hypr/.*%.conf'] = 'hyprlang' },
}

vim.filetype.add {
  extension = {
    env = 'dotenv',
  },
  filename = {
    ['.env'] = 'dotenv',
    ['env'] = 'dotenv',
  },
  pattern = {
    ['[jt]sconfig.*.json'] = 'jsonc',
    ['%.env%.[%w_.-]+'] = 'dotenv',
  },
}
