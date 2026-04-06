if vim.fn.has 'nvim-0.12.0' == 0 then
  vim.api.nvim_echo({
    { 'This configuration requires Neovim >= 0.12.0\n', 'ErrorMsg' },
    { 'Press any key to exit', 'MoreMsg' },
  }, true, {})
  vim.fn.getchar()
  vim.cmd [[quit]]
  return {}
end

return {}
