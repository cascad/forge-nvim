local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local B = require('bootstrap')
local trace = require('trace')

-- Самопроверки trace (tests/lib/trace.lua и tests/trace.test.lua) на копии
-- дерева в .tests/trace-fixture/ (add-wezterm-spec-checks, задача 6.1).
-- Копия — только то, что trace читает; в ней по одному нарушению каждого
-- вида, и каждое должно дать своё нарушение с файлом и ID — не больше и не
-- меньше. Выдуманные ID здесь — данные (этот файл trace не сверяет, см.
-- tests/lib/trace.lua). Всё пишется только в .tests/trace-fixture/; копия
-- пересоздаётся при каждом прогоне.

local FIX = B.root .. '/.tests/trace-fixture'
local COPY = { 'openspec', 'tests', trace.CONFIG, trace.FIXLOG }

local function read(path)
  local f = assert(io.open(path, 'rb'))
  local s = f:read('*a')
  f:close()
  return s
end

local function write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local f = assert(io.open(path, 'wb'))
  f:write(content)
  f:close()
end

local function append(path, text)
  write(path, read(path) .. text)
end

local function copy_tree(src_root, dst_root, rel)
  local src = src_root .. '/' .. rel
  local st = vim.uv.fs_stat(src)
  if not st then return end
  if st.type == 'file' then
    vim.fn.mkdir(vim.fn.fnamemodify(dst_root .. '/' .. rel, ':h'), 'p')
    assert(vim.uv.fs_copyfile(src, dst_root .. '/' .. rel))
    return
  end
  for name, t in vim.fs.dir(src, { depth = 30 }) do
    if t == 'file' then
      local dst = dst_root .. '/' .. rel .. '/' .. name
      vim.fn.mkdir(vim.fn.fnamemodify(dst, ':h'), 'p')
      assert(vim.uv.fs_copyfile(src .. '/' .. name, dst))
    end
  end
end

-- Подпись нарушения без текста подробности: категория, файл, ID.
local function sig(v)
  return ('%s|%s|%s'):format(v.category, v.file, tostring(v.id))
end

local function sigs(res)
  local set = {}
  for _, v in ipairs(res.violations) do set[sig(v)] = v end
  return set
end

-- Мутации: ожидаемое нарушение и как его внести в копию. Поле proto — это
-- нарушение из списка задачи 6.1, его ищем и в выводе tests/trace.test.lua.
local SPEC = 'openspec/specs/wezterm-clipboard/spec.md'
local MUTANT_TEST = 'tests/wezterm/trace-mutant.test.lua'
local MUTANT_LIST = 'tests/manual/trace-mutant.md'
local MUTATIONS = {
  { category = 'ids_tests', file = MUTANT_TEST, id = 'WT-CLIP-99', proto = true },
  { category = 'ids_tags', file = trace.CONFIG, id = 'WT-XXX-1', proto = true },
  { category = 'untagged', file = trace.CONFIG, id = nil, proto = true },
  { category = 'proverka_paths', file = SPEC, id = nil, path = 'tests/nope.sh', proto = true },
  { category = 'unregistered', file = 'tests/x.test.lua', id = nil, proto = true },
  { category = 'ids_fixlog', file = trace.FIXLOG, id = 'WT-CLIP-98' },
  { category = 'ids_manual', file = MUTANT_LIST, id = 'WT-KEYS-97' },
  { category = 'manual_items', file = SPEC, id = nil, item = 'W99' },
}

local function mutate(root)
  -- ID первого требования спеки, куда вписываются строки `Проверка:`.
  local spec = read(root .. '/' .. SPEC)
  local req_id
  spec = spec:gsub('(### Requirement:%s+(%u+%-%u+%-%d+)[^\n]*\n)', function(header, id)
    if req_id then return header end
    req_id = id
    return header .. 'Проверка: tests/nope.sh\n'
      .. 'Проверка: вручную (' .. MUTANT_LIST .. ', W99)\n'
  end)
  assert(req_id, 'в ' .. SPEC .. ' нет требований')
  write(root .. '/' .. SPEC, spec)
  for _, m in ipairs(MUTATIONS) do
    if m.file == SPEC then m.id = req_id end
  end

  -- Тест с неизвестным ID, внесённый в реестр копии.
  write(root .. '/' .. MUTANT_TEST, table.concat({
    "local T = require('check')",
    "T.check('WT-CLIP-99 несуществующее требование', function() end)",
    'T.finish()', '',
  }, '\n'))
  local reg = read(root .. '/' .. trace.REGISTRY)
  local reg2, n = reg:gsub('}%s*$', "  { file = '" .. MUTANT_TEST .. "', suite = 'unit' },\n}\n")
  assert(n == 1, 'реестр копии не заканчивается на }')
  write(root .. '/' .. trace.REGISTRY, reg2)

  append(root .. '/' .. trace.CONFIG, '\n-- spec: WT-XXX-1\nmap("F24", "CTRL", act.Nop)\n')
  write(root .. '/tests/x.test.lua', '-- незарегистрированный файл проверок\n')
  append(root .. '/' .. trace.FIXLOG, '\nСпека: WT-CLIP-98 (FIX)\n')
  write(root .. '/' .. MUTANT_LIST, table.concat({
    '# Ручные проверки (мутант trace)', '',
    '## wezterm-key-ownership', '',
    '### W1 — известный и неизвестный ID', 'WT-KEYS-9, WT-KEYS-97',
    'Проверено: 2026-09-27, windows, WezTerm 20240203-110809-5046fc22, раскладка US — совпало', '',
  }, '\n'))
end

local BASE, MUTATED

T.check('SELF: project fixtures не suites, shell checks вне fixtures требуют реестр', function()
  T.eq(trace.is_check_file('tests/e2e/fixtures/bash-language/run.sh'), false)
  T.eq(trace.is_check_file('tests/e2e/fixtures/project/data.test.lua'), false)
  T.eq(trace.is_check_file('tests/new-check.sh'), true)
  T.eq(trace.is_check_file('tests/e2e/new-feature.test.lua'), true)
end)

T.check('SELF: копия дерева в .tests/trace-fixture собирается, trace на ней работает', function()
  vim.fn.delete(FIX, 'rf')
  for _, rel in ipairs(COPY) do copy_tree(B.root, FIX, rel) end
  T.ok(vim.uv.fs_stat(FIX .. '/' .. trace.REGISTRY), 'в копии нет реестра')
  BASE = trace.collect(FIX)
  T.eq(BASE.root, FIX)
end)

T.check('SELF: каждая мутация даёт своё нарушение с файлом и ID, других новых нет', function()
  T.ok(BASE, 'копия не собрана')
  mutate(FIX)
  MUTATED = trace.collect(FIX)
  local before, after = sigs(BASE), sigs(MUTATED)
  local new = {}
  for s in pairs(after) do
    if not before[s] then new[#new + 1] = s end
  end
  table.sort(new)
  local want = {}
  for _, m in ipairs(MUTATIONS) do want[#want + 1] = sig(m) end
  table.sort(want)
  T.eq(new, want, 'новые нарушения')
  for _, m in ipairs(MUTATIONS) do
    local v = after[sig(m)]
    if m.path then T.ok(v.detail:find(m.path, 1, true), sig(m) .. ': в подробности нет ' .. m.path) end
    if m.item then T.ok(v.detail:find(m.item, 1, true), sig(m) .. ': в подробности нет ' .. m.item) end
  end
end)

T.check('SELF: tests/trace.test.lua <копия> — FAIL на каждое нарушение из задачи, с файлом и ID, код 1', function()
  T.ok(MUTATED, 'мутации не внесены')
  local res = vim.system({ vim.v.progpath, '-l', B.root .. '/tests/trace.test.lua', FIX }, {
    text = true, timeout = 60000, cwd = B.root, env = { FORGE_REPO = B.root, FORGE_TEST_ID = '' },
  }):wait()
  T.eq(res.code, 1, 'код возврата (stderr: ' .. vim.trim(res.stderr or '') .. ')')
  local fails = {}
  for line in (res.stdout or ''):gsub('\r', ''):gmatch('[^\n]+') do
    if line:match('^  FAIL ') then fails[#fails + 1] = line end
  end
  for _, m in ipairs(MUTATIONS) do
    if m.proto then
      local hit
      for _, line in ipairs(fails) do
        if line:find(m.file, 1, true) and (not m.id or line:find(m.id, 1, true))
          and (not m.path or line:find(m.path, 1, true)) then
          hit = line
        end
      end
      T.ok(hit, ('нет строки FAIL с %s%s%s; FAIL-строки:\n%s'):format(m.file, m.id and (' и ' .. m.id) or '',
        m.path and (' и ' .. m.path) or '', table.concat(fails, '\n')))
    end
  end
end)

T.finish()
