local check_version = function()
  local fmt_ver = function(v)
    return string.format('%s.%s.%s', v[1], v[2], v[3])
  end

  local v1 = { vim.version().major, vim.version().minor, vim.version().patch }
  local v2 = { 0, 9, 5 }
  if vim.version.ge(v1, v2) then
    vim.health.ok(string.format('Neovim version is: %s (>=%s is required)', fmt_ver(v1), fmt_ver(v2)))
  else
    vim.health.error(string.format('Neovim version is out of date: %s (>=%s is required)', fmt_ver(v1), fmt_ver(v2)))
  end
end

local check_external_reqs = function()
  for _, exe in ipairs { 'git', 'make', 'unzip', 'rg' } do
    local is_executable = vim.fn.executable(exe) == 1
    if is_executable then
      vim.health.ok(string.format("Found executable: '%s'", exe))
    else
      vim.health.warn(string.format("Could not find executable: '%s'", exe))
    end
  end

  return true
end

return {
  check = function()
    vim.health.start 'config'

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
  end,
}
