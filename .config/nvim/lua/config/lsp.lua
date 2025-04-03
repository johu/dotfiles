-- TODO:  custom keybinds
--
--   config = function()
--     vim.api.nvim_create_autocmd('LspAttach', {
--       group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
--       callback = function(event)
--         local map = function(keys, func, desc, mode)
--           mode = mode or 'n'
--           vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
--         end
--         map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
--         map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
--         map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
--         map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
--         map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
--         map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
--         map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
--         map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
--         map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
--
--         local client = vim.lsp.get_client_by_id(event.data.client_id)
--         if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
--           local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
--           vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
--             buffer = event.buf,
--             group = highlight_augroup,
--             callback = vim.lsp.buf.document_highlight,
--           })
--
--           vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
--             buffer = event.buf,
--             group = highlight_augroup,
--             callback = vim.lsp.buf.clear_references,
--           })
--
--           vim.api.nvim_create_autocmd('LspDetach', {
--             group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
--             callback = function(event2)
--               vim.lsp.buf.clear_references()
--               vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
--             end,
--           })
--         end
--
--         if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
--           map('<leader>th', function()
--             vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
--           end, '[T]oggle Inlay [H]ints')
--         end
--       end,
--     })

local capabilities = {
  textDocument = {
    foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    },
  },
}

capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)

vim.lsp.config('*', {
  capabilities = capabilities,
  root_markers = { '.git' },
})

-- enable LSP server, see lsp/ for available server
vim.lsp.enable {
  -- 'bashls',
  'gopls',
  'luals',
  'marksman',
  -- 'termux',
}

local markdown_augroup = vim.api.nvim_create_augroup('Markdown', { clear = true })
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
  group = markdown_augroup,
  pattern = { '*.md' },
  callback = function()
    vim.bo.textwidth = 80
    vim.bo.formatoptions = 'tcqawjp]'
  end,
})
