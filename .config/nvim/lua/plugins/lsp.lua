local capabilities = require('blink.cmp').get_lsp_capabilities()

local servers = {
  gopls = {
    mason = 'gopls',
  },
  lua_ls = {
    mason = 'lua-language-server',
    settings = {
      Lua = {
        completion = {
          callSnippet = 'Replace',
        },
        diagnostics = { disable = { 'missing-fields' } },
      },
    },
  },
  marksman = {
    mason = 'marksman',
  },
}

local ensure_installed = vim.tbl_map(function(server)
  return server.mason
end, vim.tbl_values(servers))

vim.list_extend(ensure_installed, {
  'shellcheck',
  'shfmt',
  'stylua',
  'markdownlint-cli2',
  'markdown-toc',
  'prettier',
})

require('mason').setup {}
require('mason-tool-installer').setup { ensure_installed = ensure_installed }

vim.lsp.config('*', {
  capabilities = capabilities,
  root_markers = { '.git' },
})

for server_name, server in pairs(servers) do
  local config = vim.deepcopy(server)
  config.mason = nil
  vim.lsp.config(server_name, config)
end

vim.lsp.enable(vim.tbl_keys(servers))
