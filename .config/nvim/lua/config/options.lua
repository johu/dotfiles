vim.cmd 'let g:netrw_liststyle = 3'

local opt = vim.opt

-- turn off swap files
opt.swapfile = false

-- save undo history
opt.undofile = true
opt.undolevels = 10000

-- line numbers & sign column
opt.number = true
opt.relativenumber = true
opt.signcolumn = 'yes'

-- mode handled by status line
opt.showmode = false

-- mouse support (can be useful for resizing splits for example)
opt.mouse = 'a'

-- tabs & indentation
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.smarttab = true
opt.smartindent = true
opt.wrap = false
opt.breakindent = true

-- search & replace
opt.ignorecase = true
opt.smartcase = true
opt.cursorline = true
opt.iskeyword:append '-'
opt.inccommand = 'split'
opt.scrolloff = 10

-- completion
opt.completeopt = 'menu,menuone,noselect'

-- colors
opt.termguicolors = true
opt.background = 'dark'

-- keys
opt.backspace = 'indent,eol,start'

-- clipboard
-- only set clipboard if not in ssh, to make sure the OSC 52
-- integration works automatically.
opt.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus'

-- session
opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }

-- splitting
opt.splitright = true
opt.splitbelow = true

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

-- decrease update time
opt.updatetime = 200

-- decrease mapped sequence wait time
-- displays which-key popup sooner
opt.timeoutlen = 300

-- rounded borders in floating windows
-- vim.o.winborder = 'rounded'

-- spell checking
opt.spelllang = { 'en_us' }
opt.spell = true

-- highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
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

  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  },
  virtual_text = {
    source = 'if_many',
    spacing = 2,
    format = function(diagnostic)
      local diagnostic_message = {
        [vim.diagnostic.severity.ERROR] = diagnostic.message,
        [vim.diagnostic.severity.WARN] = diagnostic.message,
        [vim.diagnostic.severity.INFO] = diagnostic.message,
        [vim.diagnostic.severity.HINT] = diagnostic.message,
      }
      return diagnostic_message[diagnostic.severity]
    end,
  },
}

-- file type detection
vim.filetype.add {
  pattern = { ['.*/hypr/.*%.conf'] = 'hyprlang' },
}

-- markdown
local markdown_augroup = vim.api.nvim_create_augroup('Markdown', { clear = true })
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
  group = markdown_augroup,
  pattern = { '*.md' },
  callback = function()
    vim.bo.textwidth = 80
    vim.bo.formatoptions = 'tcqawjp]'
  end,
})
