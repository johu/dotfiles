-- highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

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
