local function dashboard_startup_section()
  local started = vim.g.config_start_time or vim.uv.hrtime()
  local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
  local stats = { loaded = 0, count = 0 }

  local ok, plugins = pcall(vim.pack.get, nil, { info = false })
  if ok then
    stats.loaded = #plugins
    stats.count = #plugins
  end

  return {
    align = 'center',
    text = {
      { '⚡ Neovim loaded ', hl = 'footer' },
      { ('%d/%d'):format(stats.loaded, stats.count), hl = 'special' },
      { ' plugins in ', hl = 'footer' },
      { ('%.2fms'):format(elapsed_ms), hl = 'special' },
    },
  }
end

require('mini.icons').setup {
  file = {
    ['.keep'] = { glyph = '󰊢', hl = 'MiniIconsGrey' },
  },
  filetype = {
    dotenv = { glyph = '', hl = 'MiniIconsYellow' },
  },
}

require('snacks').setup {
  bigfile = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  indent = {
    enabled = true,
    char = '┊',
    animate = {
      enabled = false,
    },
  },
  dashboard = {
    preset = {
      keys = {
        { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
        { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
        { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
        { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
        { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
        { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' },
        { icon = '󰏔 ', key = 'p', desc = 'Plugins', action = ':PackUpdate' },
        { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
      },
    },
    sections = {
      {
        pane = 1,
        { section = 'header' },
        { icon = ' ', title = 'Keymaps', section = 'keys', indent = 2, padding = 1 },
        { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
        { icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
        dashboard_startup_section,
      },
    },
  },
}

require('bufferline').setup {
  options = {
    mode = 'tabs',
  },
}

require('lualine').setup {
  options = {
    theme = 'auto',
    globalstatus = vim.o.laststatus == 3,
    disabled_filetypes = { statusline = { 'snacks_dashboard' } },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = { 'filename' },
    lualine_x = { 'lsp_status', 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
}

require('which-key').setup {
  preset = 'helix',
  spec = {
    {
      mode = { 'n', 'v' },
      { '<leader><tab>', group = 'tabs' },
      { '<leader>c', group = 'code' },
      { '<leader>d', group = 'debug' },
      { '<leader>dp', group = 'profiler' },
      { '<leader>e', group = 'edit' },
      { '<leader>f', group = 'find' },
      { '<leader>g', group = 'git' },
      { '<leader>gh', group = 'hunks' },
      { '<leader>q', group = 'quit/session' },
      { '<leader>s', group = 'search' },
      { '<leader>u', group = 'ui', icon = { icon = '󰙵 ', color = 'cyan' } },
      { '<leader>x', group = 'diagnostics/quickfix', icon = { icon = '󱖫 ', color = 'green' } },
      { '[', group = 'prev' },
      { ']', group = 'next' },
      { 'g', group = 'goto' },
      { 'gs', group = 'surround' },
      { 'z', group = 'fold' },
      { '<BS>', desc = 'Decrement Selection', mode = 'x' },
      { '<Enter>', desc = 'Increment Selection', mode = { 'x', 'n' } },
      {
        '<leader>b',
        group = 'buffer',
        expand = function()
          return require('which-key.extras').expand.buf()
        end,
      },
      {
        '<leader>w',
        group = 'windows',
        proxy = '<c-w>',
        expand = function()
          return require('which-key.extras').expand.win()
        end,
      },
      { 'gx', desc = 'Open with system app' },
    },
  },
}

require('noice').setup {
  lsp = {
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      ['vim.lsp.util.stylize_markdown'] = true,
      ['cmp.entry.get_documentation'] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
    lsp_doc_border = false,
  },
}

vim.keymap.set('n', '<leader>n', function()
  if Snacks.config.picker and Snacks.config.picker.enabled then
    Snacks.picker.notifications()
  else
    Snacks.notifier.show_history()
  end
end, { desc = 'Notification History' })

vim.keymap.set('n', '<leader>un', function()
  Snacks.notifier.hide()
end, { desc = 'Dismiss All Notifications' })

vim.keymap.set('n', '<leader>?', function()
  require('which-key').show { global = false }
end, { desc = 'Buffer Local Keymaps (which-key)' })

vim.keymap.set('c', '<S-Enter>', function()
  require('noice').redirect(vim.fn.getcmdline())
end, { desc = 'Redirect Cmdline' })

vim.keymap.set('n', '<leader>snl', function()
  require('noice').cmd 'last'
end, { desc = 'Noice Last Message' })

vim.keymap.set('n', '<leader>snh', function()
  require('noice').cmd 'history'
end, { desc = 'Noice History' })

vim.keymap.set('n', '<leader>sna', function()
  require('noice').cmd 'all'
end, { desc = 'Noice All' })

vim.keymap.set('n', '<leader>snd', function()
  require('noice').cmd 'dismiss'
end, { desc = 'Dismiss All' })

vim.keymap.set('n', '<leader>snt', function()
  require('noice').cmd 'pick'
end, { desc = 'Noice Picker (Telescope/FzfLua)' })

vim.keymap.set({ 'i', 'n', 's' }, '<c-f>', function()
  if not require('noice.lsp').scroll(4) then
    return '<c-f>'
  end
end, { silent = true, expr = true, desc = 'Scroll Forward' })

vim.keymap.set({ 'i', 'n', 's' }, '<c-b>', function()
  if not require('noice.lsp').scroll(-4) then
    return '<c-b>'
  end
end, { silent = true, expr = true, desc = 'Scroll Backward' })
