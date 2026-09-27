-- Обёртка загрузки для НАСТОЯЩЕГО WezTerm (Lua 5.4), add-wezterm-spec-checks,
-- design, решения 3 и 7. Нужна потому, что WezTerm 20240203 ошибок конфига
-- кодом возврата не показывает: сломанный конфиг даёт код 0 и встроенные
-- привязки (WT-LOAD-11). Обёртка превращает ошибку в код 3.
--
-- Режим загрузки:
--   FORGE_CONFIG=<абсолютный путь к wezterm.lua> [FORGE_TARGET=<тройка>] \
--     wezterm --config-file tests/wezterm/guard.lua <подкоманда, напр. show-keys --lua | ls-fonts>
--   * FORGE_TARGET подменяет wezterm.target_triple — вид macOS и Linux на Windows;
--   * ошибка (синтаксис, выполнение, не таблица) → stderr `FORGE_CONFIG_ERROR: <текст с файлом и строкой>`, код 3;
--   * успех → stderr `FORGE_CONFIG_OK <тройка>`, конфиг возвращается, подкоманда работает как обычно.
--
-- Режим выгрузки фикстуры (делает `nvim -l tests/run.lua --update-golden`):
--   FORGE_DUMP_KEY_TABLES=<путь> wezterm --config-file tests/wezterm/guard.lua show-keys
--   * wezterm.gui.default_key_tables() → Lua-литерал в <путь> с шапкой
--     происхождения (версия WezTerm, тройка хоста, команда), затем код 0;
--   * записи отсортированы по (key, mods, action): WezTerm отдаёт их в случайном
--     порядке (HashMap; проба на 20240203, Windows, 2026-09-27 — три запуска,
--     три разных порядка), а фикстура обязана быть побайтно стабильной.
--
-- Всё тело — в pcall: любая ошибка самой обёртки тоже даёт код 3 с текстом,
-- а не молчаливые встроенные дефолты WezTerm.

local FIXTURE_COMMAND = 'nvim -l tests/run.lua --update-golden'
  .. ' (FORGE_DUMP_KEY_TABLES=<фикстура> wezterm --config-file tests/wezterm/guard.lua show-keys)'

local function env(name)
  local v = os.getenv(name)
  if v == nil or v == '' then return nil end
  return v
end

-- ---------------------------------------------------------------------------
-- Детерминированная сериализация в Lua-литерал (читается и LuaJIT, и Lua 5.4)
-- ---------------------------------------------------------------------------
local function ser_string(s)
  -- Печатные ASCII как есть, остальное — \ddd (три цифры, без двусмысленности
  -- с последующей цифрой). %q в Lua 5.4 для \n пишет обратный слэш + перевод строки.
  return '"' .. s:gsub('[%c"\\\128-\255]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    return ('\\%03d'):format(c:byte())
  end) .. '"'
end

local function ser_number(n)
  if math.type and math.type(n) == 'integer' then return ('%d'):format(n) end
  if n == math.floor(n) and n > -1e15 and n < 1e15 then return ('%.1f'):format(n) end
  local s = ('%.14g'):format(n)
  if tonumber(s) ~= n then s = ('%.17g'):format(n) end
  return s
end

local function is_list(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  for i = 1, n do
    if t[i] == nil then return false end
  end
  return true
end

local ser
local function ser_key(k)
  if type(k) == 'string' and k:match('^[%a_][%w_]*$') then return k end
  return '[' .. ser(k) .. ']'
end

ser = function(v)
  local t = type(v)
  if t == 'string' then return ser_string(v) end
  if t == 'number' then return ser_number(v) end
  if t == 'boolean' then return tostring(v) end
  if t == 'table' then
    local parts = {}
    if is_list(v) then
      for _, x in ipairs(v) do parts[#parts + 1] = ser(x) end
    else
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
      end)
      for _, k in ipairs(keys) do parts[#parts + 1] = ser_key(k) .. ' = ' .. ser(v[k]) end
    end
    if #parts == 0 then return '{}' end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
  end
  error('не сериализуется значение типа ' .. t)
end

local function dump_key_tables(wezterm, path)
  local tables = wezterm.gui.default_key_tables()
  local names = {}
  for name in pairs(tables) do names[#names + 1] = name end
  table.sort(names)
  local out = {
    '-- Встроенные таблицы режимов WezTerm: wezterm.gui.default_key_tables().',
    '-- Снято с настоящего бинарника обёрткой tests/wezterm/guard.lua, руками не править.',
    '-- WezTerm: ' .. tostring(wezterm.version),
    '-- Тройка хоста: ' .. tostring(wezterm.target_triple),
    '-- Команда: ' .. FIXTURE_COMMAND,
    '-- Порядок записей отсортирован по (key, mods, action): WezTerm отдаёт их в случайном порядке.',
    '-- Действия — в форме WezTerm: строка для действия без аргумента, { Имя = аргумент } иначе.',
    'return {',
  }
  for _, name in ipairs(names) do
    local rows = {}
    for _, b in ipairs(tables[name]) do
      rows[#rows + 1] = {
        sort = ser(b.key) .. '\0' .. ser(b.mods) .. '\0' .. ser(b.action),
        text = ('    { key = %s, mods = %s, action = %s },'):format(ser(b.key), ser(b.mods), ser(b.action)),
      }
    end
    table.sort(rows, function(a, b) return a.sort < b.sort end)
    out[#out + 1] = '  ' .. ser_key(name) .. ' = {'
    for _, r in ipairs(rows) do out[#out + 1] = r.text end
    out[#out + 1] = '  },'
  end
  out[#out + 1] = '}'
  local f, err = io.open(path, 'wb')
  if not f then error('не открыть ' .. path .. ' на запись: ' .. tostring(err)) end
  f:write(table.concat(out, '\n'), '\n')
  f:close()
  io.stderr:write('FORGE_DUMP_OK ' .. path .. '\n')
end

-- ---------------------------------------------------------------------------
-- Тело
-- ---------------------------------------------------------------------------
local ok, result = pcall(function()
  local wezterm = require('wezterm')

  local dump = env('FORGE_DUMP_KEY_TABLES')
  if dump then
    dump_key_tables(wezterm, dump)
    return { exit = 0 }
  end

  local path = env('FORGE_CONFIG')
  if not path then error('FORGE_CONFIG не задан: путь к проверяемому wezterm.lua', 0) end
  local target = env('FORGE_TARGET')
  if target then wezterm.target_triple = target end
  -- Модули рядом с конфигом ищутся так же, как у WezTerm без обёртки.
  local dir = path:match('^(.*)[/\\]')
  if dir then package.path = dir .. '/?.lua;' .. dir .. '/?/init.lua;' .. package.path end

  local loaded, cfg = pcall(dofile, path)
  if not loaded then error(tostring(cfg), 0) end
  if type(cfg) ~= 'table' then error(path .. ' вернул ' .. type(cfg) .. ', а не таблицу конфига', 0) end
  io.stderr:write('FORGE_CONFIG_OK ' .. tostring(wezterm.target_triple) .. '\n')
  return { config = cfg }
end)

if not ok then
  io.stderr:write('FORGE_CONFIG_ERROR: ' .. tostring(result) .. '\n')
  io.stderr:flush()
  os.exit(3)
end
if result.exit then
  io.stderr:flush()
  os.exit(result.exit)
end
return result.config
