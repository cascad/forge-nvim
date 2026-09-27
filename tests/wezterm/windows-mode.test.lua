-- Проверки capability wezterm-windows-mode (WT-WIN-1…21), add-wezterm-spec-checks, задача 3.5;
-- модальность режимов — fix-windows-mode-modality (design, решение 12): проверки с
-- меткой «windows-mode: …» — сценарии, на которые ссылаются строки `Проверка:`.
--
-- Каждая проверка — сценарий требования в той части, что видна без GUI:
--   * таблицы config.keys, config.key_tables.windows и resize_pane, а для
--     WT-WIN-21 — ещё copy_mode и search_mode (встроенные, из фикстуры,
--     переведённые конфигом на phys:);
--   * колбэки режима на поддельных окне и панели (tests/wezterm/fake_wezterm.lua).
-- Каждая проверка идёт по трём тройкам: Платформы у всех WT-WIN — «все».
--
-- Не видно из конфига — это ручная часть (чек-листы tests/manual/ ведёт
-- review-baseline), здесь её нет, SKIP для неё не пишется:
--   * бейдж режима (WT-UI); режим принадлежит окну и живёт при смене вкладки (WT-WIN-1);
--   * режим гаснет, когда WezTerm заново применяет конфиг (WT-WIN-2) — здесь
--     только то, что эти клавиши доходят до перечитывания и overrides шрифта;
--   * ход отсчёта таймаута и его продление командами и сочетаниями (WT-WIN-3) —
--     здесь только 5000 мс и то, что сочетания терминала есть в таблицах режимов;
--   * что проглоченная клавиша не напечатана, в том числе её отпускание (WT-WIN-4,
--     WT-WIN-20) — здесь только prevent_fallback у входов;
--   * экраны выбора панели и запроса подтверждения: Esc на Windows и macOS,
--     русская раскладка, зум (WT-WIN-7, WT-WIN-10, WT-WIN-20);
--   * геометрия сдвигов границ и «сдвигать нечего» (WT-WIN-11), обход сеткой и
--     «соседа нет» (WT-WIN-5), порядок обхода панелей по o (WT-WIN-6);
--   * кодировщики клавиш (kitty, win32-input-mode) и IME (WT-WIN-20);
--   * порядок, в котором WezTerm ищет клавишу в стеке таблиц и оверлеях (WT-WIN-21) —
--     здесь только состав таблиц, из которого этот порядок выбирает.
--
-- Мутации (проверка самих проверок) — на копии wezterm.lua в .tests/:
-- обёртка ставит require('fake_wezterm').CONFIG_PATH на копию и делает dofile
-- этого файла. wezterm.lua репо не правится.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')

-- ---------------------------------------------------------------------------
-- Помощники
-- ---------------------------------------------------------------------------

local ORDER = { 'windows', 'macos', 'linux' }
local loaded = {}

local function load(os_name)
  if not loaded[os_name] then
    loaded[os_name] = F.load_config({ triple = F.TRIPLES[os_name] })
  end
  return loaded[os_name]
end

--- fn(config, os_name, res) для каждой тройки; ошибка — с именем ОС впереди.
local function each_os(fn, list)
  for _, os_name in ipairs(list or ORDER) do
    local ok, e = pcall(function()
      local res = load(os_name)
      fn(res.config, os_name, res)
    end)
    if not ok then error(os_name .. ': ' .. tostring(e), 0) end
  end
end

local function id_of(key, mods)
  local _, _, id = F.norm_binding(key, mods)
  return id
end

--- Колбэки — по месту, без функции: для сравнения структур между загрузками.
local function strip(v)
  if type(v) ~= 'table' then return v end
  if v.name == 'Callback' and type(v.fn) == 'function' then return { name = 'Callback' } end
  local out = {}
  for k, x in pairs(v) do out[k] = strip(x) end
  return out
end

local function shape(a) return strip(F.normalize_action(a)) end

local function show(a)
  return vim.inspect(shape(a), { newline = ' ', indent = '' })
end

--- Действие пары (key, mods) — последняя запись, как у WezTerm; нет — ошибка.
local function action(list, key, mods)
  local b = F.find_binding(list, key, mods)
  if not b then error('нет привязки ' .. id_of(key, mods), 2) end
  return F.normalize_action(b.action), b
end

--- Пары (key, mods) нет в списке.
local function absent(list, key, mods, where)
  local b = F.find_binding(list, key, mods)
  if b then
    error(('%s: есть привязка %s → %s'):format(where, id_of(key, mods), show(b.action)), 2)
  end
end

--- Буквы нет ни по позиции (phys:X), ни по символу (mapped:x) с этими модификаторами.
local function letter_absent(list, letter, mods, where)
  absent(list, 'phys:' .. letter:upper(), mods, where)
  absent(list, 'mapped:' .. letter:lower(), mods, where)
end

--- Все действия, включая вложенные в Multiple, плоским списком.
local function flatten(a, out)
  a = F.normalize_action(a)
  out = out or {}
  out[#out + 1] = a
  if type(a) == 'table' and a.name == 'Multiple' then
    for _, x in ipairs(a.args[1]) do flatten(x, out) end
  end
  return out
end

local function has_action(a, name)
  for _, x in ipairs(flatten(a)) do
    if x.name == name then return true end
  end
  return false
end

--- Multiple, первым шагом которого — ClearKeyTableStack: выход из режима (и из
--- RESIZE под ним) до действия (WT-WIN-19).
local function leaves_first(a)
  return a.name == 'Multiple' and type(a.args[1]) == 'table'
    and F.normalize_action(a.args[1][1]).name == 'ClearKeyTableStack'
end

--- Второй шаг Multiple { ClearKeyTableStack, <действие> }.
local function after_leave(a)
  T.ok(leaves_first(a), 'ожидался Multiple { ClearKeyTableStack, … }, получено ' .. show(a))
  T.eq(#a.args[1], 2, 'шагов в Multiple')
  return F.normalize_action(a.args[1][2])
end

-- Действия, открывающие экран поверх панели: независимый оракул WT-WIN-19
-- (fix-windows-mode-modality, design, решение 12) — по имени действия, а не по
-- пометке leaves_mode в конфиге.
local SCREEN = {}
for _, n in ipairs({ 'CloseCurrentPane', 'QuickSelect', 'QuickSelectArgs', 'ActivateCopyMode', 'Search',
  'QuitApplication', 'PaneSelect', 'CharSelect', 'ActivateCommandPalette', 'ShowLauncher',
  'ShowLauncherArgs', 'ShowTabNavigator', 'PromptInputLine', 'InputSelector', 'ShowDebugOverlay' }) do
  SCREEN[n] = true
end

--- Множество пар 'key mods' списка.
local function id_set(list)
  local set = {}
  for _, b in ipairs(list) do set[id_of(b.key, b.mods)] = true end
  return set
end

--- Множества пар равны; иначе ошибка со списками «нет» и «лишние».
local function set_eq(actual, expected, msg)
  local missing, extra = {}, {}
  for k in pairs(expected) do if not actual[k] then missing[#missing + 1] = k end end
  for k in pairs(actual) do if not expected[k] then extra[#extra + 1] = k end end
  if #missing == 0 and #extra == 0 then return end
  table.sort(missing)
  table.sort(extra)
  error(('%s: нет [%s], лишние [%s]'):format(msg, table.concat(missing, ', '), table.concat(extra, ', ')), 2)
end

local function ids(spec)
  local set = {}
  for _, p in ipairs(spec) do set[id_of(p[1], p[2])] = true end
  return set
end

--- Команда режима «остаётся в режиме»: ни выхода, ни смены таблицы.
local function stays(a)
  return not has_action(a, 'PopKeyTable') and not has_action(a, 'ClearKeyTableStack')
    and not has_action(a, 'ActivateKeyTable')
end

local function opens_screen(a)
  for _, x in ipairs(flatten(a)) do
    if SCREEN[x.name] then return true end
  end
  return false
end

--- Запись таблицы режима — копия сочетания терминала k из config.keys: та же
--- пара и то же действие, либо Multiple { ClearKeyTableStack, то же действие }.
local function is_copy_of(b, k)
  if not k or id_of(b.key, b.mods) ~= id_of(k.key, k.mods) then return false end
  if rawequal(b.action, k.action) then return true end
  local a = F.normalize_action(b.action)
  return leaves_first(a) and #a.args[1] == 2
    and vim.deep_equal(F.normalize_action(a.args[1][2]), F.normalize_action(k.action))
end

--- Записи таблицы режима: собственные команды и копии сочетаний терминала.
local function split_mode(c, tname)
  local keys = {}
  for _, k in ipairs(c.keys) do keys[id_of(k.key, k.mods)] = k end
  local own, copies = {}, {}
  for _, b in ipairs(c.key_tables[tname]) do
    local id = id_of(b.key, b.mods)
    if is_copy_of(b, keys[id]) then copies[id] = b else own[id] = b end
  end
  return own, copies, keys
end

-- Запись входа в режим в config.keys.
local function entry_args(c)
  local a = action(c.keys, 'phys:Space', 'CTRL|SHIFT')
  T.eq(a.name, 'ActivateKeyTable', 'Ctrl+Shift+Space в config.keys')
  return a.args[1]
end

-- ---------------------------------------------------------------------------
-- Ожидаемый состав таблицы режима — по тексту WT-WIN-19 и WT-WIN-2
-- ---------------------------------------------------------------------------

-- Первая группа WT-WIN-19: h, j, k, l, стрелки, o, v, s, z, c, n, p, 1…9.
local STAY = {
  { 'phys:H' }, { 'phys:J' }, { 'phys:K' }, { 'phys:L' },
  { 'LeftArrow' }, { 'DownArrow' }, { 'UpArrow' }, { 'RightArrow' },
  { 'phys:O' }, { 'phys:V' }, { 'phys:S' }, { 'phys:Z' },
  { 'phys:C' }, { 'phys:N' }, { 'phys:P' },
}
for i = 1, 9 do STAY[#STAY + 1] = { 'phys:' .. i } end
-- Вторая группа: r.
local TO_RESIZE = { { 'phys:R' } }
-- Третья группа: q, x, a, `,`, w, Shift+S, `[`, f, Space, b, e, `;`, m, d.
local EXIT_FIRST = {
  { 'phys:Q' }, { 'phys:X' }, { 'phys:A' }, { 'phys:Comma' }, { 'phys:W' }, { 'phys:S', 'SHIFT' }, { 'phys:LeftBracket' },
  { 'phys:F' }, { 'phys:Space' }, { 'phys:B' }, { 'phys:E' }, { 'phys:Semicolon' },
  { 'phys:M' }, { 'phys:D' },
}
-- Выходы WT-WIN-2: Esc, Enter без модификаторов и тот же Ctrl+Shift+Space.
local EXITS = { { 'Escape' }, { 'Enter' }, { 'phys:Space', 'CTRL|SHIFT' } }

local function union(...)
  local set = {}
  for _, s in ipairs({ ... }) do for k in pairs(s) do set[k] = true end end
  return set
end

-- Команды режима — всё, кроме выходов (так их перечисляет WT-WIN-19).
local COMMANDS = union(ids(STAY), ids(TO_RESIZE), ids(EXIT_FIRST))

-- RESIZE (WT-WIN-11): 8 сдвигов и 2 выхода.
local RESIZE_MOVES = {
  { 'phys:H', 'Left' }, { 'LeftArrow', 'Left' }, { 'phys:L', 'Right' }, { 'RightArrow', 'Right' },
  { 'phys:K', 'Up' }, { 'UpArrow', 'Up' }, { 'phys:J', 'Down' }, { 'DownArrow', 'Down' },
}
local RESIZE_OWN = { { 'Escape' }, { 'Enter' } }
for _, m in ipairs(RESIZE_MOVES) do RESIZE_OWN[#RESIZE_OWN + 1] = { m[1] } end

-- Собственные пары таблиц режимов; остальное в них — копии сочетаний терминала.
local OWN = { windows = union(COMMANDS, ids(EXITS)), resize_pane = ids(RESIZE_OWN) }

-- Сочетания терминала, которые открывают экран (WT-WIN-4): их копии в режимах
-- сначала выключают режим.
local SCREEN_COMBOS = {
  windows = { { 'phys:W', 'CTRL|SHIFT' }, { 'phys:U', 'CTRL|SHIFT' }, { 'phys:X', 'CTRL|SHIFT' } },
}
SCREEN_COMBOS.linux = SCREEN_COMBOS.windows
SCREEN_COMBOS.macos = { { 'phys:W', 'CTRL|SHIFT' }, { 'phys:U', 'CTRL|SHIFT' }, { 'phys:X', 'CTRL|SHIFT' },
  { 'phys:Q', 'SUPER' } }

-- ---------------------------------------------------------------------------
-- WT-WIN-1 Вход в режим
-- ---------------------------------------------------------------------------

T.check('WT-WIN-1 вход: Ctrl+Shift+Space включает таблицу windows, липкую (one_shot = false)', function()
  each_os(function(c)
    local args = entry_args(c)
    T.eq(args.name, 'windows', 'имя таблицы')
    T.eq(args.one_shot, false, 'one_shot: режим не одноразовый префикс')
    T.ok(c.key_tables and c.key_tables.windows, 'нет config.key_tables.windows')
  end)
end)

T.check('WT-WIN-1 серия v, l, s без повторного входа: эти команды режим не выключают', function()
  each_os(function(c)
    for _, k in ipairs({ 'phys:V', 'phys:L', 'phys:S' }) do
      local a = action(c.key_tables.windows, k)
      T.ok(stays(a), k .. ' выходит из режима: ' .. show(a))
    end
  end)
end)

T.check('WT-WIN-1 вне режима клавиши режима не перехватываются: из собственных пар таблицы windows в config.keys только Ctrl+Shift+Space', function()
  each_os(function(c)
    local keys = id_set(c.keys)
    local both = {}
    for id in pairs(OWN.windows) do
      if keys[id] then both[id] = true end
    end
    set_eq(both, ids({ { 'phys:Space', 'CTRL|SHIFT' } }), 'пары режима, перехваченные и вне режима')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-2 Выход из режима
-- ---------------------------------------------------------------------------

T.check('WT-WIN-2 Esc выключает режим (PopKeyTable), до программы не доходит', function()
  each_os(function(c)
    T.eq(action(c.key_tables.windows, 'Escape'), { name = 'PopKeyTable' }, 'Esc в таблице windows')
  end)
end)

T.check('WT-WIN-2 Enter выключает режим (PopKeyTable), до шелла не доходит', function()
  each_os(function(c)
    T.eq(action(c.key_tables.windows, 'Enter'), { name = 'PopKeyTable' }, 'Enter в таблице windows')
  end)
end)

T.check('WT-WIN-2 тумблер: повторный Ctrl+Shift+Space в режиме — PopKeyTable, второго слоя нет', function()
  each_os(function(c)
    T.eq(action(c.key_tables.windows, 'phys:Space', 'CTRL|SHIFT'), { name = 'PopKeyTable' },
      'Ctrl+Shift+Space в таблице windows')
  end)
end)

T.check('WT-WIN-2 windows-mode: выходы из режима — только Esc, Enter без модификаторов и тумблер (PopKeyTable), в RESIZE — Esc и Enter', function()
  each_os(function(c)
    local want = { windows = ids(EXITS), resize_pane = ids({ { 'Escape' }, { 'Enter' } }) }
    for tname, expected in pairs(want) do
      local exits = {}
      for _, b in ipairs(c.key_tables[tname]) do
        if F.normalize_action(b.action).name == 'PopKeyTable' then exits[id_of(b.key, b.mods)] = true end
      end
      set_eq(exits, expected, tname .. ': клавиши, чьё действие — только PopKeyTable')
    end
  end)
end)

T.check('WT-WIN-2 Enter с модификатором — не выход: Shift+Enter (вне Windows и Ctrl+Enter) проглатываются, Ctrl+Shift+Enter — сплит, режим остаётся', function()
  each_os(function(c, os_name)
    local w = c.key_tables.windows
    absent(w, 'Enter', 'SHIFT', 'таблица windows')
    absent(c.keys, 'Enter', 'SHIFT', 'config.keys')
    if os_name == 'windows' then
      -- На Windows Ctrl+Enter — подмена WT-KEYS-10: в режиме — копия того же колбэка.
      local _, b = action(w, 'Enter', 'CTRL')
      local _, k = action(c.keys, 'Enter', 'CTRL')
      T.ok(rawequal(b.action, k.action), 'Ctrl+Enter в режиме — не то же действие, что вне режима')
    else
      absent(w, 'Enter', 'CTRL', 'таблица windows')
      absent(c.keys, 'Enter', 'CTRL', 'config.keys')
    end
    T.eq(entry_args(c).prevent_fallback, true, 'prevent_fallback у входа: без него Shift+Enter ушёл бы в программу')
    local split = { name = 'SplitPane', args = { { direction = 'Right' } } }
    T.eq(action(c.keys, 'Enter', 'CTRL|SHIFT'), split, 'Ctrl+Shift+Enter в config.keys')
    T.eq(action(w, 'Enter', 'CTRL|SHIFT'), split, 'Ctrl+Shift+Enter в таблице windows')
  end)
end)

T.check('WT-WIN-2 Ctrl+Shift+R и Ctrl+= / Ctrl+- (macOS: и Cmd) в режиме доходят до перечитывания конфига и overrides шрифта', function()
  each_os(function(c, os_name)
    local combos = { { 'phys:Equal', 'CTRL' }, { 'phys:Minus', 'CTRL' } }
    if os_name == 'macos' then
      combos[#combos + 1] = { 'phys:Equal', 'SUPER' }
      combos[#combos + 1] = { 'phys:Minus', 'SUPER' }
    end
    -- В таблицах режимов — копии с тем же действием, что вне режима.
    for _, tname in ipairs({ 'windows', 'resize_pane' }) do
      for _, p in ipairs({ { 'phys:R', 'CTRL|SHIFT' }, unpack(combos) }) do
        local _, b = action(c.key_tables[tname], p[1], p[2])
        local _, k = action(c.keys, p[1], p[2])
        T.ok(rawequal(b.action, k.action), ('%s %s: не то же действие, что вне режима: %s'):format(
          tname, id_of(p[1], p[2]), show(b.action)))
      end
    end
    T.eq(action(c.keys, 'phys:R', 'CTRL|SHIFT'), { name = 'ReloadConfiguration' }, 'Ctrl+Shift+R')
    for _, p in ipairs(combos) do
      local a = action(c.keys, p[1], p[2])
      local win = F.window({ effective_config = { font_size = 12.0 } })
      F.run_callback(a, win, F.pane())
      T.eq(#win.override_calls, 1, id_of(p[1], p[2]) .. ': set_config_overrides')
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-3 Таймаут бездействия
-- ---------------------------------------------------------------------------

T.check('WT-WIN-3 таймаут бездействия 5 с: вход задаёт timeout_milliseconds = 5000', function()
  each_os(function(c)
    T.eq(entry_args(c).timeout_milliseconds, 5000, 'timeout_milliseconds у входа в режим')
  end)
end)

T.check('WT-WIN-3 t и y — не команды режима (проглатываются, режим не продлевают), Ctrl+Shift+T — сочетание терминала в режиме, продлевает его', function()
  each_os(function(c)
    local w = c.key_tables.windows
    letter_absent(w, 't', 'NONE', 'таблица windows')
    letter_absent(w, 'y', 'NONE', 'таблица windows')
    local tab = { name = 'SpawnTab', args = { 'CurrentPaneDomain' } }
    T.eq(action(c.keys, 'phys:T', 'CTRL|SHIFT'), tab, 'Ctrl+Shift+T')
    T.eq(action(w, 'phys:T', 'CTRL|SHIFT'), tab, 'Ctrl+Shift+T в таблице windows')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-4 Клавиши без команды в режиме
-- ---------------------------------------------------------------------------

T.check('WT-WIN-4 windows-mode: вход в режимы проглатывает чужие клавиши — prevent_fallback у каждого входа в windows и resize_pane, until_unknown нет', function()
  each_os(function(c)
    local lists = { ['config.keys'] = c.keys, windows = c.key_tables.windows, resize_pane = c.key_tables.resize_pane }
    local seen = 0
    for where, list in pairs(lists) do
      for _, b in ipairs(list) do
        for _, a in ipairs(flatten(b.action)) do
          if a.name == 'ActivateKeyTable' and (a.args[1].name == 'windows' or a.args[1].name == 'resize_pane') then
            seen = seen + 1
            local what = ('%s %s → %s'):format(where, id_of(b.key, b.mods), a.args[1].name)
            T.eq(a.args[1].prevent_fallback, true, what .. ': prevent_fallback')
            T.ok(not a.args[1].until_unknown, what .. ': until_unknown')
          end
        end
      end
    end
    -- Вход в config.keys, его копия в RESIZE и r в WINDOWS.
    T.eq(seen, 3, 'входов в режимы')
  end)
end)

T.check('WT-WIN-4 буквы i, g, y, t, u без команды — нет ни в таблице режима, ни в config.keys: проглатываются', function()
  each_os(function(c)
    for _, l in ipairs({ 'i', 'g', 'y', 't', 'u' }) do
      letter_absent(c.key_tables.windows, l, 'NONE', 'таблица windows')
      letter_absent(c.keys, l, 'NONE', 'config.keys')
    end
    T.eq(entry_args(c).prevent_fallback, true, 'prevent_fallback у входа')
  end)
end)

T.check('WT-WIN-4 Shift+H и Ctrl+H проглатываются; из собственных команд с модификаторами только Shift+S и Ctrl+Shift+Space', function()
  each_os(function(c)
    for _, m in ipairs({ 'SHIFT', 'CTRL' }) do
      letter_absent(c.key_tables.windows, 'h', m, 'таблица windows')
      letter_absent(c.keys, 'h', m, 'config.keys')
    end
    local own = split_mode(c, 'windows')
    local with_mods = {}
    for id, b in pairs(own) do
      local _, m = F.norm_binding(b.key, b.mods)
      if m ~= 'NONE' then with_mods[id] = true end
    end
    set_eq(with_mods, ids({ { 'phys:S', 'SHIFT' }, { 'phys:Space', 'CTRL|SHIFT' } }),
      'собственные пары таблицы windows с модификаторами')
  end)
end)

T.check('WT-WIN-4 глобальные Ctrl+Shift+T, Ctrl+Shift+H, Ctrl+Tab, Ctrl+Shift+Enter и Shift+PageUp работают и в режиме — то же действие', function()
  each_os(function(c)
    local expect = {
      { 'phys:T', 'CTRL|SHIFT', { name = 'SpawnTab', args = { 'CurrentPaneDomain' } } },
      { 'phys:H', 'CTRL|SHIFT', { name = 'ActivatePaneDirection', args = { 'Left' } } },
      { 'Tab', 'CTRL', { name = 'ActivateTabRelative', args = { 1 } } },
      { 'Enter', 'CTRL|SHIFT', { name = 'SplitPane', args = { { direction = 'Right' } } } },
      { 'PageUp', 'SHIFT', { name = 'ScrollByPage', args = { -1 } } },
    }
    for _, e in ipairs(expect) do
      T.eq(action(c.keys, e[1], e[2]), e[3], id_of(e[1], e[2]) .. ' в config.keys')
      for _, tname in ipairs({ 'windows', 'resize_pane' }) do
        T.eq(action(c.key_tables[tname], e[1], e[2]), e[3], id_of(e[1], e[2]) .. ' в таблице ' .. tname)
      end
    end
  end)
end)

T.check('WT-WIN-4 цифры цифровой клавиатуры — не команды: 1…9 только на верхнем ряду (phys:1…9)', function()
  each_os(function(c)
    for _, b in ipairs(c.key_tables.windows) do
      local k = F.norm_key(b.key)
      T.ok(not k:find('Numpad', 1, true), 'клавиша цифровой клавиатуры в режиме: ' .. k)
    end
    local digits = {}
    for id, b in pairs(split_mode(c, 'windows')) do
      if F.norm_key(b.key):match('%d$') then digits[#digits + 1] = id end
    end
    table.sort(digits)
    local want = {}
    for i = 1, 9 do want[i] = id_of('phys:' .. i) end
    T.eq(digits, want, 'цифровые клавиши среди команд таблицы windows')
  end)
end)

T.check('WT-WIN-4 windows-mode: сочетания терминала есть в таблицах режимов — те же пары, что в config.keys, то же действие', function()
  each_os(function(c)
    for _, tname in ipairs({ 'windows', 'resize_pane' }) do
      local own, copies, keys = split_mode(c, tname)
      set_eq(id_set(vim.tbl_values(own)), OWN[tname], tname .. ': собственные команды')
      local want = {}
      for id in pairs(keys) do
        if not OWN[tname][id] then want[id] = true end
      end
      set_eq(copies, want, tname .. ': копии сочетаний терминала')
      -- Одна запись на пару (WT-KEYS-8).
      T.eq(#c.key_tables[tname], vim.tbl_count(own) + vim.tbl_count(copies), tname .. ': повторы пар')
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-5…10 Команды панелей
-- ---------------------------------------------------------------------------

local DIRS = {
  { 'phys:H', 'Left' }, { 'phys:J', 'Down' }, { 'phys:K', 'Up' }, { 'phys:L', 'Right' },
  { 'LeftArrow', 'Left' }, { 'DownArrow', 'Down' }, { 'UpArrow', 'Up' }, { 'RightArrow', 'Right' },
}

T.check('WT-WIN-5 h, j, k, l и стрелки — фокус влево, вниз, вверх, вправо, режим остаётся', function()
  each_os(function(c)
    for _, d in ipairs(DIRS) do
      T.eq(action(c.key_tables.windows, d[1]), { name = 'ActivatePaneDirection', args = { d[2] } }, d[1])
    end
  end)
end)

T.check('WT-WIN-5 выбор соседа и зум как у Ctrl+Shift+h/j/k/l и стрелок (WT-PANE-2): то же действие', function()
  each_os(function(c)
    for _, d in ipairs(DIRS) do
      T.eq(action(c.key_tables.windows, d[1]), action(c.keys, d[1], 'CTRL|SHIFT'), d[1] .. ' против Ctrl+Shift+' .. d[1])
    end
  end)
end)

T.check('WT-WIN-6 windows-mode: o — следующая панель по кругу, без перестановки панелей, режим остаётся', function()
  each_os(function(c)
    local o = action(c.key_tables.windows, 'phys:O')
    T.eq(o, { name = 'ActivatePaneDirection', args = { 'Next' } }, 'o')
    T.ok(stays(o), 'o выходит из режима: ' .. show(o))
  end)
end)

T.check('WT-WIN-7 q — сначала выход из режима, затем выбор панели по меткам a, s, d, f, g, h, j, k, l', function()
  each_os(function(c)
    T.eq(after_leave(action(c.key_tables.windows, 'phys:Q')), { name = 'PaneSelect', args = { { alphabet = 'asdfghjkl' } } }, 'q')
  end)
end)

T.check('WT-WIN-7 метки перехватывает сам режим — больше нет: q выключает режим раньше, чем появятся метки', function()
  each_os(function(c)
    local q = action(c.key_tables.windows, 'phys:Q')
    T.ok(leaves_first(q), 'q: ' .. show(q))
    -- Метки — буквы, у которых в режиме есть команды: при включённом режиме они
    -- выполнили бы команду вместо выбора.
    for _, l in ipairs({ 'a', 's', 'd', 'f', 'h', 'j', 'k', 'l' }) do action(c.key_tables.windows, 'phys:' .. l:upper()) end
  end)
end)

T.check('WT-WIN-8 v — сплит вправо, s — сплит вниз, режим остаётся', function()
  each_os(function(c)
    T.eq(action(c.key_tables.windows, 'phys:V'), { name = 'SplitPane', args = { { direction = 'Right' } } }, 'v')
    T.eq(action(c.key_tables.windows, 'phys:S'), { name = 'SplitPane', args = { { direction = 'Down' } } }, 's')
  end)
end)

T.check('WT-WIN-8 новая панель как после Ctrl+Shift+Enter и Ctrl+Shift+Alt+Enter (WT-PANE-1): то же действие', function()
  each_os(function(c)
    T.eq(action(c.key_tables.windows, 'phys:V'), action(c.keys, 'Enter', 'CTRL|SHIFT'), 'v против Ctrl+Shift+Enter')
    T.eq(action(c.key_tables.windows, 'phys:S'), action(c.keys, 'Enter', 'CTRL|SHIFT|ALT'), 's против Ctrl+Shift+Alt+Enter')
  end)
end)

T.check('WT-WIN-9 z — зум туда и обратно, как Ctrl+Shift+Z, режим остаётся', function()
  each_os(function(c)
    T.eq(action(c.key_tables.windows, 'phys:Z'), { name = 'TogglePaneZoomState' }, 'z')
    T.eq(action(c.key_tables.windows, 'phys:Z'), action(c.keys, 'phys:Z', 'CTRL|SHIFT'), 'z против Ctrl+Shift+Z')
  end)
end)

T.check('WT-WIN-10 x — сначала выход из режима, затем закрыть панель по правилам Ctrl+Shift+W (с подтверждением)', function()
  each_os(function(c)
    local close = after_leave(action(c.key_tables.windows, 'phys:X'))
    T.eq(close, { name = 'CloseCurrentPane', args = { { confirm = true } } }, 'x')
    T.eq(close, action(c.keys, 'phys:W', 'CTRL|SHIFT'), 'x против Ctrl+Shift+W')
  end)
end)

T.check('WT-WIN-10 запрос при включённом режиме — x выключает режим раньше, чем откроется запрос: y, n и Esc достаются запросу', function()
  each_os(function(c)
    local x = action(c.key_tables.windows, 'phys:X')
    T.ok(leaves_first(x), 'x: ' .. show(x))
    T.eq(after_leave(x).name, 'CloseCurrentPane', 'x')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-11 Подрежим RESIZE
-- ---------------------------------------------------------------------------

T.check('WT-WIN-11 r заменяет WINDOWS подрежимом RESIZE: replace_current, липкий, таймаут 5 с', function()
  each_os(function(c)
    local a = action(c.key_tables.windows, 'phys:R')
    T.eq(a, { name = 'ActivateKeyTable', args = { {
      name = 'resize_pane', one_shot = false, prevent_fallback = true, replace_current = true,
      timeout_milliseconds = 5000,
    } } }, 'r')
    T.ok(c.key_tables.resize_pane, 'нет config.key_tables.resize_pane')
  end)
end)

T.check('WT-WIN-11 серия сдвигов: h/← и l/→ — граница на 3 ячейки влево и вправо, k/↑ и j/↓ — вверх и вниз', function()
  each_os(function(c)
    for _, m in ipairs(RESIZE_MOVES) do
      T.eq(action(c.key_tables.resize_pane, m[1]), { name = 'AdjustPaneSize', args = { { m[2], 3 } } }, m[1])
    end
  end)
end)

T.check('WT-WIN-11 Esc и Enter выключают RESIZE сразу в обычный ввод', function()
  each_os(function(c)
    T.eq(action(c.key_tables.resize_pane, 'Escape'), { name = 'PopKeyTable' }, 'Esc')
    T.eq(action(c.key_tables.resize_pane, 'Enter'), { name = 'PopKeyTable' }, 'Enter')
    -- Слой WINDOWS под RESIZE не остаётся: r его заменяет (replace_current).
    T.eq(action(c.key_tables.windows, 'phys:R').args[1].replace_current, true, 'replace_current у r')
  end)
end)

T.check('WT-WIN-11 команд WINDOWS в RESIZE нет: 8 сдвигов и 2 выхода плюс сочетания терминала, остальное проглатывается', function()
  each_os(function(c)
    local own = split_mode(c, 'resize_pane')
    set_eq(id_set(vim.tbl_values(own)), OWN.resize_pane, 'собственные пары таблицы resize_pane')
    for _, l in ipairs({ 'v', 'x', 'q', 'i' }) do letter_absent(c.key_tables.resize_pane, l, 'NONE', 'таблица resize_pane') end
    T.eq(action(c.key_tables.windows, 'phys:R').args[1].prevent_fallback, true, 'prevent_fallback у RESIZE')
  end)
end)

T.check('WT-WIN-11 Ctrl+Shift+Space из RESIZE включает WINDOWS поверх него (копия входа, без replace_current)', function()
  each_os(function(c)
    local _, b = action(c.key_tables.resize_pane, 'phys:Space', 'CTRL|SHIFT')
    local _, k = action(c.keys, 'phys:Space', 'CTRL|SHIFT')
    T.ok(rawequal(b.action, k.action), 'Ctrl+Shift+Space в RESIZE — не вход в WINDOWS: ' .. show(b.action))
    local args = entry_args(c)
    T.eq(args.name, 'windows', 'вход')
    T.ok(not args.replace_current, 'вход в WINDOWS заменяет RESIZE, а не ложится поверх')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-12…18 Команды, которые выходят из режима
-- ---------------------------------------------------------------------------

T.check('WT-WIN-12 a — сначала выход из режима, затем готовый лэйаут на текущей панели', function()
  each_os(function(c)
    local cb = after_leave(action(c.key_tables.windows, 'phys:A'))
    T.eq(cb.name, 'Callback', 'второй шаг a')
    local pane = F.pane({ id = 1 })
    F.run_callback(cb, F.window({ pane = pane }), pane)
    T.eq(pane.log, {
      { op = 'split', pane = 1, args = { direction = 'Right', size = 0.35 }, new = 2 },
      { op = 'split', pane = 2, args = { direction = 'Bottom', size = 0.5 }, new = 3 },
      { op = 'activate', pane = 1 },
    }, 'операции лэйаута')
  end)
end)

T.check('WT-WIN-13 c — новая вкладка как Ctrl+Shift+T, n и p — следующая и предыдущая по кругу, режим остаётся', function()
  each_os(function(c)
    local w = c.key_tables.windows
    T.eq(action(w, 'phys:C'), action(c.keys, 'phys:T', 'CTRL|SHIFT'), 'c против Ctrl+Shift+T')
    T.eq(action(w, 'phys:C'), { name = 'SpawnTab', args = { 'CurrentPaneDomain' } }, 'c')
    T.eq(action(w, 'phys:N'), { name = 'ActivateTabRelative', args = { 1 } }, 'n')
    T.eq(action(w, 'phys:P'), { name = 'ActivateTabRelative', args = { -1 } }, 'p')
  end)
end)

T.check('WT-WIN-13 1…9 — вкладка с этим номером, по позиции клавиши верхнего ряда (и на русской раскладке)', function()
  each_os(function(c)
    for i = 1, 9 do
      local a, b = action(c.key_tables.windows, 'phys:' .. i)
      T.ok(b.key:match('^phys:'), 'цифра не по позиции: ' .. tostring(b.key))
      T.eq(a, { name = 'ActivateTab', args = { i - 1 } }, tostring(i))
    end
  end)
end)

T.check('WT-WIN-14 запятая — сначала выход из режима, затем запрос «Имя вкладки:»', function()
  each_os(function(c)
    local p = after_leave(action(c.key_tables.windows, 'phys:Comma'))
    T.eq(strip(p), { name = 'PromptInputLine', args = { { description = 'Имя вкладки:', action = { name = 'Callback' } } } },
      'второй шаг запятой')
  end)
end)

T.check('WT-WIN-15 w — сначала выход из режима, затем лаунчер воркспейсов и вкладок с нечётким поиском', function()
  each_os(function(c)
    local p = after_leave(action(c.key_tables.windows, 'phys:W'))
    T.eq(p, { name = 'ShowLauncherArgs', args = { { flags = 'FUZZY|TABS|WORKSPACES' } } }, 'второй шаг w')
  end)
end)

T.check('WT-WIN-15 Shift+S — сначала выход, затем запрос «Новый/существующий воркспейс:»; s без Shift — сплит вниз', function()
  each_os(function(c)
    local w = c.key_tables.windows
    local p = after_leave(action(w, 'phys:S', 'SHIFT'))
    T.eq(strip(p), { name = 'PromptInputLine', args = { {
      description = 'Новый/существующий воркспейс:', action = { name = 'Callback' },
    } } }, 'второй шаг Shift+S')
    T.eq(action(w, 'phys:S', 'NONE'), { name = 'SplitPane', args = { { direction = 'Down' } } }, 's без Shift')
  end)
end)

T.check('WT-WIN-16 [ — сначала выход из режима, затем copy mode', function()
  each_os(function(c)
    T.eq(after_leave(action(c.key_tables.windows, 'phys:LeftBracket')), { name = 'ActivateCopyMode' }, 'второй шаг [')
  end)
end)

T.check('WT-WIN-16 f — выход и поиск с пустым шаблоном без учёта регистра; Space — выход и QuickSelect', function()
  each_os(function(c)
    local w = c.key_tables.windows
    T.eq(after_leave(action(w, 'phys:F')), { name = 'Search', args = { { CaseInSensitiveString = '' } } }, 'второй шаг f')
    T.eq(after_leave(action(w, 'phys:Space')), { name = 'QuickSelect' }, 'второй шаг Space')
  end)
end)

T.check('WT-WIN-17 b — сначала выход из режима, затем история панели в nvim новой вкладкой', function()
  each_os(function(c)
    local cb = after_leave(action(c.key_tables.windows, 'phys:B'))
    T.eq(cb.name, 'Callback', 'второй шаг b')
    local pane = F.pane({ text = 'история\n' })
    local win = F.window({ pane = pane })
    F.run_callback(cb, win, pane)
    T.eq(#win.performed, 1, 'действий колбэка')
    local spawn = F.normalize_action(win.performed[1])
    T.eq(spawn.name, 'SpawnCommandInNewTab', 'колбэк b открывает вкладку')
    T.eq(spawn.args[1].args[1], 'nvim', 'программа новой вкладки')
  end)
end)

T.check('WT-WIN-18 e — сначала выход из режима, затем выбор символа с копированием в буфер обмена', function()
  each_os(function(c)
    T.eq(after_leave(action(c.key_tables.windows, 'phys:E')), { name = 'CharSelect', args = { { copy_on_select = true } } },
      'второй шаг e')
  end)
end)

T.check('WT-WIN-18 ; , m и d — выход, затем палитра команд, полный экран (на macOS не нативный), debug overlay', function()
  each_os(function(c, os_name)
    local w = c.key_tables.windows
    T.eq(after_leave(action(w, 'phys:Semicolon')), { name = 'ActivateCommandPalette' }, 'второй шаг ;')
    T.eq(after_leave(action(w, 'phys:M')), { name = 'ToggleFullScreen' }, 'второй шаг m')
    T.eq(after_leave(action(w, 'phys:D')), { name = 'ShowDebugOverlay' }, 'второй шаг d')
    if os_name == 'macos' then
      T.ok(not c.native_macos_fullscreen_mode, 'native_macos_fullscreen_mode включён')
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-19 Какие команды оставляют режим, а какие выходят
-- ---------------------------------------------------------------------------

T.check('WT-WIN-19 состав таблицы windows: три группы команд и три выхода, остальное — копии сочетаний терминала', function()
  each_os(function(c)
    set_eq(id_set(vim.tbl_values((split_mode(c, 'windows')))), union(COMMANDS, ids(EXITS)), 'собственные пары таблицы windows')
  end)
end)

T.check('WT-WIN-19 навигация, сплиты, вкладки (h…p, стрелки, 1…9) оставляют режим включённым', function()
  each_os(function(c)
    for _, p in ipairs(STAY) do
      local a = action(c.key_tables.windows, p[1], p[2])
      T.ok(stays(a), id_of(p[1], p[2]) .. ' выходит из режима или меняет таблицу: ' .. show(a))
    end
  end)
end)

T.check('WT-WIN-19 r заменяет режим подрежимом RESIZE', function()
  each_os(function(c)
    local a = action(c.key_tables.windows, 'phys:R')
    T.eq(a.name, 'ActivateKeyTable', 'r')
    T.eq({ a.args[1].name, a.args[1].replace_current }, { 'resize_pane', true }, 'r: таблица и replace_current')
  end)
end)

T.check('WT-WIN-19 windows-mode: какие команды выходят из режима — q, x, a, запятая, w, Shift+S, [, f, Space, b, e, ;, m, d начинаются с ClearKeyTableStack', function()
  each_os(function(c)
    for _, p in ipairs(EXIT_FIRST) do
      local a = action(c.key_tables.windows, p[1], p[2])
      T.ok(leaves_first(a), id_of(p[1], p[2]) .. ': не Multiple { ClearKeyTableStack, … }: ' .. show(a))
    end
  end)
end)

T.check('WT-WIN-19 q и x открывают экран поверх панели при включённом режиме — больше нет: сначала выход из режима', function()
  each_os(function(c)
    T.eq(after_leave(action(c.key_tables.windows, 'phys:Q')).name, 'PaneSelect', 'q')
    T.eq(after_leave(action(c.key_tables.windows, 'phys:X')).name, 'CloseCurrentPane', 'x')
  end)
end)

T.check('WT-WIN-19 windows-mode: сочетания, открывающие экран, выходят из режима — всё, что открывает экран, начинается с ClearKeyTableStack', function()
  each_os(function(c, os_name)
    for _, tname in ipairs({ 'windows', 'resize_pane' }) do
      for _, b in ipairs(c.key_tables[tname]) do
        local a = F.normalize_action(b.action)
        if opens_screen(a) then
          T.ok(leaves_first(a), ('%s %s открывает экран при включённом режиме: %s'):format(tname, id_of(b.key, b.mods), show(a)))
        end
      end
      -- Сами сочетания терминала: в режиме — выход и то же действие.
      for _, p in ipairs(SCREEN_COMBOS[os_name]) do
        T.eq(after_leave(action(c.key_tables[tname], p[1], p[2])), action(c.keys, p[1], p[2]),
          tname .. ' ' .. id_of(p[1], p[2]))
      end
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-20 Раскладка и платформа
-- ---------------------------------------------------------------------------

T.check('WT-WIN-20 клавиши WINDOWS и RESIZE — только phys: и именованные, без символов раскладки', function()
  each_os(function(c)
    for _, tname in ipairs({ 'windows', 'resize_pane' }) do
      for i, b in ipairs(c.key_tables[tname]) do
        local k = b.key
        local named = type(k) == 'string' and #k > 1 and not k:find(':', 1, true)
        T.ok(type(k) == 'string' and (k:match('^phys:') or named),
          ('%s[%d]: клавиша по символу раскладки: %s'):format(tname, i, tostring(k)))
      end
    end
  end)
end)

-- ЙЦУКЕН (RussianWin): русская буква → позиция клавиши на US-ANSI.
local RU = {
  { 'р', 'phys:H' }, { 'м', 'phys:V' }, { 'ы', 'phys:S' }, { 'х', 'phys:LeftBracket' },
  { 'б', 'phys:Comma' }, { 'ж', 'phys:Semicolon' }, { 'ц', 'phys:W' },
}

T.check('WT-WIN-20 русская раскладка: р, м, ы, х, б, ж, ц — те же привязки по позиции, что h, v, s, [, запятая, ;, w', function()
  each_os(function(c)
    local w = c.key_tables.windows
    for _, p in ipairs(RU) do
      local _, b = action(w, p[2])
      T.ok(b.key:match('^phys:'), p[1] .. ': привязка не по позиции: ' .. tostring(b.key))
      absent(w, 'mapped:' .. p[1], 'NONE', 'таблица windows')
    end
  end)
end)

T.check('WT-WIN-20 команды WINDOWS и RESIZE одинаковы на Windows, macOS и Linux (копии сочетаний — по config.keys своей платформы)', function()
  local base = load('windows').config
  each_os(function(c, os_name)
    if os_name == 'windows' then return end
    for _, tname in ipairs({ 'windows', 'resize_pane' }) do
      local own, base_own = split_mode(c, tname), split_mode(base, tname)
      T.eq(strip(own), strip(base_own), tname .. ' против windows')
    end
  end)
end)

T.check('WT-WIN-20 macOS и Shift+S: привязка по позиции клавиши (phys:S + SHIFT) открывает запрос воркспейса', function()
  each_os(function(c)
    local a, b = action(c.key_tables.windows, 'phys:S', 'SHIFT')
    T.eq(b.key, 'phys:S', 'клавиша Shift+S')
    T.eq(after_leave(a).args[1].description, 'Новый/существующий воркспейс:', 'Shift+S')
  end, { 'macos' })
end)

-- ---------------------------------------------------------------------------
-- WT-WIN-21 Режим поверх экранов и оверлеев
-- ---------------------------------------------------------------------------

T.check('WT-WIN-21 запрос от Ctrl+Shift+W — в режиме сочетание сначала выключает режим, y, n и Esc достаются запросу', function()
  each_os(function(c)
    local close = { name = 'CloseCurrentPane', args = { { confirm = true } } }
    T.eq(action(c.keys, 'phys:W', 'CTRL|SHIFT'), close, 'Ctrl+Shift+W')
    T.eq(after_leave(action(c.key_tables.windows, 'phys:W', 'CTRL|SHIFT')), close, 'Ctrl+Shift+W в режиме')
  end)
end)

T.check('WT-WIN-21 QuickSelect от Ctrl+Shift+U — режим выключается до меток: s копирует фрагмент, а не делит панель', function()
  each_os(function(c)
    T.eq(action(c.keys, 'phys:U', 'CTRL|SHIFT'), { name = 'QuickSelect' }, 'Ctrl+Shift+U')
    T.eq(after_leave(action(c.key_tables.windows, 'phys:U', 'CTRL|SHIFT')), { name = 'QuickSelect' }, 'Ctrl+Shift+U в режиме')
  end)
end)

-- Команды режима поверх copy mode: те, чьих пар нет в copy_mode (copy_mode —
-- встроенная таблица из фикстуры, переведённая конфигом на phys:). Space режима —
-- phys:Space, а в copy_mode пробел — символ 'mapped: ': для WezTerm это разные
-- клавиши (F.norm_key; сверено Core с show-keys 20240203).
T.check('WT-WIN-21 copy mode от Ctrl+Shift+X — сначала выход из режима; режим из copy mode: клавиши copy mode важнее, команды режима — только a, c, d, m, p, r, s, x, z, 1…9, [, Shift+S и Space', function()
  each_os(function(c)
    T.eq(action(c.keys, 'phys:X', 'CTRL|SHIFT'), { name = 'ActivateCopyMode' }, 'Ctrl+Shift+X')
    T.eq(after_leave(action(c.key_tables.windows, 'phys:X', 'CTRL|SHIFT')), { name = 'ActivateCopyMode' },
      'Ctrl+Shift+X в режиме')
    local cm = c.key_tables.copy_mode
    T.ok(cm, 'нет config.key_tables.copy_mode')
    for _, k in ipairs({ 'phys:H', 'phys:J', 'phys:K', 'phys:L', 'phys:V', 'phys:Y',
      'LeftArrow', 'DownArrow', 'UpArrow', 'RightArrow', 'Escape' }) do
      action(cm, k)
    end
    local in_copy = id_set(cm)
    local through = {}
    for id in pairs(COMMANDS) do
      if not in_copy[id] then through[id] = true end
    end
    local want = { { 'phys:A' }, { 'phys:C' }, { 'phys:D' }, { 'phys:M' }, { 'phys:P' }, { 'phys:R' },
      { 'phys:S' }, { 'phys:X' }, { 'phys:Z' }, { 'phys:LeftBracket' }, { 'phys:S', 'SHIFT' }, { 'phys:Space' } }
    for i = 1, 9 do want[#want + 1] = { 'phys:' .. i } end
    set_eq(through, ids(want), 'команды режима, которых нет в copy_mode')
  end)
end)

T.check('WT-WIN-21 набор шаблона поиска: в search_mode нет голых букв, l и o — команды режима, g — нет', function()
  each_os(function(c)
    local sm = c.key_tables.search_mode
    T.ok(sm, 'нет config.key_tables.search_mode')
    for _, b in ipairs(sm) do
      local k, m = F.norm_binding(b.key, b.mods)
      local letter = k:match('^phys:(%a)$') or k:match('^mapped:(%a)$')
      T.ok(not (letter and (m == 'NONE' or m == 'SHIFT')), 'буква в search_mode: ' .. k .. ' ' .. m)
    end
    action(c.key_tables.windows, 'phys:L')
    action(c.key_tables.windows, 'phys:O')
    letter_absent(c.key_tables.windows, 'g', 'NONE', 'таблица windows')
  end)
end)

T.check('WT-WIN-21 вход в режим из copy mode: Ctrl+Shift+Space в copy_mode не занят, срабатывает вход из config.keys', function()
  each_os(function(c)
    absent(c.key_tables.copy_mode, 'phys:Space', 'CTRL|SHIFT', 'таблица copy_mode')
    T.eq(entry_args(c).name, 'windows', 'вход')
  end)
end)

T.check('WT-WIN-21 таймаут освобождает экран: режим поверх экрана тоже гаснет через 5 с', function()
  each_os(function(c)
    T.eq(entry_args(c).timeout_milliseconds, 5000, 'timeout_milliseconds у входа в режим')
  end)
end)

T.finish()
