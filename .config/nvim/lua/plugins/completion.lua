require('blink.cmp').setup {
  keymap = {
    preset = 'enter',
    ['<C-y>'] = { 'select_and_accept' },
    ['<C-j>'] = { 'select_next', 'fallback' },
    ['<C-k>'] = { 'select_prev', 'fallback' },
  },
  appearance = {
    nerd_font_variant = 'mono',
  },
  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 200,
    },
  },
  cmdline = {
    completion = {
      ghost_text = { enabled = true },
    },
  },
  sources = {
    default = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev' },
    providers = {
      lazydev = {
        name = 'LazyDev',
        module = 'lazydev.integrations.blink',
        score_offset = 100,
      },
    },
  },
  signature = { enabled = true },
  fuzzy = { implementation = 'prefer_rust_with_warning' },
}
