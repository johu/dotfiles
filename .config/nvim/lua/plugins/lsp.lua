return {
  -- main LSP configuration
  {
    'neovim/nvim-lspconfig',
    event = 'VeryLazy',
    dependencies = {
      'saghen/blink.cmp',
      { 'mason-org/mason.nvim', opts = {} },
      'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    config = function()
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
        -- bash
        'shellcheck',
        'shfmt',
        -- lua
        'stylua',
        -- markdown
        'markdownlint-cli2',
        'markdown-toc',
        -- web stack (html,css,js,yaml,json and more)
        'prettier',
      })
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
    end,
  },
}
