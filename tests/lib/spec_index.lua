-- Индекс требований и ссылок «требование ↔ проверка» (add-wezterm-spec-checks,
-- design, решение 10). Читает:
--   * `### Requirement: <ID> …` из openspec/specs/*/spec.md — действующие ID;
--   * ADDED-требования открытых changes (openspec/changes/<id>/specs/*/spec.md);
--   * все требования из openspec/changes/archive/ — снятые ID остаются резолвимыми;
--   * строки `Проверка:` требований: пути `tests/…` и пункты `вручную (<файл>, <пункт>)`;
--   * ручные чек-листы tests/manual/*.md в формате review-baseline (его design,
--     решение 3; tasks 1.1): раздел `## <capability>`, пункт `### W<n>`/`### M<n>`,
--     ID требований в теле пункта, результат — строки `Проверено: …`, последняя
--     из них — текущий статус.
--
-- Разбор — чистые функции над текстом (parse_*); build(root) только читает
-- файлы под root и собирает их вместе. Корень — параметр: trace проверяет и
-- копию дерева.

local M = {}

-- ID: <ОБЛАСТЬ>-<ПРЕФИКС>-<n>. Область — первая часть ID из спек (WT, MAC).
M.ID_PATTERN = '%f[%w](%u+%-%u+%-%d+)%f[^%w]'

local function trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function lines_of(text)
  local out = {}
  text = text:gsub('\r\n', '\n')
  for line in (text .. '\n'):gmatch('([^\n]*)\n') do out[#out + 1] = line end
  return out
end

local function area_of(id)
  return id:match('^(%u+)%-')
end

--- ID-токены в тексте по порядку. areas — множество допустимых областей
--- (nil — любые).
function M.scan_ids(text, areas)
  local out = {}
  for id in text:gmatch(M.ID_PATTERN) do
    if areas == nil or areas[area_of(id)] then out[#out + 1] = id end
  end
  return out
end

--- Ведущие ID имени проверки: 'WT-KEYS-4 WT-KEYS-7 пересечение' → {WT-KEYS-4, WT-KEYS-7}.
--- ID в начале имени идут через пробел или запятую; 'WT-CLIP-1-b …' — вариант
--- случая WT-CLIP-1 (как у фильтра --id).
function M.leading_ids(name)
  local ids, pos = {}, 1
  while true do
    local s, e, id = name:find('^[%s,]*(%u+%-%u+%-%d+)', pos)
    if not s then break end
    local nextc = name:sub(e + 1, e + 1)
    if nextc == '-' then ids[#ids + 1] = id; break end
    if nextc ~= '' and not nextc:match('[%s,:]') then break end
    ids[#ids + 1] = id
    pos = e + 1
  end
  return ids
end

--- Разбор строки `Проверка:` (без префикса).
--- → { text, paths = {'tests/…'}, manual = {{file=, item=}}, manual_free = bool }
function M.parse_proverka(text)
  local res = { text = text, paths = {}, manual = {}, manual_free = false }
  local rest = text:gsub('вручную%s*(%b())', function(paren)
    local inner = paren:sub(2, -2)
    local parts = {}
    for p in inner:gmatch('[^,]+') do parts[#parts + 1] = trim(p) end
    local file = parts[1]
    if file and file:match('^tests/') then
      if #parts == 1 then
        res.manual[#res.manual + 1] = { file = file }
      end
      for i = 2, #parts do res.manual[#res.manual + 1] = { file = file, item = parts[i] } end
    else
      res.manual_free = true
    end
    return ' '
  end)
  if rest:find('вручную', 1, true) then res.manual_free = true end
  local seen = {}
  for p in rest:gmatch('tests/[%w%._%-/]+') do
    p = p:gsub('[%.,;:]+$', '')
    if not seen[p] then seen[p] = true; res.paths[#res.paths + 1] = p end
  end
  return res
end

--- Требования спеки: { {id, title, line, proverka = {разобранные строки}} }.
function M.parse_spec(text)
  local reqs, cur = {}, nil
  for n, line in ipairs(lines_of(text)) do
    local id, title = line:match('^### Requirement:%s+(%u+%-%u+%-%d+)%s*(.-)%s*$')
    if id then
      cur = { id = id, title = title, line = n, proverka = {} }
      reqs[#reqs + 1] = cur
    elseif line:match('^##%s') or line:match('^###%s') then
      cur = nil
    elseif cur then
      local p = line:match('^Проверка:%s*(.-)%s*$')
      if p then
        local parsed = M.parse_proverka(p)
        parsed.line = n
        cur.proverka[#cur.proverka + 1] = parsed
      end
    end
  end
  return reqs
end

--- Delta-спека change: ID по разделам ADDED / MODIFIED / REMOVED / RENAMED.
function M.parse_delta(text)
  local res = { added = {}, modified = {}, removed = {}, renamed = {} }
  local section
  for n, line in ipairs(lines_of(text)) do
    local sec = line:match('^##%s+(%u+)%s+Requirements')
    if sec then
      section = ({ ADDED = 'added', MODIFIED = 'modified', REMOVED = 'removed', RENAMED = 'renamed' })[sec]
    elseif line:match('^##%s') then
      section = nil
    elseif section then
      local id, title = line:match('^### Requirement:%s+(%u+%-%u+%-%d+)%s*(.-)%s*$')
      if not id and section == 'renamed' then
        id, title = line:match('^%-%s*TO:%s*`### Requirement:%s+(%u+%-%u+%-%d+)%s*(.-)`')
      end
      if not id and section == 'removed' then
        id = line:match('^### Requirement:%s+(%u+%-%u+%-%d+)')
      end
      if id then
        local list = res[section]
        list[#list + 1] = { id = id, title = title, line = n }
      end
    end
  end
  return res
end

--- Ручной чек-лист (формат review-baseline): пункты `### <КОД>`.
--- → { {code, title, line, capability, ids = {…}, verified = {строки}, last = строка|nil} }
function M.parse_checklist(text)
  local items, cur, capability = {}, nil, nil
  for n, line in ipairs(lines_of(text)) do
    local cap = line:match('^##%s+([^#].-)%s*$')
    local code, title = line:match('^###%s+(%u+%d+)%f[^%w](.-)%s*$')
    if code then
      title = title:gsub('^%s*—%s*', ''):gsub('^%s*[%-:.]%s*', ''):gsub('^%s+', '')
      cur = { code = code, title = title, line = n, capability = capability, ids = {}, verified = {}, _seen = {} }
      items[#items + 1] = cur
    elseif cap then
      capability, cur = cap, nil
    elseif cur then
      local v = line:match('^%s*[%-%*]?%s*Проверено:%s*(.-)%s*$')
      if v then
        cur.verified[#cur.verified + 1] = v
        cur.last = v
      else
        for _, id in ipairs(M.scan_ids(line)) do
          if not cur._seen[id] then cur._seen[id] = true; cur.ids[#cur.ids + 1] = id end
        end
      end
    end
  end
  for _, it in ipairs(items) do it._seen = nil end
  return items
end

-- ---------------------------------------------------------------------------
-- Сборка индекса по дереву
-- ---------------------------------------------------------------------------

local function read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  return table.concat(lines, '\n')
end

local function list(dir, want_dir)
  local out = {}
  local h = vim.uv.fs_scandir(dir)
  if not h then return out end
  while true do
    local name, t = vim.uv.fs_scandir_next(h)
    if not name then break end
    if (want_dir and t == 'directory') or (not want_dir and t ~= 'directory') then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

--- Индекс для дерева root.
function M.build(root)
  root = root:gsub('\\', '/'):gsub('/+$', '')
  local idx = {
    root = root,
    ids = {},        -- ID → { id, title, capability, file, line, proverka }
    order = {},      -- ID из openspec/specs по порядку: capability, затем номер
    areas = {},      -- множество областей (WT, MAC)
    added = {},      -- ID → { id, title, change, file } — ADDED открытых changes
    archived = {},   -- ID → { id, change, file }
    path_refs = {},  -- 'tests/…' → { ID… } из строк `Проверка:`
    manual = { present = false, files = {}, by_id = {} },
  }

  -- Действующие требования.
  local specs_dir = root .. '/openspec/specs'
  for _, cap in ipairs(list(specs_dir, true)) do
    local file = 'openspec/specs/' .. cap .. '/spec.md'
    local text = read(root .. '/' .. file)
    if text then
      for _, req in ipairs(M.parse_spec(text)) do
        req.capability, req.file = cap, file
        if not idx.ids[req.id] then idx.order[#idx.order + 1] = req.id end
        idx.ids[req.id] = req
        idx.areas[area_of(req.id)] = true
        for _, p in ipairs(req.proverka) do
          for _, path in ipairs(p.paths) do
            idx.path_refs[path] = idx.path_refs[path] or {}
            table.insert(idx.path_refs[path], req.id)
          end
        end
      end
    end
  end

  -- Открытые changes: ADDED-требования.
  local changes_dir = root .. '/openspec/changes'
  for _, change in ipairs(list(changes_dir, true)) do
    if change ~= 'archive' then
      for _, cap in ipairs(list(changes_dir .. '/' .. change .. '/specs', true)) do
        local file = 'openspec/changes/' .. change .. '/specs/' .. cap .. '/spec.md'
        local text = read(root .. '/' .. file)
        if text then
          for _, r in ipairs(M.parse_delta(text).added) do
            idx.added[r.id] = { id = r.id, title = r.title, change = change, file = file }
            idx.areas[area_of(r.id)] = true
          end
        end
      end
    end
  end

  -- Архив: все требования, упомянутые в delta заархивированных changes.
  local arch_dir = changes_dir .. '/archive'
  for _, change in ipairs(list(arch_dir, true)) do
    for _, cap in ipairs(list(arch_dir .. '/' .. change .. '/specs', true)) do
      local file = 'openspec/changes/archive/' .. change .. '/specs/' .. cap .. '/spec.md'
      local text = read(root .. '/' .. file)
      if text then
        for id in text:gmatch('### Requirement:%s+(%u+%-%u+%-%d+)') do
          idx.archived[id] = idx.archived[id] or { id = id, change = change, file = file }
        end
      end
    end
  end

  -- Ручные чек-листы.
  for _, name in ipairs(list(root .. '/tests/manual', false)) do
    if name:match('%.md$') then
      local file = 'tests/manual/' .. name
      local items = M.parse_checklist(read(root .. '/' .. file) or '')
      idx.manual.present = true
      idx.manual.files[file] = items
      for _, it in ipairs(items) do
        for _, id in ipairs(it.ids) do
          idx.manual.by_id[id] = idx.manual.by_id[id] or {}
          table.insert(idx.manual.by_id[id], { file = file, item = it.code, last = it.last })
        end
      end
    end
  end

  -- Ссылки `вручную (tests/manual/<файл>, <пункт>)` из спек тоже дают MANUAL.
  for _, id in ipairs(idx.order) do
    for _, p in ipairs(idx.ids[id].proverka) do
      for _, m in ipairs(p.manual) do
        local last
        for _, it in ipairs(idx.manual.files[m.file] or {}) do
          if it.code == m.item then last = it.last end
        end
        local list_ = idx.manual.by_id[id] or {}
        local dup = false
        for _, e in ipairs(list_) do
          if e.file == m.file and e.item == m.item then dup = true end
        end
        if not dup then
          list_[#list_ + 1] = { file = m.file, item = m.item, last = last, from_spec = true }
        end
        idx.manual.by_id[id] = list_
      end
    end
  end

  return setmetatable(idx, { __index = M })
end

--- Известен ли ID. scope: 'tests' (спеки + ADDED открытых changes, по
--- умолчанию) или 'fixlog' (плюс архив).
function M.known(idx, id, scope)
  if idx.ids[id] or idx.added[id] then return true end
  if scope == 'fixlog' and idx.archived[id] then return true end
  return false
end

return M
