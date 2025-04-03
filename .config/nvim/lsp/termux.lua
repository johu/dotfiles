-- FIXME: doesn't work
-- approach with nvim-lspconfig:
-- https://github.com/termux/termux-language-server/issues/21
--
-- vim.api.nvim_create_autocmd({ 'BufEnter' }, {
--   pattern = { 'build.sh', '*.subpackage.sh', 'PKGBUILD', '*.install', 'makepkg.conf', '*.ebuild', '*.eclass', 'color.map', 'make.conf' },
--   callback = function()
--     vim.lsp.start {
--       name = 'termux',
--       cmd = { 'termux-language-server' },
--     }
--   end,
-- })

return {
  cmd = { 'termux-language-server' },
  filetypes = { 'ebuild', 'eclass' },
  root_markers = { '.git' },
}
