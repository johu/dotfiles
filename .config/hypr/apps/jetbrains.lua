-- Disable mouse focus
hl.window_rule {
  name = 'jetbrains-focus',
  match = { class = '^(jetbrains-.*)$' },
  no_follow_mouse = true,
}
