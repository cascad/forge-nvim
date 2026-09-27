-- Привязки nvim_forge без плагинов — сторона nvim межслойной проверки
-- WT-KEYS-4, WT-KEYS-6, WT-KEYS-7 (add-wezterm-spec-checks, design, решение 6).
--
--   local NK = require('nvim_keymaps')
--   local side = NK.collect{ root = B.root, sandbox = B.sandbox .. '/nvim', nvim = vim.v.progpath }
--   side.maps   -- { mode, lhs, keys, desc, rhs, noremap } — что nvim_forge поставил в таблицу привязок
--   side.lazy   -- { lhs, canon, keys, modes, desc, file, ft } — `keys` спек lazy.nvim, прочитанные dofile
--   side.errors -- что не загрузилось (пусто — всё загрузилось)
--
-- Как собирается. Отдельный процесс
--   nvim --clean --headless -i NONE -l tests/lib/nvim_keymaps.lua --child <корень>
-- с nvim_forge в runtimepath и лидером, как в nvim_forge/init.lua. В нём
-- снимается таблица привязок до и после config.ru_keys.setup(),
-- config.options, config.keymaps, config.wezterm_chords (порядок
-- nvim_forge/init.lua); привязки nvim_forge — то, что появилось
-- или поменялось (встроенные привязки nvim и его плагинов из --clean не
-- в счёт). Плагины (config.lazy) не грузятся — нет сети и живого
-- nvim_forge-data. Результат — одна строка stdout `FORGE_KEYMAPS_JSON {…}`.
--
-- Песочница. XDG_CONFIG/DATA/STATE/CACHE_HOME, NVIM_LOG_FILE и TEMP/TMP/TMPDIR
-- процесса указывают в `sandbox` (под .tests/), cwd — там же; результат
-- несёт stdpath() процесса, и проверка сверяет, что они в песочнице.
--
-- Ограничение (tests/README.md, «Межслойная проверка»): не видны
--   * буферные привязки (FileType, BufEnter и т.п.) и привязки из LspAttach;
--   * привязки из `config`/`opts`-функций плагинов (cmp: <C-Space>, <Tab> в
--     меню дополнения; telescope, neo-tree — внутри своих окон);
--   * `keys = function() … end` в спеках lazy (перечисляются в side.dynamic);
--   * то, что ставится в vim.schedule после загрузки.
-- Эта часть WT-KEYS-7 проверяется вручную.

local M = {}

M.MODES = { 'n', 'x', 's', 'o', 'i', 'c', 't', 'l' }
M.MARKER = 'FORGE_KEYMAPS_JSON '
M.SELF = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):gsub('\\', '/')

-- ---------------------------------------------------------------------------
-- Родитель: запуск процесса и разбор результата
-- ---------------------------------------------------------------------------

--- Окружение процесса: всё, что nvim может записать, — в песочнице.
function M.child_env(sandbox)
  local env = {
    XDG_CONFIG_HOME = sandbox .. '/config',
    XDG_DATA_HOME = sandbox .. '/data',
    XDG_STATE_HOME = sandbox .. '/state',
    XDG_CACHE_HOME = sandbox .. '/cache',
    TMPDIR = sandbox .. '/tmp',
    TEMP = sandbox .. '/tmp',
    TMP = sandbox .. '/tmp',
  }
  for _, d in pairs(env) do vim.fn.mkdir(d, 'p') end
  env.NVIM_APPNAME = 'nvim'
  env.NVIM_LOG_FILE = sandbox .. '/state/nvim.log'
  return env
end

--- Разобрать stdout процесса: строка с маркером → таблица. Нет строки — error.
function M.parse(stdout)
  for line in (stdout or ''):gmatch('[^\r\n]+') do
    if line:sub(1, #M.MARKER) == M.MARKER then
      return vim.json.decode(line:sub(#M.MARKER + 1), { luanil = { object = true, array = true } })
    end
  end
  error('nvim_keymaps: в выводе процесса нет строки ' .. vim.trim(M.MARKER), 0)
end

--- Собрать привязки nvim_forge. o: root (корень репо), sandbox (каталог под
--- .tests/), nvim (путь к nvim), timeout_ms (по умолчанию 30000).
--- Процесс упал, завис или не выдал результат — error с кодом и stderr.
function M.collect(o)
  assert(o and o.root and o.sandbox and o.nvim, 'nvim_keymaps.collect{ root, sandbox, nvim }')
  local cmd = { o.nvim, '--clean', '--headless', '-i', 'NONE', '-l', M.SELF, '--child', o.root }
  local ok, proc = pcall(vim.system, cmd, {
    cwd = o.sandbox, env = M.child_env(o.sandbox), text = true, timeout = o.timeout_ms or 30000,
  })
  if not ok then error('nvim_keymaps: не удалось запустить ' .. table.concat(cmd, ' ') .. ': ' .. tostring(proc), 0) end
  local res = proc:wait()
  local stderr = vim.trim((res.stderr or ''):gsub('\r', ''))
  if res.code ~= 0 then
    error(('nvim_keymaps: процесс вышел с кодом %s%s\n%s'):format(tostring(res.code),
      res.signal ~= 0 and (', сигнал ' .. tostring(res.signal)) or '', stderr), 0)
  end
  local pok, data = pcall(M.parse, res.stdout)
  if not pok then error(tostring(data) .. '\n' .. stderr, 0) end
  data.stderr = stderr
  return data
end

-- ---------------------------------------------------------------------------
-- Процесс: снять привязки (выполняется только при `-l … --child <корень>`)
-- ---------------------------------------------------------------------------

local function signature(m)
  return vim.inspect({
    m.rhs, m.desc, m.callback and tostring(m.callback), m.expr, m.noremap, m.silent,
    m.nowait, m.script, m.replace_keycodes,
  })
end

local function snapshot()
  local out = {}
  for _, mode in ipairs(M.MODES) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      out[mode .. '\0' .. m.lhs] = { mode = mode, lhs = m.lhs, desc = m.desc, rhs = m.rhs, noremap = m.noremap,
        sig = signature(m) }
    end
  end
  return out
end

-- Обход спеки lazy.nvim: список спек, вложенные спеки, dependencies.
local function walk_spec(spec, file, lazy, dynamic)
  if type(spec) ~= 'table' then return end
  if type(spec.keys) == 'function' then
    dynamic[#dynamic + 1] = { file = file, plugin = type(spec[1]) == 'string' and spec[1] or nil }
  elseif type(spec.keys) == 'table' then
    for _, k in ipairs(spec.keys) do
      local lhs = type(k) == 'table' and k[1] or k
      if type(lhs) == 'string' then
        local mode = type(k) == 'table' and k.mode or 'n'
        lazy[#lazy + 1] = {
          lhs = lhs, file = file,
          modes = type(mode) == 'table' and mode or { mode },
          desc = type(k) == 'table' and k.desc or nil,
          ft = type(k) == 'table' and k.ft or nil,
        }
      end
    end
  end
  for _, v in ipairs(spec) do walk_spec(v, file, lazy, dynamic) end
  if type(spec.dependencies) == 'table' then
    for _, d in ipairs(spec.dependencies) do walk_spec(d, file, lazy, dynamic) end
  end
end

local function child(root)
  local forge = root .. '/nvim_forge'
  local KN = dofile(root .. '/tests/lib/keynames.lua')
  -- Как nvim_forge/init.lua: лидер до загрузки привязок.
  vim.g.mapleader = ' '
  vim.g.maplocalleader = '\\'
  vim.opt.rtp:prepend(forge)

  local errors = {}
  local before = snapshot()
  for _, step in ipairs({
    { 'config.ru_keys', function() require('config.ru_keys').setup() end },
    { 'config.options', function() require('config.options') end },
    { 'config.keymaps', function() require('config.keymaps') end },
    { 'config.wezterm_chords', function() require('config.wezterm_chords').setup() end },
  }) do
    local ok, err = pcall(step[2])
    if not ok then errors[#errors + 1] = step[1] .. ': ' .. tostring(err) end
  end
  local after = snapshot()

  local maps = {}
  for id, m in pairs(after) do
    local b = before[id]
    if not b or b.sig ~= m.sig then
      maps[#maps + 1] = { mode = m.mode, lhs = m.lhs, keys = KN.split(m.lhs), desc = m.desc, rhs = m.rhs,
        noremap = m.noremap }
    end
  end
  table.sort(maps, function(a, b)
    if a.lhs ~= b.lhs then return a.lhs < b.lhs end
    return a.mode < b.mode
  end)

  local lazy, dynamic = {}, {}
  local files = vim.fn.glob(forge .. '/lua/plugins/*.lua', false, true)
  table.sort(files)
  for _, f in ipairs(files) do
    local name = 'nvim_forge/lua/plugins/' .. vim.fn.fnamemodify(f, ':t')
    local ok, spec = pcall(dofile, f)
    if ok then
      walk_spec(spec, name, lazy, dynamic)
    else
      errors[#errors + 1] = name .. ': ' .. tostring(spec)
    end
  end
  for _, k in ipairs(lazy) do
    local ok, c = pcall(KN.canon, k.lhs)
    if ok then
      k.canon, k.keys = c, KN.split(c)
    else
      errors[#errors + 1] = ('%s: lhs %q не разбирается: %s'):format(k.file, k.lhs, tostring(c))
    end
  end

  local out = {
    maps = maps, lazy = lazy, dynamic = dynamic, errors = errors,
    errmsg = vim.v.errmsg,
    stdpath = {
      config = vim.fn.stdpath('config'), data = vim.fn.stdpath('data'),
      state = vim.fn.stdpath('state'), cache = vim.fn.stdpath('cache'), log = vim.fn.stdpath('log'),
    },
    counts = { plugin_files = #files },
  }
  io.stdout:write(M.MARKER, vim.json.encode(out), '\n')
  io.stdout:flush()
end

if arg and arg[1] == '--child' and arg[0]
    and vim.fn.fnamemodify(arg[0], ':t') == 'nvim_keymaps.lua' then
  local ok, err = pcall(child, assert(arg[2], 'nvim_keymaps --child: нужен корень репо'))
  if not ok then
    io.stderr:write('nvim_keymaps: ', tostring(err), '\n')
    os.exit(1)
  end
  os.exit(0)
end

return M
