local main = require('globals').main_monitor
-- local second = require('globals').second_monitor

hl.monitor {
  output = main,
  mode = '1920x1080@60',
  position = '0x0',
  scale = '1',
}

-- hl.monitor {
--   output = second,
--   mode = '2560x1440@60',
--   position = '2560x0',
--   scale = '1',
-- }
