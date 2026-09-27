-- Построчный протокол проверок (add-wezterm-spec-checks, design, решение 2).
--
--   local T = require('check')
--   T.check('WT-CLIP-2 Ctrl+C без выделения уходит в программу', function()
--     T.eq(actual, expected, 'что сравниваем')
--   end)
--   T.skip('WT-KBD-2 nvim получает <C-.>', 'MANUAL: кодировщик клавиш WezTerm')
--   T.finish()
--
-- Строки вывода — те же, что у tests/install-macos.scenarios.sh:
--   '  ok   <имя>'
--   '  FAIL <имя>  -- <подробность>'   (продолжение подробности — строки '      | …')
--   '  SKIP <имя>  -- <причина>'
-- Имя проверки начинается с ID требования. Фильтр FORGE_TEST_ID=<ID>
-- пропускает случаи, чьё имя не равно ID и не начинается с '<ID>-' или '<ID> '.
-- finish() печатает итог и выходит с кодом 1, если был хотя бы один FAIL.
--
-- require('check') отдаёт экземпляр, собранный из настоящего окружения
-- (stdout, stderr, os.exit, FORGE_TEST_ID). T.new{ out, err, exit, filter }
-- собирает экземпляр с подставными стоками — для самопроверок протокола.

local M = {}

-- ---------------------------------------------------------------------------
-- Чистые помощники
-- ---------------------------------------------------------------------------

--- Совпадает ли имя проверки с фильтром --id / FORGE_TEST_ID.
--- 'WT-CLIP' берёт всю capability, 'WT-CLIP-1' не захватывает 'WT-CLIP-10'.
function M.matches(name, id)
  if id == nil or id == '' then return true end
  if name == id then return true end
  if name:sub(1, #id) ~= id then return false end
  local nextc = name:sub(#id + 1, #id + 1)
  return nextc == '-' or nextc == ' '
end

local function fmt(v)
  if type(v) == 'string' then return (string.format('%q', v):gsub('\\\n', '\\n')) end
  if type(v) == 'table' and vim and vim.inspect then
    return (vim.inspect(v, { newline = ' ', indent = '' }))
  end
  return tostring(v)
end

local function join_path(path, k)
  if type(k) == 'string' and k:match('^[%a_][%w_]*$') then return path .. '.' .. k end
  return path .. '[' .. fmt(k) .. ']'
end

local function key_order(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  if ta == 'number' or ta == 'string' then return a < b end
  return tostring(a) < tostring(b)
end

local function collect_diff(a, b, path, out, seen, limit)
  if #out >= limit or rawequal(a, b) then return end
  if type(a) ~= 'table' or type(b) ~= 'table' then
    out[#out + 1] = ('%s: получено %s, ожидалось %s'):format(path == '' and '(значение)' or path, fmt(a), fmt(b))
    return
  end
  seen[a] = seen[a] or {}
  if seen[a][b] then return end
  seen[a][b] = true
  local keys, have = {}, {}
  for k in pairs(a) do if not have[k] then have[k] = true; keys[#keys + 1] = k end end
  for k in pairs(b) do if not have[k] then have[k] = true; keys[#keys + 1] = k end end
  table.sort(keys, key_order)
  for _, k in ipairs(keys) do
    collect_diff(a[k], b[k], join_path(path, k), out, seen, limit)
    if #out >= limit then return end
  end
end

--- Список расхождений actual против expected (глубокое сравнение таблиц,
--- метатаблицы не сравниваются, функции — по идентичности).
function M.diff(actual, expected, limit)
  local out = {}
  collect_diff(actual, expected, '', out, {}, limit or 20)
  return out
end

--- Глубокое равенство.
function M.equal(a, b)
  return #M.diff(a, b, 1) == 0
end

--- Утверждение: глубокое равенство, иначе ошибка с читаемым diff.
function M.eq(actual, expected, msg)
  local d = M.diff(actual, expected, 20)
  if #d > 0 then
    error(((msg and (msg .. ': ')) or '') .. 'не равно\n' .. table.concat(d, '\n'), 2)
  end
end

--- Утверждение: условие истинно.
function M.ok(cond, msg)
  if not cond then error(msg or 'условие не выполнено', 2) end
  return cond
end

local function error_text(e)
  if type(e) == 'string' then return e end
  return fmt(e)
end

local function one_line(s)
  return (tostring(s):gsub('[\r\n]+', ' | '))
end

-- ---------------------------------------------------------------------------
-- Экземпляр: счётчики, вывод, код возврата
-- ---------------------------------------------------------------------------

--- opts.out(line)   — вывод строки протокола (по умолчанию stdout);
--- opts.err(text)   — диагностика, в протокол не входит (по умолчанию stderr);
--- opts.exit(code)  — завершение (по умолчанию os.exit);
--- opts.filter      — ID из FORGE_TEST_ID или nil.
function M.new(opts)
  opts = opts or {}
  local out = opts.out or function(line)
    io.stdout:write(line, '\n')
    io.stdout:flush()
  end
  local err = opts.err or function(text) io.stderr:write(text, '\n') end
  local exit = opts.exit or os.exit
  local filter = opts.filter
  if filter == '' then filter = nil end

  local T = setmetatable({
    filter = filter,
    counts = { ok = 0, fail = 0, skip = 0 },
    results = {},
  }, { __index = M })

  local function record(status, name, detail)
    T.results[#T.results + 1] = { status = status, name = name, detail = detail }
  end

  local function check_name(name)
    if type(name) ~= 'string' or name == '' or name:find('[\r\n]') then
      error('check: имя проверки — непустая строка в одну строку, получено ' .. fmt(name), 3)
    end
  end

  function T.check(name, fn)
    check_name(name)
    if not M.matches(name, filter) then return end
    local tb
    local ok, e = xpcall(fn, function(x)
      tb = debug.traceback(error_text(x), 2)
      return x
    end)
    if ok then
      T.counts.ok = T.counts.ok + 1
      record('ok', name)
      out('  ok   ' .. name)
      return true
    end
    T.counts.fail = T.counts.fail + 1
    local text = error_text(e)
    local first, rest = text:match('^([^\n]*)\n?(.*)$')
    record('FAIL', name, text)
    out('  FAIL ' .. name .. '  -- ' .. first)
    for line in rest:gmatch('[^\n]+') do out('      | ' .. line) end
    err('FAIL ' .. name .. '\n' .. (tb or text))
    return false
  end

  function T.skip(name, reason)
    check_name(name)
    if not M.matches(name, filter) then return end
    T.counts.skip = T.counts.skip + 1
    local r = one_line(reason or 'причина не указана')
    record('SKIP', name, r)
    out('  SKIP ' .. name .. '  -- ' .. r)
  end

  function T.finish()
    local c = T.counts
    out('')
    out(('%d passed, %d failed, %d skipped'):format(c.ok, c.fail, c.skip))
    return exit(c.fail > 0 and 1 or 0)
  end

  return T
end

return M.new({ filter = os.getenv('FORGE_TEST_ID') })
