return {
  cmd = { 'gopls' },
  filetypes = { 'go', 'gomod', 'gosum', 'gotmpl' },
  root_markers = {
    'go.mod',
    'go.sum',
  },
  settings = {
    gopls = {
      completeUnimported = true,
      usePlaceholders = true,
      staticcheck = true,
      gofumpt = true,
      semanticTokens = true,
      analyses = {
        unusedparams = true,
        fieldalignment = true,
        inferTypeArgs = true,
      },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}
