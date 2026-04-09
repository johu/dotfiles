local lint = require 'lint'

lint.linters_by_ft = {
  markdown = { 'markdownlint-cli2' },
}

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  group = vim.api.nvim_create_augroup('lint', { clear = true }),
  callback = function()
    lint.try_lint()
  end,
})

vim.keymap.set('n', '<leader>l', function()
  lint.try_lint()
end, { desc = 'Trigger linting for current file' })
