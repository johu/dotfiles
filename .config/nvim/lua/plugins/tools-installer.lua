return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      },
    },
  },
  { 'Bilal2453/luvit-meta', lazy = true },
  {
    'williamboman/mason.nvim',
    dependencies = {
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      require('mason').setup()

      local servers = {
        --
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        -- bash
        'bash-language-server',
        'shellcheck',
        'shfmt',
        -- bash derivates like gentoo ebuilds
        'termux-language-server',
        -- go
        'gopls',
        -- lua
        'lua-language-server',
        'stylua',
        -- markdown
        'marksman',
        'markdownlint-cli2',
        'markdown-toc',
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }
    end,
  },
}
