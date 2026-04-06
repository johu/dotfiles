vim.g.config_start_time = vim.uv.hrtime()

require 'config.options'
require 'config.keymaps'
require('config.pack').setup()
require 'config.lsp'
