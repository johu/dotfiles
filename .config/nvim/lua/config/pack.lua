local M = {}

local config_keymap_group = vim.api.nvim_create_augroup('config-pack-keys', { clear = true })

local function plugin_name(spec)
  local source = spec.name or spec.src
  if type(source) ~= 'string' then
    return nil
  end

  local name = source:match '([^/]+)$' or source
  return (name:gsub('%.git$', ''))
end

local function is_plugin_spec(value)
  if type(value) ~= 'table' then
    return false
  end

  if type(value[1]) == 'string' then
    if #value == 1 then
      return true
    end

    for key in pairs(value) do
      if type(key) ~= 'number' then
        return true
      end
    end

    return false
  end

  return value.src ~= nil
    or value.dependencies ~= nil
    or value.opts ~= nil
    or value.config ~= nil
    or value.keys ~= nil
    or value.event ~= nil
    or value.ft ~= nil
    or value.cmd ~= nil
    or value.main ~= nil
    or value.version ~= nil
    or value.branch ~= nil
    or value.enabled ~= nil
    or value.priority ~= nil
end

local function as_spec_list(value)
  if not is_plugin_spec(value) then
    return value
  end

  return { value }
end

local function normalize_spec(spec)
  if type(spec) == 'string' then
    return { src = spec }
  end

  local normalized = {}
  for key, value in pairs(spec) do
    if key ~= 1 then
      normalized[key] = value
    end
  end

  normalized.src = normalized.src or spec[1]
  return normalized
end

local function load_plugin_modules()
  local root = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'plugins')
  local files = {}

  vim.list_extend(files, vim.fn.globpath(root, '*.lua', false, true))
  vim.list_extend(files, vim.fn.globpath(root, '**/*.lua', false, true))
  table.sort(files)

  local modules, seen = {}, {}
  for _, file in ipairs(files) do
    if not seen[file] then
      seen[file] = true
      local relative = file:sub(#(vim.fs.joinpath(vim.fn.stdpath 'config', 'lua')) + 2)
      local module_name = relative:gsub('%.lua$', ''):gsub('/', '.')
      table.insert(modules, module_name)
    end
  end

  return modules
end

local function flatten_specs(specs, acc)
  for _, item in ipairs(as_spec_list(specs) or {}) do
    local spec = normalize_spec(item)
    table.insert(acc, spec)

    if spec.dependencies then
      flatten_specs(spec.dependencies, acc)
    end
  end
end

local function collect_specs()
  local raw_specs = {}

  for _, module_name in ipairs(load_plugin_modules()) do
    local ok, specs = pcall(require, module_name)
    if ok and specs then
      flatten_specs(specs, raw_specs)
    end
  end

  return raw_specs
end

local function is_enabled(spec)
  local enabled = spec.enabled
  if type(enabled) == 'function' then
    return enabled(spec)
  end

  return enabled ~= false
end

local function normalize_source(src)
  if type(src) ~= 'string' then
    return nil
  end

  if src:find '://' or src:match '^%a[%w+.-]*:' then
    return src
  end

  if src:match '^[^/]+/[^/]+$' then
    return ('https://github.com/%s.git'):format(src)
  end

  return nil
end

local function normalize_version(version)
  if type(version) ~= 'string' then
    return version
  end

  if version == '*' then
    return vim.version.range '*'
  end

  local major = version:match '^(%d+)%.%*$'
  if major then
    return vim.version.range(major)
  end

  return version
end

local function get_path(tbl, path)
  local value = tbl
  for segment in path:gmatch '[^%.]+' do
    if type(value) ~= 'table' then
      return nil
    end

    value = value[segment]
    if value == nil then
      return nil
    end
  end

  return value
end

local function set_path(tbl, path, value)
  local target = tbl
  local segments = vim.split(path, '.', { plain = true })

  for index = 1, #segments - 1 do
    local segment = segments[index]
    if type(target[segment]) ~= 'table' then
      target[segment] = {}
    end

    target = target[segment]
  end

  target[segments[#segments]] = value
end

local function merge_opts(base, addition, extend_paths)
  local merged = vim.tbl_deep_extend('force', {}, base, addition)

  for _, path in ipairs(extend_paths) do
    local left = get_path(base, path)
    local right = get_path(addition, path)
    if vim.islist(left) and vim.islist(right) then
      local value = vim.deepcopy(left)
      vim.list_extend(value, vim.deepcopy(right))
      set_path(merged, path, value)
    end
  end

  return merged
end

local function flatten_keys(record)
  local keys = {}

  for _, value in ipairs(record.keys_values) do
    local resolved = type(value) == 'function' and value(record) or value
    for _, mapping in ipairs(resolved or {}) do
      table.insert(keys, mapping)
    end
  end

  return keys
end

local function apply_keymap(mapping)
  local lhs = mapping[1]
  local rhs = mapping[2]
  if type(lhs) ~= 'string' or rhs == nil or rhs == '' then
    return
  end

  local positional_opts = type(mapping[3]) == 'table' and mapping[3] or {}
  local map_opts = vim.tbl_extend('force', {}, positional_opts)

  for _, key in ipairs { 'buffer', 'desc', 'expr', 'nowait', 'remap', 'replace_keycodes', 'silent', 'unique' } do
    if mapping[key] ~= nil then
      map_opts[key] = mapping[key]
    end
  end

  local ft = mapping.ft or map_opts.ft
  map_opts.ft = nil

  local mode = mapping.mode or map_opts.mode or 'n'
  map_opts.mode = nil

  if ft then
    vim.api.nvim_create_autocmd('FileType', {
      group = config_keymap_group,
      pattern = type(ft) == 'table' and ft or { ft },
      callback = function(event)
        local buffer_opts = vim.tbl_extend('force', {}, map_opts, { buffer = event.buf })
        vim.keymap.set(mode, lhs, rhs, buffer_opts)
      end,
    })
    return
  end

  vim.keymap.set(mode, lhs, rhs, map_opts)
end

local function derive_main(record)
  return (record.main or record.name):gsub('%.nvim$', '')
end

local function resolve_opts(record)
  local opts = {}

  for _, value in ipairs(record.opts_values) do
    if type(value) == 'function' then
      local result = value(record, opts)
      if result ~= nil then
        opts = result
      end
    elseif type(value) == 'table' then
      opts = merge_opts(opts, value, record.opts_extend)
    end
  end

  return opts
end

local function run_build(record)
  if record.build == nil then
    return
  end

  local build = record.build

  if type(build) == 'function' then
    build(record)
    return
  end

  vim.cmd.packadd(record.name)
  vim.cmd(build:sub(1, 1) == ':' and build:sub(2) or build)
end

local function create_commands()
  vim.api.nvim_create_user_command('PackUpdate', function(command)
    local names = vim.split(command.args, '%s+', { trimempty = true })
    vim.pack.update(#names > 0 and names or nil, { force = command.bang })
  end, {
    bang = true,
    nargs = '*',
  })
end

local function collect_records()
  local raw_specs = collect_specs()
  local base_names = {}

  for _, spec in ipairs(raw_specs) do
    local name = plugin_name(spec)
    if name and is_enabled(spec) and not spec.optional then
      base_names[name] = true
    end
  end

  local records = {}

  for _, spec in ipairs(raw_specs) do
    local name = plugin_name(spec)
    if name and is_enabled(spec) and (not spec.optional or base_names[name]) then
      local record = records[name] or {
        name = name,
        dependencies = {},
        init_hooks = {},
        config_hooks = {},
        opts_values = {},
        opts_extend = {},
        keys_values = {},
        priority = 0,
      }

      local source = normalize_source(spec.src)
      if source then
        record.src = source
      end

      if spec.name then
        record.name = spec.name
      end

      if record.version == nil then
        record.version = normalize_version(spec.version or spec.branch)
      end

      if record.main == nil then
        record.main = spec.main
      end

      if record.build == nil then
        record.build = spec.build
      end

      record.priority = math.max(record.priority, spec.priority or 0)

      if spec.init then
        table.insert(record.init_hooks, spec.init)
      end

      if spec.opts ~= nil then
        table.insert(record.opts_values, spec.opts)
      end

      if spec.config ~= nil then
        table.insert(record.config_hooks, spec.config)
      end

      if spec.keys ~= nil then
        table.insert(record.keys_values, spec.keys)
      end

      vim.list_extend(record.opts_extend, spec.opts_extend or {})

      for _, dependency in ipairs(as_spec_list(spec.dependencies) or {}) do
        local dep_name = plugin_name(normalize_spec(dependency))
        if dep_name then
          table.insert(record.dependencies, dep_name)
        end
      end

      records[name] = record
    end
  end

  return vim.tbl_values(records)
end

local function sort_records(records)
  table.sort(records, function(left, right)
    if left.priority ~= right.priority then
      return left.priority > right.priority
    end

    return left.name < right.name
  end)
end

function M.setup()
  local records = collect_records()
  sort_records(records)

  vim.api.nvim_create_autocmd('PackChanged', {
    group = vim.api.nvim_create_augroup('config-pack-build', { clear = true }),
    callback = function(event)
      local record = vim.iter(records):find(function(item)
        return item.name == event.data.spec.name
      end)

      if record and (event.data.kind == 'install' or event.data.kind == 'update') then
        run_build(record)
      end
    end,
  })

  for _, record in ipairs(records) do
    for _, init in ipairs(record.init_hooks) do
      init(record)
    end
  end

  create_commands()

  local pack_specs = {}
  for _, record in ipairs(records) do
    if record.src then
      table.insert(pack_specs, {
        src = record.src,
        name = record.name,
        version = record.version,
      })
    end
  end

  vim.pack.add(pack_specs, { confirm = false, load = false })

  for _, record in ipairs(records) do
    if record.src then
      vim.cmd.packadd(record.name)
    end
  end

  for _, record in ipairs(records) do
    local opts = resolve_opts(record)
    local configured = false

    for _, config in ipairs(record.config_hooks) do
      if config == true then
        local ok, module = pcall(require, derive_main(record))
        if ok and type(module.setup) == 'function' then
          module.setup(opts)
          configured = true
        end
      elseif type(config) == 'function' then
        config(record, opts)
        configured = true
      end
    end

    if not configured and next(record.opts_values) ~= nil then
      local ok, module = pcall(require, derive_main(record))
      if ok and type(module.setup) == 'function' then
        module.setup(opts)
      end
    end

    for _, mapping in ipairs(flatten_keys(record)) do
      apply_keymap(mapping)
    end
  end
end

return M
