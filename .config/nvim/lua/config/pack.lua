local M = {}

local function create_pack_commands()
  vim.api.nvim_create_user_command('PackUpdate', function(command)
    local names = vim.split(command.args, '%s+', { trimempty = true })
    vim.pack.update(#names > 0 and names or nil, { force = command.bang })
  end, {
    bang = true,
    nargs = '*',
  })
end

local function create_pack_hooks()
  vim.api.nvim_create_autocmd('PackChanged', {
    group = vim.api.nvim_create_augroup('config-pack-hooks', { clear = true }),
    callback = function(event)
      local name, kind = event.data.spec.name, event.data.kind
      if kind ~= 'install' and kind ~= 'update' then
        return
      end

      if name == 'nvim-treesitter' then
        if not event.data.active then
          vim.cmd.packadd 'nvim-treesitter'
        end
        vim.cmd 'TSUpdate'
        return
      end

      if name == 'markdown-preview.nvim' then
        if not event.data.active then
          vim.cmd.packadd 'markdown-preview.nvim'
        end
        vim.fn['mkdp#util#install']()
      end
    end,
  })
end

local function prepare_startup()
  package.preload['nvim-web-devicons'] = function()
    require('mini.icons').mock_nvim_web_devicons()
    return package.loaded['nvim-web-devicons']
  end

  vim.g.lualine_laststatus = vim.o.laststatus
  if vim.fn.argc(-1) > 0 then
    vim.o.statusline = ' '
  else
    vim.o.laststatus = 0
  end
end

local function require_modules()
  local modules = {
    'plugins.colorscheme',
    'plugins.completion',
    'plugins.util',
    'plugins.lsp',
    'plugins.syntax',
    'plugins.editor',
    'plugins.navigation',
    'plugins.formatting',
    'plugins.linting',
    'plugins.ui',
    'plugins.lang.markdown',
  }

  for _, module in ipairs(modules) do
    require(module)
  end
end

function M.setup()
  if vim.fn.has 'nvim-0.12.0' == 0 then
    vim.api.nvim_echo({
      { 'This configuration requires Neovim >= 0.12.0\n', 'ErrorMsg' },
      { 'Press any key to exit', 'MoreMsg' },
    }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
    return
  end

  create_pack_commands()
  create_pack_hooks()
  prepare_startup()

  vim.pack.add(require 'config.plugins', { confirm = false, load = true })
  require_modules()
end

return M
