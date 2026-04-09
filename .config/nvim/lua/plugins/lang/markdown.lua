require('render-markdown').setup {}
vim.cmd [[do FileType]]

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config-markdown-preview-map', { clear = true }),
  pattern = 'markdown',
  callback = function(event)
    vim.keymap.set('n', '<leader>cp', '<cmd>MarkdownPreviewToggle<cr>', {
      buffer = event.buf,
      desc = 'Markdown Preview',
    })
  end,
})
