local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local B = require('bootstrap')
local trace = require('trace')

-- Трассировка «требование ↔ проверка» (add-wezterm-spec-checks, design,
-- решение 10; логика — tests/lib/trace.lua).
--
--   nvim -l tests/trace.test.lua             -- дерево репо
--   nvim -l tests/trace.test.lua <корень>    -- копия дерева (например, .tests/trace-fixture)
--
-- Каждое нарушение — отдельный FAIL: в имени файл, строка и ID. Категория без
-- нарушений — одна строка `ok`; категория, в которой проверять нечего, — SKIP
-- с причиной (не PASS). Имена начинаются с `TRACE:`, а не с ID: в сводку по ID
-- trace не попадает.

local target, change, catalog_json = B.root, nil, nil
local i, positional = 1, false
while arg and i <= #arg do
  local value = arg[i]
  if value == '--change' or value == '--catalog-json' then
    i = i + 1
    if not arg[i] or arg[i] == '' then error(value .. ' требует значение') end
    if value == '--change' then change = arg[i] else catalog_json = vim.fn.fnamemodify(arg[i], ':p') end
  elseif value:sub(1, 2) == '--' or positional then
    error('Неизвестный аргумент trace: ' .. value)
  else
    target = vim.fn.fnamemodify(value, ':p'):gsub('\\', '/'):gsub('/+$', '')
    positional = true
  end
  i = i + 1
end

local ok, res = pcall(trace.collect, target, { change = change })
if not ok then
  T.check('TRACE: индекс и реестр дерева ' .. target .. ' читаются', function() error(res, 0) end)
  T.finish()
end

if catalog_json then
  vim.fn.mkdir(vim.fs.dirname(catalog_json), 'p')
  vim.fn.writefile({ vim.json.encode(res.catalog) }, catalog_json)
end

for _, c in ipairs(trace.CATEGORIES) do
  local vs = res.by_category[c.key]
  if #vs > 0 then
    for _, v in ipairs(vs) do
      T.check(trace.name(v), function() error(v.detail, 0) end)
    end
  elseif res.checked[c.key] == 0 then
    T.skip('TRACE: ' .. c.title, c.none)
  else
    T.check('TRACE: ' .. c.title, function() end)
  end
end

for _, req in ipairs(res.catalog.requirements) do
  if req.state == 'PENDING' then
    T.skip('TRACE: E2E PENDING ' .. req.id .. ' — ' .. req.file, 'change не завершён; registered E2E ещё нет')
  end
end

T.finish()
