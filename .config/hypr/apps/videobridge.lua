-- xwaylandvideobridge: keep its helper window invisible and out of the way
hl.window_rule {
  match = { class = '^xwaylandvideobridge$' },
  opacity = '0.0 override',
  no_anim = true,
  no_initial_focus = true,
  no_focus = true,
  max_size = '1 1',
  no_blur = true,
}
