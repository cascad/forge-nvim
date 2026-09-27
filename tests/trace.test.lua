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

local target = B.root
if arg and arg[1] and arg[1] ~= '' then
  target = (vim.fn.fnamemodify(arg[1], ':p'):gsub('\\', '/'):gsub('/+$', ''))
end

local ok, res = pcall(trace.collect, target)
if not ok then
  T.check('TRACE: индекс и реестр дерева ' .. target .. ' читаются', function() error(res, 0) end)
  T.finish()
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

T.finish()
