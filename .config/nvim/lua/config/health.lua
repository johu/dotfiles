local start = vim.health.start
local ok = vim.health.ok
local info = vim.health.info
local warn = vim.health.warn
local error = vim.health.error

local check_version = function()
  local fmt_ver = function(v)
    return string.format('%s.%s.%s', v[1], v[2], v[3])
  end

  local v1 = { vim.version().major, vim.version().minor, vim.version().patch }
  local v2 = { 0, 11, 0 }
  if vim.version.ge(v1, v2) then
    ok(('Neovim version is: %s (>=%s is required)'):format(fmt_ver(v1), fmt_ver(v2)))
  else
    error(('Neovim version is out of date: %s (>=%s is required)'):format(fmt_ver(v1), fmt_ver(v2)))
  end
end

local check_external_reqs = function()
  for _, cmd in ipairs { 'git', 'make', 'unzip', 'curl', 'rg', 'fzf', { 'fd', 'fdfind' } } do
    local name = type(cmd) == 'string' and cmd or vim.inspect(cmd)
    local commands = type(cmd) == 'string' and { cmd } or cmd
    ---@cast commands string[]
    local found = false

    for _, c in ipairs(commands) do
      if vim.fn.executable(c) == 1 then
        name = c
        found = true
      end
    end

    if found then
      ok(("'%s' is installed"):format(name))
    else
      warn(("'%s' is not installed"):format(name))
    end
  end

  return true
end

return {
  check = function()
    start 'config'

    local uv = vim.uv or vim.loop
    info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
  end,
}
