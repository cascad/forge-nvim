-- Снимки конфигурации (add-wezterm-spec-checks, задача 4.2, design, решение 8).
-- Набор `wezterm`. Снимок — детектор изменений, а не спека: случаи называются
-- `SNAPSHOT: …`, ID требований не несут и в сводку по ID не попадают
-- (правила закрепляют проверки tests/wezterm/<capability>.test.lua).
--
-- Два снимка на каждую тройку (windows, macos, linux):
--   * keys.<ОС> — `show-keys --lua` НАСТОЯЩЕГО WezTerm через обёртку guard.lua
--     (FORGE_TARGET подменяет тройку). Нормализация: буква после `phys:` —
--     заглавная (регистр в выводе случаен от запуска к запуску), `EmitEvent
--     'user-defined-N'` → `Callback` (N — порядок создания колбэков). Порядок
--     записей задаёт WezTerm (по коду клавиши), перестановка в исходнике
--     снимок не меняет. Какой колбэк на какой клавише — не хранится.
--     Только если `wezterm --version` = tests/wezterm/VERSION, иначе SKIP с
--     обеими версиями; нет бинарника — SKIP.
--   * config.<ОС> — весь config из подделки (fake_wezterm, чистое окружение:
--     env = {}, files = {}) плюс отсортированный список событий wezterm.on.
--     Ловит то, чего нет в show-keys: шрифт, цвета, протокол клавиатуры,
--     default_prog. Сериализация детерминирована (см. «Сериализация»).
-- Эталоны — tests/wezterm/golden/{keys,config}.{windows,macos,linux}.lua, с
-- шапкой происхождения (версия WezTerm, тройка, команда; у config — версия из
-- шапки фикстуры, с которой сняты встроенные таблицы). Сравнивается файл
-- целиком; расхождение — FAIL с diff (первая пара строк — в первой строке,
-- полный unified diff — в продолжении и в логе).
--
-- `--update-golden` (FORGE_UPDATE_GOLDEN=1) перезаписывает эталоны — только из
-- wezterm.lua репо и только на версии из VERSION. Diff эталона — в тот же
-- коммит, что и осознанное изменение поведения.
--
-- Мутации — на копии в .tests/: обёртка ставит require('fake_wezterm').CONFIG_PATH
-- на копию (и/или F.VERSION на другую строку) и делает dofile этого файла.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local B = require('bootstrap')
local T = require('check')
local F = require('fake_wezterm')
local RW = require('real_wezterm')

-- ---------------------------------------------------------------------------
-- Композиционный корень: бинарник и его версия, проверяемый конфиг, режим.
-- ---------------------------------------------------------------------------
local EXE = B.wezterm
local CONFIG = F.CONFIG_PATH
local REPO_CONFIG = B.root .. '/wezterm.lua'
local WANT_VERSION = F.VERSION
local UPDATE = B.update_golden
local GOLDEN = 'tests/wezterm/golden'
local ORDER = { 'windows', 'macos', 'linux' }
local HAVE_VERSION = EXE and RW.version(EXE) or nil
local ENV = EXE and RW.sandbox_env(B.sandbox .. '/wezterm') or nil
-- Снимок конфигурации зависит не от бинарника, а от фикстуры встроенных таблиц:
-- его происхождение — версия из шапки фикстуры. Поэтому при `wezterm --version`
-- ≠ VERSION он сверяется как обычно (design, решение 8).
local FIXTURE_VERSION = (vim.fn.readfile(F.FIXTURE_PATH, '', 10) or {})
FIXTURE_VERSION = table.concat(FIXTURE_VERSION, '\n'):match('\n%-%- WezTerm: (%S+)') or 'неизвестна'

if CONFIG ~= REPO_CONFIG then
  io.stdout:write('конфиг под проверкой: ' .. CONFIG .. '\n')
end

-- ---------------------------------------------------------------------------
-- Нормализация show-keys --lua
-- ---------------------------------------------------------------------------

--- Вывод show-keys → вид для эталона. Трогает только то, что меняется без
--- изменения поведения: регистр буквы после phys: и номер user-defined-N.
--- EmitEvent с другим именем события остаётся как есть.
local function normalize_show_keys(text)
  text = text:gsub('\r\n', '\n')
  text = text:gsub("'phys:(%a)'", function(c) return "'phys:" .. c:upper() .. "'" end)
  -- act.EmitEvent 'user-defined-N' → act.Callback; { EmitEvent =  'user-defined-N' } → { Callback }
  text = text:gsub("EmitEvent%s*=?%s*'user%-defined%-%d+'", 'Callback')
  return text
end

-- ---------------------------------------------------------------------------
-- Сериализация конфига из подделки
-- ---------------------------------------------------------------------------
-- * ключи таблиц отсортированы; у привязок и действий сначала key, mods,
--   event, action, name, args — чтобы строка читалась, дальше по алфавиту;
-- * привязки config.keys и config.key_tables.* — каноническая пара
--   (F.norm_binding: регистр phys:, синонимы клавиш, множество модификаторов,
--   normalize_shift — как у WezTerm 20240203) и сортировка: WezTerm не зависит
--   от порядка записей, значит, и снимок (повторы пар — дело WT-KEYS-8);
-- * строка-действие 'PopKeyTable' ≡ act.PopKeyTable (F.normalize_action);
-- * колбэк action_callback → { name = "Callback" } (номер user-defined-N и
--   функция отброшены, как в снимке show-keys), любая другая функция → "<function>";
-- * списки таблиц — по элементу на строку, прочее — в одну строку;
-- * числа: целые без дробной части, иначе кратчайшее точное %.14g/%.17g.

local FIELD_ORDER = { key = 1, mods = 2, event = 3, action = 4, name = 5, args = 6 }

local function key_less(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  if ta == 'string' then
    local pa, pb = FIELD_ORDER[a] or 99, FIELD_ORDER[b] or 99
    if pa ~= pb then return pa < pb end
  end
  if ta == 'number' or ta == 'string' then return a < b end
  return tostring(a) < tostring(b)
end

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, key_less)
  return keys
end

local function is_list(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

local function ser_string(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    return ('\\%03d'):format(c:byte())
  end) .. '"'
end

local function ser_number(n)
  if n ~= n or n == math.huge or n == -math.huge then return ('(%s)'):format(tostring(n)) end
  if n == math.floor(n) and math.abs(n) < 2 ^ 53 then return ('%d'):format(n) end
  local s = ('%.14g'):format(n)
  if tonumber(s) ~= n then s = ('%.17g'):format(n) end
  return s
end

local inline
local function ser_key(k)
  if type(k) == 'string' and k:match('^[%a_][%w_]*$') then return k end
  return '[' .. inline(k) .. ']'
end

inline = function(v)
  local t = type(v)
  if t == 'string' then return ser_string(v) end
  if t == 'number' then return ser_number(v) end
  if t == 'boolean' or t == 'nil' then return tostring(v) end
  if t ~= 'table' then return ser_string('<' .. t .. '>') end
  local parts = {}
  if is_list(v) then
    for _, x in ipairs(v) do parts[#parts + 1] = inline(x) end
  else
    for _, k in ipairs(sorted_keys(v)) do parts[#parts + 1] = ser_key(k) .. ' = ' .. inline(v[k]) end
  end
  if #parts == 0 then return '{}' end
  return '{ ' .. table.concat(parts, ', ') .. ' }'
end

-- Многострочно: список, в котором есть таблицы, и словарь, в глубине которого
-- такой список. Элементы списка — всегда в одну строку (привязка = строка).
local function needs_block(v)
  if type(v) ~= 'table' then return false end
  if is_list(v) then
    for _, x in ipairs(v) do if type(x) == 'table' then return true end end
    return false
  end
  for _, x in pairs(v) do if needs_block(x) then return true end end
  return false
end

local function block(v, indent)
  local pad = indent .. '  '
  local lines = { '{' }
  if is_list(v) then
    for _, x in ipairs(v) do lines[#lines + 1] = pad .. inline(x) .. ',' end
  else
    for _, k in ipairs(sorted_keys(v)) do
      local x = v[k]
      lines[#lines + 1] = pad .. ser_key(k) .. ' = ' .. (needs_block(x) and block(x, pad) or inline(x)) .. ','
    end
  end
  lines[#lines + 1] = indent .. '}'
  return table.concat(lines, '\n')
end

--- Глубокая копия без метатаблиц: колбэк → { name = 'Callback' }, функция → '<function>'.
local function strip(v)
  if type(v) == 'function' then return '<function>' end
  if type(v) ~= 'table' then return v end
  if v.name == 'Callback' and type(v.fn) == 'function' then return { name = 'Callback' } end
  local out = {}
  for k, x in pairs(v) do out[k] = strip(x) end
  return out
end

local function norm_bindings(list)
  local rows = {}
  for _, b in ipairs(list) do
    local e = strip(b)
    e.key, e.mods = F.norm_binding(b.key, b.mods)
    e.action = strip(F.normalize_action(b.action))
    local line = inline(e)
    rows[#rows + 1] = { sort = e.key .. '\0' .. e.mods .. '\0' .. line, value = e }
  end
  table.sort(rows, function(a, b) return a.sort < b.sort end)
  local out = {}
  for i, row in ipairs(rows) do out[i] = row.value end
  return out
end

--- Результат F.load_config → текст снимка (без шапки).
local function serialize_config(res)
  local c = strip(res.config)
  if type(res.config.keys) == 'table' then c.keys = norm_bindings(res.config.keys) end
  if type(res.config.key_tables) == 'table' then
    for name, list in pairs(res.config.key_tables) do c.key_tables[name] = norm_bindings(list) end
  end
  local events = {}
  for name, handlers in pairs(res.event_handlers) do
    for _ = 1, #handlers do events[#events + 1] = name end
  end
  table.sort(events)
  return 'return ' .. block({ config = c, events = events }, '') .. '\n'
end

-- ---------------------------------------------------------------------------
-- Шапки эталонов: функция тройки и версии, но не пути — эталон одинаков на
-- любой машине, а в прогоне мутации diff показывает только изменение.
-- ---------------------------------------------------------------------------
local ACCEPT = '-- Руками не править. Осознанное изменение: nvim -l tests/run.lua --update-golden, diff — в тот же коммит.'

local function keys_header(os_name, triple)
  return table.concat({
    '-- Эталон снимка show-keys --lua настоящего WezTerm, вид ' .. os_name .. ' (add-wezterm-spec-checks, design, решение 8).',
    ACCEPT,
    '-- WezTerm: ' .. WANT_VERSION,
    '-- Тройка: ' .. triple,
    '-- Команда: FORGE_CONFIG=<репо>/wezterm.lua FORGE_TARGET=' .. triple
      .. ' wezterm --config-file tests/wezterm/guard.lua show-keys --lua',
    "-- Нормализация: буква после phys: — заглавная (регистр в выводе случаен); EmitEvent 'user-defined-N' → Callback.",
    '-- Порядок записей задаёт WezTerm (по коду клавиши), а не исходник.',
    '',
  }, '\n')
end

local function config_header(os_name, triple)
  return table.concat({
    '-- Эталон снимка конфигурации из подделки, вид ' .. os_name .. ' (add-wezterm-spec-checks, design, решение 8).',
    ACCEPT,
    '-- WezTerm: ' .. FIXTURE_VERSION .. ' (встроенные таблицы режимов — tests/wezterm/fixtures/default_key_tables.lua)',
    '-- Тройка: ' .. triple,
    "-- Команда: F.load_config{ triple = '" .. triple .. "', env = {}, files = {} }"
      .. ' (tests/wezterm/fake_wezterm.lua, <репо>/wezterm.lua)',
    '-- Нормализация: ключи отсортированы; привязки keys и key_tables.* — каноническая пара (F.norm_binding)'
      .. ' и сортировка; action_callback → { name = "Callback" }; функция → "<function>"; events — wezterm.on по имени.',
    '',
  }, '\n')
end

-- ---------------------------------------------------------------------------
-- Сверка с эталоном
-- ---------------------------------------------------------------------------
local function read_or_nil(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return (s:gsub('\r\n', '\n'))
end

local function write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local f = assert(io.open(path, 'wb'))
  f:write(content)
  f:close()
end

local function clip(s, n)
  s = vim.trim(s)
  if #s <= n then return s end
  return s:sub(1, n) .. '…'
end

--- Текст FAIL: первая строка — сводка и первая пара расходящихся строк
--- (её раннер показывает в терминале), дальше — unified diff (эталон → снимок).
local function diff_detail(rel, want, got)
  local d = vim.text.diff(want, got, { result_type = 'unified', ctxlen = 0 })
  local minus, plus, first_minus, first_plus, first_hunk = 0, 0, nil, nil, nil
  local lines = {}
  for line in d:gmatch('[^\n]+') do
    lines[#lines + 1] = line
    local c = line:sub(1, 1)
    if c == '@' then first_hunk = first_hunk or line:match('^@@ %-(%d+)')
    elseif c == '-' then minus = minus + 1; first_minus = first_minus or line:sub(2)
    elseif c == '+' then plus = plus + 1; first_plus = first_plus or line:sub(2)
    end
  end
  local head = ('снимок ≠ эталон %s (-%d +%d строк, стр. %s): %s → %s'):format(rel, minus, plus,
    first_hunk or '?', first_minus and ('-' .. clip(first_minus, 140)) or '(нет)',
    first_plus and ('+' .. clip(first_plus, 140)) or '(нет)')
  local tail = {}
  for i = 1, math.min(#lines, 60) do tail[#tail + 1] = lines[i] end
  if #lines > 60 then tail[#tail + 1] = ('… ещё %d строк diff'):format(#lines - 60) end
  tail[#tail + 1] = 'осознанное изменение — nvim -l tests/run.lua --update-golden (diff эталона — в тот же коммит)'
  return head .. '\n' .. table.concat(tail, '\n')
end

--- Сверить text с эталоном rel; под --update-golden — записать его.
local function settle(rel, text)
  local path = B.root .. '/' .. rel
  local have = read_or_nil(path)
  if UPDATE then
    if CONFIG ~= REPO_CONFIG then
      error('эталоны пишутся только из wezterm.lua репо, а проверяется ' .. CONFIG, 0)
    end
    if have ~= text then write(path, text) end
    -- Не строка протокола: видна в логе и при прямом запуске.
    io.stdout:write(('  (эталон %s: %s)\n'):format(rel,
      have == nil and 'создан' or (have ~= text and 'обновлён' or 'без изменений')))
    return
  end
  if have == nil then
    error('эталона нет: ' .. rel .. ' — снять: nvim -l tests/run.lua --update-golden', 0)
  end
  if have ~= text then error(diff_detail(rel, have, text), 0) end
end

-- ---------------------------------------------------------------------------
-- Самопроверки нормализации и сериализации (без бинарника и диска)
-- ---------------------------------------------------------------------------
T.check('SELF: нормализация show-keys — регистр phys:, user-defined-N → Callback, прочее как есть', function()
  local src = table.concat({
    "    { key = 'phys:c', mods = 'CTRL', action = act.EmitEvent 'user-defined-12' },",
    "    { key = 'phys:LeftBracket', mods = 'CTRL', action = act.SendKey{ key =  'F13', mods =  'NONE' } },",
    "      { key = 'phys:a', mods = 'NONE', action = act.Multiple{ 'PopKeyTable', { EmitEvent =  'user-defined-0' } } },",
    "    { key = 'phys:Z', mods = 'SUPER', action = act.EmitEvent 'my-event' },",
  }, '\r\n') .. '\r\n'
  T.eq(normalize_show_keys(src), table.concat({
    "    { key = 'phys:C', mods = 'CTRL', action = act.Callback },",
    "    { key = 'phys:LeftBracket', mods = 'CTRL', action = act.SendKey{ key =  'F13', mods =  'NONE' } },",
    "      { key = 'phys:A', mods = 'NONE', action = act.Multiple{ 'PopKeyTable', { Callback } } },",
    "    { key = 'phys:Z', mods = 'SUPER', action = act.EmitEvent 'my-event' },",
  }, '\n') .. '\n')
end)

T.check('SELF: снимок конфигурации не зависит от порядка и записи привязок в исходнике, но видит смену действия', function()
  local a = [[
    local wezterm = require('wezterm'); local act = wezterm.action
    local c = { font_size = 12.0, line_height = 1.05, default_prog = { 'pwsh.exe', '-NoLogo' } }
    c.keys = {
      { key = 'phys:c', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function() end) },
      { key = 'Enter', mods = 'SHIFT', action = act.SplitPane({ direction = 'Right' }) },
    }
    c.key_tables = { t = { { key = 'Escape', action = 'PopKeyTable' }, { key = 'phys:J', action = act.ScrollByLine(1) } } }
    wezterm.on('b-event', function() end); wezterm.on('a-event', function() end)
    return c
  ]]
  -- Тот же смысл: обратный порядок, другие записи клавиш и модификаторов,
  -- act.PopKeyTable вместо строки, другой номер колбэка, другой порядок on.
  local b = [[
    local wezterm = require('wezterm'); local act = wezterm.action
    local _unused = wezterm.action_callback(function() end)
    local c = { default_prog = { 'pwsh.exe', '-NoLogo' }, line_height = 1.05, font_size = 12 }
    c.key_tables = { t = { { key = 'phys:j', mods = 'NONE', action = act.ScrollByLine(1) }, { key = 'Escape', mods = '', action = act.PopKeyTable } } }
    wezterm.on('a-event', function() end); wezterm.on('b-event', function() end)
    c.keys = {
      { key = 'Return', mods = 'SHIFT', action = act.SplitPane({ direction = 'Right' }) },
      { key = 'phys:C', mods = 'SHIFT|CTRL', action = wezterm.action_callback(function() end) },
    }
    return c
  ]]
  local function snap(src)
    return serialize_config(F.load_config({ triple = F.TRIPLES.windows, env = {}, files = {}, source = src, chunkname = 'snapshot-self' }))
  end
  local sa = snap(a)
  T.eq(sa, snap(b), 'снимки равнозначных конфигов')
  T.ok(sa:find('action = { name = "Callback" }', 1, true), 'колбэк не приведён к Callback:\n' .. sa)
  T.ok(not sa:find('user-defined', 1, true) and not sa:find('function', 1, true), 'в снимке номер колбэка или функция:\n' .. sa)
  T.ok(sa:find('events = { "a-event", "b-event" }', 1, true), 'события не отсортированы:\n' .. sa)
  T.ok(sa ~= snap(a:gsub("direction = 'Right'", "direction = 'Down'")), 'смена направления сплита не видна в снимке')
  T.eq(inline({ fn = print }), '{ fn = "<function>" }', 'функция вне колбэка')
end)

-- ---------------------------------------------------------------------------
-- Снимки
-- ---------------------------------------------------------------------------
local keys_gate
if not EXE then
  keys_gate = 'wezterm не найден (FORGE_WEZTERM пуст / нет в PATH) — снимок show-keys не снимался'
elseif HAVE_VERSION ~= WANT_VERSION then
  keys_gate = ('wezterm --version = %s, а tests/wezterm/VERSION = %s — снимок show-keys сверяется только на версии эталона')
    :format(tostring(HAVE_VERSION), WANT_VERSION)
end

for _, os_name in ipairs(ORDER) do
  local triple = F.TRIPLES[os_name]
  local rel = ('%s/keys.%s.lua'):format(GOLDEN, os_name)
  local name = ('SNAPSHOT: keys.%s — show-keys --lua через guard.lua совпадает с %s'):format(os_name, rel)
  if keys_gate then
    T.skip(name, keys_gate)
  else
    T.check(name, function()
      local res = RW.guard(EXE, CONFIG, triple, { 'show-keys', '--lua' }, { env = ENV })
      T.ok(res.code == 0 and res.marker == triple, 'обёртка: конфиг не загрузился — ' .. RW.describe(res))
      T.ok(vim.trim(res.stdout) ~= '', 'show-keys: пустой stdout — ' .. RW.describe(res))
      settle(rel, keys_header(os_name, triple) .. normalize_show_keys(res.stdout))
    end)
  end
end

for _, os_name in ipairs(ORDER) do
  local triple = F.TRIPLES[os_name]
  local rel = ('%s/config.%s.lua'):format(GOLDEN, os_name)
  T.check(('SNAPSHOT: config.%s — конфиг из подделки совпадает с %s'):format(os_name, rel), function()
    local res = F.load_config({ triple = triple, env = {}, files = {}, path = CONFIG })
    settle(rel, config_header(os_name, triple) .. serialize_config(res))
  end)
end

T.finish()
