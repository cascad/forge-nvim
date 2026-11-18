-- Трассировка «требование ↔ проверка» (add-wezterm-spec-checks, design,
-- решение 10): статические проверки висячих ссылок в дереве root.
--
--   local trace = require('trace')
--   local res = trace.collect(root)   -- root — корень репо или его копии
--   res.violations                    -- { {category, file, line, id, detail} } по порядку
--   res.by_category[key]              -- то же по категориям (trace.CATEGORIES)
--   res.checked[key]                  -- сколько объектов проверено (0 — нечего проверять)
--
-- Индекс ID — tests/lib/spec_index.lua (спеки + ADDED открытых changes; для
-- FIXLOG ещё и архив). Реестр — <root>/tests/registry.lua. Всё читается из
-- root и только из него: trace проверяет и копию дерева.
--
-- Что НЕ сверяется: самопроверки каркаса tests/lib/*.test.lua. Они держат
-- выдуманные ID как данные разбора (WT-AA-1, WT-CLIPX-1, мутанты trace);
-- проверки требований в tests/lib не кладутся.

local S = require('spec_index')

local M = {}

M.REGISTRY = 'tests/registry.lua'
M.FIXLOG = 'nvim_forge/FIXLOG.md'
M.CONFIG = 'wezterm.lua'

-- Порядок категорий = порядок вывода. none — причина SKIP, когда проверять нечего.
M.CATEGORIES = {
  { key = 'ids_tests', title = 'ID в файлах проверок известны', short = 'неизвестный ID в проверке',
    none = 'файлов проверок нет' },
  { key = 'ids_manual', title = 'ID в ручных чек-листах tests/manual/*.md известны', short = 'неизвестный ID в чек-листе',
    none = 'ручных чек-листов tests/manual/*.md нет (их заводит review-baseline)' },
  { key = 'ids_tags', title = 'ID в тегах `-- spec:` в wezterm.lua известны', short = 'неизвестный ID в теге -- spec:',
    none = 'в wezterm.lua нет тегов `-- spec:` (их расставляет restructure-wezterm-config)' },
  { key = 'untagged', title = 'у каждой записи привязки в wezterm.lua есть тег `-- spec:`', short = 'запись привязки без тега -- spec:',
    none = 'в wezterm.lua нет вызовов map(, mode_map(, mode_replace(' },
  { key = 'ids_fixlog', title = 'ID в строках `Спека:` FIXLOG известны', short = 'неизвестный ID в строке Спека:',
    none = 'в nvim_forge/FIXLOG.md нет строк `Спека:`' },
  { key = 'proverka_paths', title = 'пути tests/… в строках `Проверка:` есть и в реестре', short = 'висячий путь в строке Проверка:',
    none = 'в спеках нет строк `Проверка:` с путями tests/…' },
  { key = 'e2e_contracts', title = 'готовые и выбранные IDE contracts имеют registered E2E', short = 'нет обязательного E2E',
    none = 'IDE contracts в выбранной области отсутствуют' },
  { key = 'manual_items', title = 'пункты `вручную (tests/manual/…)` найдены в чек-листах', short = 'пункт вручную (…) не найден',
    none = 'в спеках нет ссылок `вручную (tests/manual/…)`' },
  { key = 'unregistered', title = 'файлы *.test.lua и *.sh в tests/ есть в реестре', short = 'файл вне реестра',
    none = 'в tests/ нет файлов *.test.lua и *.sh' },
}

-- ---------------------------------------------------------------------------
-- Чистые помощники
-- ---------------------------------------------------------------------------

--- Файл проверок (по имени).
function M.is_check_file(path)
  -- Fixtures — исходники проектов под тестом, их запускает editor E2E.
  -- Это не самостоятельные suites (в том числе Bash .sh/.test.lua data).
  if path:match('^tests/e2e/fixtures/') then return false end
  if path:match('^tests/containers/[^/]+%.sh$') then return false end
  return path:match('%.test%.lua$') ~= nil or path:match('%.sh$') ~= nil
end

--- Самопроверка каркаса: её ID — выдуманные данные, trace их не сверяет.
function M.is_harness_selftest(path)
  return path:match('^tests/lib/[^/]+%.test%.lua$') ~= nil
end

--- Хвост тега `-- spec: …` в строке Lua или nil.
function M.spec_tag(line)
  return line:match('%-%-%s*spec:%s*(.-)%s*$')
end

--- Строка wezterm.lua — запись привязки: вызов map(, mode_map( или
--- mode_replace( в начале строки (restructure-wezterm-config, design,
--- решение 7). Определения `local function map(` сюда не попадают.
M.BINDING_CALLS = { '^%s*map%(', '^%s*mode_map%(', '^%s*mode_replace%(' }
function M.is_binding_call(line)
  for _, p in ipairs(M.BINDING_CALLS) do
    if line:match(p) then return true end
  end
  return false
end

--- Хвост строки `Спека: …` FIXLOG (в начале строки, можно в `- `/`**`) или nil.
--- Упоминание формата в тексте (`` `Спека: <ID> …` ``) строкой не считается.
function M.fixlog_spec(line)
  return line:match('^%s*[%-%*]?%s*%**Спека:%**%s*(.-)%s*$')
end

--- Имя проверки для нарушения: одна строка, начинается не с ID (в сводку по ID
--- не попадает), содержит файл, строку и ID.
function M.name(v)
  local short
  for _, c in ipairs(M.CATEGORIES) do
    if c.key == v.category then short = c.short end
  end
  local where = v.file .. (v.line and (':' .. v.line) or '')
  return ('TRACE: %s — %s%s'):format(short or v.category, where, v.id and (' ' .. v.id) or '')
end

-- ---------------------------------------------------------------------------
-- Чтение дерева (только под root)
-- ---------------------------------------------------------------------------

local function norm(p)
  return (p:gsub('\\', '/'):gsub('/+$', ''))
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  return lines
end

-- Файлы под dir (пути от root), отсортированы.
local function walk(root, dir)
  local out = {}
  if not exists(root .. '/' .. dir) then return out end
  for name, t in vim.fs.dir(root .. '/' .. dir, { depth = 20 }) do
    if t == 'file' then out[#out + 1] = dir .. '/' .. (name:gsub('\\', '/')) end
  end
  table.sort(out)
  return out
end

local function registry_set(reg)
  local set = {}
  for _, e in ipairs(reg) do
    if type(e) == 'table' and type(e.file) == 'string' then set[e.file] = e end
  end
  return set
end

local function with_native(root,set)
  for _,file in ipairs(require('batch_plan').native_suites(root)) do
    assert(not set[file], 'Duplicate native test registration: '..file)
    set[file]={file=file,suite='e2e',kind='py',runner='native-python'}
  end
  return set
end

local function load_registry(root)
  local path = root .. '/' .. M.REGISTRY
  local ok, reg = pcall(dofile, path)
  if not ok then error(M.REGISTRY .. ' не загружается: ' .. tostring(reg), 0) end
  if type(reg) ~= 'table' then error(M.REGISTRY .. ' должен вернуть список', 0) end
  return with_native(root,registry_set(reg))
end

-- Каталог presence, не свидетельство runtime/OS PASS. Данные только из
-- existing specs/tasks/registry; незавершённое покрытие не становится готовым.
local function catalog(root, idx, registered, selected)
  local result = { requirements = {}, summary = { registered = 0, pending = 0, missing = 0 },
    registry = M.REGISTRY, change = selected }
  if selected and not idx.changes[selected] then
    result.selection_error = 'Неизвестный E2E change: ' .. selected
    return result
  end
  local completion = {}
  local function complete(change)
    if completion[change] ~= nil then return completion[change] end
    local total, unfinished = 0, 0
    for _, line in ipairs(read_lines(root .. '/openspec/changes/' .. change .. '/tasks.md') or {}) do
      local mark = line:match('^%s*[-*]%s*%[([^%]]*)%]')
      if mark then total = total + 1; if mark:lower() ~= 'x' then unfinished = unfinished + 1 end end
    end
    completion[change] = total > 0 and unfinished == 0
    return completion[change]
  end
  local function add(req)
    if not req.id:match('^IDE%-') or (selected and req.change ~= selected) then return end
    local ready = not req.change or complete(req.change)
    local row = { id = req.id, file = req.file, line = req.line, change = req.change,
      kind = req.kind, implementation_complete = ready, e2e = {}, paths = {}, runners = {} }
    local seen = {}
    for _, p in ipairs(req.proverka) do
      for _, path in ipairs(p.paths) do
        row.paths[#row.paths + 1] = path
        local entry, st = registered[path], vim.uv.fs_stat(root .. '/' .. path)
        if entry and entry.suite == 'e2e' and st and st.type == 'file' and not seen[path] then
          seen[path] = true; row.e2e[#row.e2e + 1] = path
          row.runners[path]=entry.runner or 'registry'
        end
      end
    end
    row.state = #row.e2e > 0 and 'REGISTERED' or ((ready or selected) and 'MISSING' or 'PENDING')
    local key = row.state:lower(); result.summary[key] = result.summary[key] + 1
    result.requirements[#result.requirements + 1] = row
  end
  for _, id in ipairs(idx.order) do add(idx.ids[id]) end
  for _, req in ipairs(idx.changed) do add(req) end
  return result
end

function M.catalog(root, index, registry)
  root = norm(root)
  return catalog(root, index or S.build(root), registry and with_native(root,registry_set(registry)) or load_registry(root))
end

-- ---------------------------------------------------------------------------
-- Сбор нарушений
-- ---------------------------------------------------------------------------

function M.collect(root, options)
  root = norm(root)
  local idx = S.build(root)
  local registered = load_registry(root)
  local res = { root = root, violations = {}, by_category = {}, checked = {} }
  for _, c in ipairs(M.CATEGORIES) do
    res.by_category[c.key] = {}
    res.checked[c.key] = 0
  end
  local function add(category, file, line, id, detail)
    local v = { category = category, file = file, line = line, id = id, detail = detail }
    res.violations[#res.violations + 1] = v
    table.insert(res.by_category[category], v)
  end
  local function count(category, n) res.checked[category] = res.checked[category] + (n or 1) end

  -- Неизвестные ID в тексте файла: области — из спек (WT, MAC), scope — индекс.
  local function scan_file(category, file, areas, scope, why)
    local lines = read_lines(root .. '/' .. file) or {}
    for n, line in ipairs(lines) do
      for _, id in ipairs(S.scan_ids(line, areas)) do
        if not idx:known(id, scope) then add(category, file, n, id, why) end
      end
    end
  end

  -- 1. Файлы проверок: зарегистрированные и все *.test.lua/*.sh в tests/.
  local tests_files = walk(root, 'tests')
  local check_files, seen = {}, {}
  for f in pairs(registered) do
    if not seen[f] and exists(root .. '/' .. f) then seen[f] = true; check_files[#check_files + 1] = f end
  end
  for _, f in ipairs(tests_files) do
    if M.is_check_file(f) and not seen[f] then seen[f] = true; check_files[#check_files + 1] = f end
  end
  table.sort(check_files)
  for _, f in ipairs(check_files) do
    if not M.is_harness_selftest(f) then
      count('ids_tests')
      scan_file('ids_tests', f, idx.areas, 'tests', 'нет в openspec/specs и в ADDED открытых changes')
    end
  end

  -- 2. Ручные чек-листы.
  for _, f in ipairs(walk(root, 'tests/manual')) do
    if f:match('%.md$') then
      count('ids_manual')
      scan_file('ids_manual', f, idx.areas, 'tests', 'нет в openspec/specs и в ADDED открытых changes')
    end
  end

  -- 3. Теги `-- spec:` в wezterm.lua: всё после `spec:` — ID, область любая.
  --    Запись привязки (M.is_binding_call) без тега — нарушение со строкой.
  for n, line in ipairs(read_lines(root .. '/' .. M.CONFIG) or {}) do
    local tag = M.spec_tag(line)
    if M.is_binding_call(line) then
      count('untagged')
      if not tag then add('untagged', M.CONFIG, n, nil, 'у записи нет `-- spec: <ID>`: ' .. vim.trim(line)) end
    end
    if tag then
      count('ids_tags')
      local ids = S.scan_ids(tag)
      if #ids == 0 then
        add('ids_tags', M.CONFIG, n, tag, 'в теге нет ID вида <ОБЛАСТЬ>-<ПРЕФИКС>-<n>')
      end
      for _, id in ipairs(ids) do
        if not idx:known(id, 'tests') then
          add('ids_tags', M.CONFIG, n, id, 'нет в openspec/specs и в ADDED открытых changes')
        end
      end
    end
  end

  -- 4. Строки `Спека:` FIXLOG: снятые ID (архив) тоже резолвятся.
  for n, line in ipairs(read_lines(root .. '/' .. M.FIXLOG) or {}) do
    local tail = M.fixlog_spec(line)
    if tail then
      count('ids_fixlog')
      for _, id in ipairs(S.scan_ids(tail)) do
        if not idx:known(id, 'fixlog') then
          add('ids_fixlog', M.FIXLOG, n, id, 'нет в openspec/specs, ADDED открытых changes и архиве')
        end
      end
    end
  end

  -- 5 и 6. Строки `Проверка:` спек: пути tests/… и пункты `вручную (…)`.
  local checklists = {}
  local function checklist(file)
    if checklists[file] == nil then
      local lines = read_lines(root .. '/' .. file)
      checklists[file] = lines and S.parse_checklist(table.concat(lines, '\n')) or false
    end
    return checklists[file]
  end
  local requirements = {}
  for _, id in ipairs(idx.order) do requirements[#requirements + 1] = idx.ids[id] end
  for _, req in ipairs(idx.changed) do
    if req.id:match('^IDE%-') then requirements[#requirements + 1] = req end
  end
  for _, req in ipairs(requirements) do
    local id = req.id
    for _, p in ipairs(req.proverka) do
      for _, path in ipairs(p.paths) do
        count('proverka_paths')
        if not exists(root .. '/' .. path) then
          add('proverka_paths', req.file, p.line, id, path .. ': нет такого файла')
        elseif not registered[path] then
          add('proverka_paths', req.file, p.line, id, path .. ': нет в ' .. M.REGISTRY)
        end
      end
      for _, m in ipairs(p.manual) do
        count('manual_items')
        local items = checklist(m.file)
        if not items then
          add('manual_items', req.file, p.line, id, m.file .. ': нет такого файла')
        elseif m.item then
          local found = false
          for _, it in ipairs(items) do
            if it.code == m.item then found = true end
          end
          if not found then add('manual_items', req.file, p.line, id, m.file .. ': нет пункта ' .. m.item) end
        end
      end
    end
  end

  res.catalog = catalog(root, idx, registered, options and options.change)
  if res.catalog.selection_error then
    count('e2e_contracts')
    add('e2e_contracts', 'openspec/changes/' .. options.change, nil, nil, res.catalog.selection_error)
  end
  for _, req in ipairs(res.catalog.requirements) do
    count('e2e_contracts')
    if req.state == 'MISSING' then
      add('e2e_contracts', req.file, req.line, req.id,
        'Нет registered E2E в Проверка: для готового/выбранного requirement; unit/manual не заменяют E2E')
    end
  end

  -- 7. Файлы проверок в tests/ вне реестра.
  for _, f in ipairs(tests_files) do
    if M.is_check_file(f) then
      count('unregistered')
      if not registered[f] then add('unregistered', f, nil, nil, 'нет в ' .. M.REGISTRY) end
    end
  end

  return res
end

return M
