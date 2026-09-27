-- Проверки capability wezterm-panes-tabs (WT-PANE-1…13), add-wezterm-spec-checks, задача 3.6.
--
-- Характеризация базовой линии (design, решение 4): код как есть. Каждая
-- проверка — сценарий требования в части привязок и колбэков:
--   * прямые сочетания в config.keys (без режима WINDOWS) и настройки конфига,
--     от которых зависит сценарий (например, unzoom_on_switch_pane);
--   * колбэки общих с режимом WINDOWS действий — готовый лэйаут, запросы
--     воркспейса и имени вкладки — на поддельных окне и панели
--     (tests/wezterm/fake_wezterm.lua); сами действия берутся из таблицы режима,
--     потому что прямых сочетаний у них нет (WT-PANE-9, WT-PANE-10, WT-PANE-11).
-- Платформы «все» — три тройки; WT-PANE-8 — macOS и отрицательный сценарий Windows.
--
-- Не видно из конфига — ручная часть (чек-листы tests/manual/ ведёт
-- review-baseline), SKIP для неё не пишется:
--   * геометрия и фокус после сплита, «нет места» у прямого сплита (WT-PANE-1);
--   * выбор соседа, где фокус был последним (WT-PANE-2); вид при зуме (WT-PANE-3);
--   * запрос подтверждения: текст, y/n/Esc, клики, русская раскладка, судьба
--     вкладки, окна и воркспейса после последней панели (WT-PANE-4, WT-PANE-8);
--   * порядок и номера вкладок, куда попадает новое окно (WT-PANE-5…7);
--   * лаунчер и воркспейсы в работе: список, фильтр, время жизни, окна (WT-PANE-10);
--   * Esc при непустой строке запроса (WT-PANE-10, WT-PANE-11);
--   * откуда WezTerm берёт каталог: OSC 7, процесс на переднем плане, pwsh (WT-PANE-12);
--   * мышь в работе: перетаскивание, клики, колесо, Tab Navigator (WT-PANE-13).
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

local function strip(v)
  if type(v) ~= 'table' then return v end
  if v.name == 'Callback' and type(v.fn) == 'function' then return { name = 'Callback' } end
  local out = {}
  for k, x in pairs(v) do out[k] = strip(x) end
  return out
end

local function show(a)
  return vim.inspect(strip(F.normalize_action(a)), { newline = ' ', indent = '' })
end

--- Действие пары (key, mods) — последняя запись, как у WezTerm; нет — ошибка.
local function action(list, key, mods)
  local b = F.find_binding(list, key, mods)
  if not b then error('нет привязки ' .. id_of(key, mods), 2) end
  return F.normalize_action(b.action), b
end

local function absent(list, key, mods, where)
  local b = F.find_binding(list, key, mods)
  if b then
    error(('%s: есть привязка %s → %s'):format(where, id_of(key, mods), show(b.action)), 2)
  end
end

--- Клавиши нет ни по позиции (phys:X), ни по символу (mapped:x) с этими модификаторами.
local function char_absent(list, ch, mods, where)
  absent(list, 'phys:' .. ch:upper(), mods, where)
  absent(list, 'mapped:' .. ch:lower(), mods, where)
end

--- Второй шаг Multiple { ClearKeyTableStack, <действие> } привязки таблицы режима
--- (команда сначала выключает режим, WT-WIN-19).
local function mode_command(c, key, mods)
  local a = action(c.key_tables.windows, key, mods)
  T.ok(a.name == 'Multiple' and F.normalize_action(a.args[1][1]).name == 'ClearKeyTableStack',
    id_of(key, mods) .. ': ожидался Multiple { ClearKeyTableStack, … }, получено ' .. show(a))
  return F.normalize_action(a.args[1][2])
end

--- Колбэк готового лэйаута: у него нет прямого сочетания, он висит на a в режиме WINDOWS.
local function ready_layout(c)
  local cb = mode_command(c, 'phys:A')
  T.eq(cb.name, 'Callback', 'a в режиме WINDOWS')
  return cb
end

--- Колбэк запроса: запятая (имя вкладки) или Shift+S (воркспейс) в режиме WINDOWS.
local function prompt(c, key, mods, description)
  local p = mode_command(c, key, mods)
  T.eq(p.name, 'PromptInputLine', id_of(key, mods))
  T.eq(p.args[1].description, description, id_of(key, mods) .. ': текст запроса')
  T.eq(p.args[1].action.name, 'Callback', id_of(key, mods) .. ': действие запроса')
  return p.args[1].action
end

--- Путь к первому полю с именем key где-либо внутри v (колбэки не обходятся).
local function find_field(v, key, path)
  if type(v) ~= 'table' then return nil end
  if v.name == 'Callback' and type(v.fn) == 'function' then return nil end
  local keys = vim.tbl_keys(v)
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local p = (path or '') .. '.' .. tostring(k)
    if k == key then return p end
    local found = find_field(v[k], key, p)
    if found then return found end
  end
  return nil
end

--- Все действия, включая вложенные в Multiple.
local function flatten(a, out)
  a = F.normalize_action(a)
  out = out or {}
  out[#out + 1] = a
  if type(a) == 'table' and a.name == 'Multiple' then
    for _, x in ipairs(a.args[1]) do flatten(x, out) end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- WT-PANE-1 Сплит без режима
-- ---------------------------------------------------------------------------

T.check('WT-PANE-1 Ctrl+Shift+Enter — сплит вправо: шелл по умолчанию, тот же домен, сочетание забирает WezTerm', function()
  each_os(function(c)
    T.eq(action(c.keys, 'Enter', 'CTRL|SHIFT'), { name = 'SplitPane', args = { { direction = 'Right' } } },
      'Ctrl+Shift+Enter')
  end)
end)

T.check('WT-PANE-1 Ctrl+Shift+Alt+Enter — сплит вниз', function()
  each_os(function(c)
    T.eq(action(c.keys, 'Enter', 'CTRL|SHIFT|ALT'), { name = 'SplitPane', args = { { direction = 'Down' } } },
      'Ctrl+Shift+Alt+Enter')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-2 Фокус по направлению, WT-PANE-3 Зум
-- ---------------------------------------------------------------------------

local LETTER_DIRS = { { 'phys:H', 'Left' }, { 'phys:J', 'Down' }, { 'phys:K', 'Up' }, { 'phys:L', 'Right' } }
local ARROW_DIRS = { { 'LeftArrow', 'Left' }, { 'DownArrow', 'Down' }, { 'UpArrow', 'Up' }, { 'RightArrow', 'Right' } }

T.check('WT-PANE-2 Ctrl+Shift+H, J, K, L — фокус влево, вниз, вверх, вправо, до nvim сочетание не доходит', function()
  each_os(function(c)
    for _, d in ipairs(LETTER_DIRS) do
      T.eq(action(c.keys, d[1], 'CTRL|SHIFT'), { name = 'ActivatePaneDirection', args = { d[2] } }, 'Ctrl+Shift+' .. d[1])
    end
  end)
end)

T.check('WT-PANE-2 Ctrl+Shift+←, ↓, ↑, → — фокус в ту же сторону', function()
  each_os(function(c)
    for _, d in ipairs(ARROW_DIRS) do
      T.eq(action(c.keys, d[1], 'CTRL|SHIFT'), { name = 'ActivatePaneDirection', args = { d[2] } }, 'Ctrl+Shift+' .. d[1])
    end
  end)
end)

T.check('WT-PANE-2 панель развёрнута зумом: переход снимает зум (unzoom_on_switch_pane не выключен)', function()
  each_os(function(c)
    T.ok(c.unzoom_on_switch_pane ~= false, 'unzoom_on_switch_pane = false')
  end)
end)

T.check('WT-PANE-2 русская раскладка: Ctrl+Shift+h, j, k, l заданы по позиции клавиши', function()
  each_os(function(c)
    for _, d in ipairs(LETTER_DIRS) do
      local _, b = action(c.keys, d[1], 'CTRL|SHIFT')
      T.ok(b.key:match('^phys:'), 'не по позиции: ' .. tostring(b.key))
    end
  end)
end)

T.check('WT-PANE-3 Ctrl+Shift+Z — зум текущей панели туда и обратно', function()
  each_os(function(c)
    T.eq(action(c.keys, 'phys:Z', 'CTRL|SHIFT'), { name = 'TogglePaneZoomState' }, 'Ctrl+Shift+Z')
  end)
end)

T.check('WT-PANE-3 зум снимает переход в другую панель (unzoom_on_switch_pane не выключен)', function()
  each_os(function(c)
    T.ok(c.unzoom_on_switch_pane ~= false, 'unzoom_on_switch_pane = false')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-4 Закрытие панели
-- ---------------------------------------------------------------------------

T.check('WT-PANE-4 Ctrl+Shift+W — закрыть текущую панель, с запросом, если в ней не только шелл', function()
  each_os(function(c)
    T.eq(action(c.keys, 'phys:W', 'CTRL|SHIFT'), { name = 'CloseCurrentPane', args = { { confirm = true } } },
      'Ctrl+Shift+W')
  end)
end)

T.check('WT-PANE-4 без вопроса — только шеллы из списка WezTerm по умолчанию (skip_close_confirmation_for_processes_named не задан)', function()
  each_os(function(c)
    T.eq(c.skip_close_confirmation_for_processes_named, nil, 'skip_close_confirmation_for_processes_named')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-5…7 Вкладки и окна
-- ---------------------------------------------------------------------------

T.check('WT-PANE-5 Ctrl+Shift+T — новая вкладка в домене текущей панели, по позиции клавиши (и на русской раскладке)', function()
  each_os(function(c)
    local a, b = action(c.keys, 'phys:T', 'CTRL|SHIFT')
    T.eq(a, { name = 'SpawnTab', args = { 'CurrentPaneDomain' } }, 'Ctrl+Shift+T')
    T.eq(b.key, 'phys:T', 'клавиша Ctrl+Shift+T')
  end)
end)

T.check('WT-PANE-5 macOS: Cmd+T — то же, что Ctrl+Shift+T', function()
  each_os(function(c)
    T.eq(action(c.keys, 'phys:T', 'SUPER'), action(c.keys, 'phys:T', 'CTRL|SHIFT'), 'Cmd+T против Ctrl+Shift+T')
  end, { 'macos' })
end)

T.check('WT-PANE-6 Ctrl+Tab и Ctrl+Shift+PageDown — следующая вкладка, Ctrl+Shift+Tab и Ctrl+Shift+PageUp — предыдущая, по кругу', function()
  each_os(function(c)
    local next_tab = { name = 'ActivateTabRelative', args = { 1 } }
    local prev_tab = { name = 'ActivateTabRelative', args = { -1 } }
    T.eq(action(c.keys, 'Tab', 'CTRL'), next_tab, 'Ctrl+Tab')
    T.eq(action(c.keys, 'PageDown', 'CTRL|SHIFT'), next_tab, 'Ctrl+Shift+PageDown')
    T.eq(action(c.keys, 'Tab', 'CTRL|SHIFT'), prev_tab, 'Ctrl+Shift+Tab')
    T.eq(action(c.keys, 'PageUp', 'CTRL|SHIFT'), prev_tab, 'Ctrl+Shift+PageUp')
  end)
end)

T.check('WT-PANE-6 Ctrl+Shift+1…9 — вкладка с этим номером, цифры по позиции клавиши (и на русской раскладке)', function()
  each_os(function(c)
    for i = 1, 9 do
      local a, b = action(c.keys, 'phys:' .. i, 'CTRL|SHIFT')
      T.eq(a, { name = 'ActivateTab', args = { i - 1 } }, 'Ctrl+Shift+' .. i)
      T.eq(b.key, 'phys:' .. i, 'клавиша Ctrl+Shift+' .. i)
    end
  end)
end)

T.check('WT-PANE-6 соседние сочетания остаются программе: голые Tab, Shift+Tab, Ctrl+PageUp и Ctrl+PageDown', function()
  each_os(function(c)
    T.eq(c.disable_default_key_bindings, true, 'встроенные привязки WezTerm (в них есть Ctrl+PageUp/PageDown)')
    for _, p in ipairs({ { 'Tab', 'NONE' }, { 'Tab', 'SHIFT' }, { 'PageUp', 'CTRL' }, { 'PageDown', 'CTRL' } }) do
      absent(c.keys, p[1], p[2], 'config.keys')
    end
  end)
end)

T.check('WT-PANE-7 Ctrl+Shift+N — новое окно, по позиции клавиши (и на русской раскладке); на macOS ещё Cmd+N', function()
  each_os(function(c, os_name)
    local a, b = action(c.keys, 'phys:N', 'CTRL|SHIFT')
    T.eq(a, { name = 'SpawnWindow' }, 'Ctrl+Shift+N')
    T.eq(b.key, 'phys:N', 'клавиша Ctrl+Shift+N')
    if os_name == 'macos' then
      T.eq(action(c.keys, 'phys:N', 'SUPER'), { name = 'SpawnWindow' }, 'Cmd+N')
    end
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-8 Cmd-сочетания macOS
-- ---------------------------------------------------------------------------

T.check('WT-PANE-8 macOS: Cmd+T, Cmd+N, Cmd+H, Cmd+M и Cmd+Q — вкладка, окно, скрыть, свернуть, выход', function()
  each_os(function(c)
    T.eq(action(c.keys, 'phys:T', 'SUPER'), { name = 'SpawnTab', args = { 'CurrentPaneDomain' } }, 'Cmd+T')
    T.eq(action(c.keys, 'phys:N', 'SUPER'), { name = 'SpawnWindow' }, 'Cmd+N')
    T.eq(action(c.keys, 'phys:H', 'SUPER'), { name = 'HideApplication' }, 'Cmd+H')
    T.eq(action(c.keys, 'phys:M', 'SUPER'), { name = 'Hide' }, 'Cmd+M')
    T.eq(action(c.keys, 'phys:Q', 'SUPER'), { name = 'QuitApplication' }, 'Cmd+Q')
  end, { 'macos' })
end)

-- QuitApplication в WezTerm 20240203 спрашивает, пока window_close_confirmation
-- не 'NeverPrompt' (по умолчанию 'AlwaysPrompt').
T.check('WT-PANE-8 Cmd+Q всегда спрашивает: window_close_confirmation не выключен', function()
  each_os(function(c)
    T.ok(c.window_close_confirmation ~= 'NeverPrompt', 'window_close_confirmation = NeverPrompt')
  end, { 'macos' })
end)

T.check('WT-PANE-8 macOS: Cmd+W и Cmd+1…9 не привязаны — ни панель, ни вкладку не закрывают и не переключают', function()
  each_os(function(c)
    T.eq(c.disable_default_key_bindings, true, 'встроенные привязки WezTerm (в них есть Cmd+W и Cmd+цифры)')
    char_absent(c.keys, 'w', 'SUPER', 'config.keys')
    for i = 1, 9 do char_absent(c.keys, tostring(i), 'SUPER', 'config.keys') end
  end, { 'macos' })
end)

T.check('WT-PANE-8 на Windows Cmd-привязок нет: Win+T, Win+N, Win+H, Win+M и Win+Q остаются системе', function()
  each_os(function(c)
    for _, ch in ipairs({ 't', 'n', 'h', 'm', 'q' }) do char_absent(c.keys, ch, 'SUPER', 'config.keys') end
  end, { 'windows' })
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-9 Готовый лэйаут
-- ---------------------------------------------------------------------------

T.check('WT-PANE-9 nvim и две консоли: справа 35% ширины две панели одна над другой по половине высоты, фокус в исходной', function()
  each_os(function(c)
    local pane = F.pane({ id = 1 })
    local win = F.window({ pane = pane })
    F.run_callback(ready_layout(c), win, pane)
    T.eq(pane.log, {
      { op = 'split', pane = 1, args = { direction = 'Right', size = 0.35 }, new = 2 },
      { op = 'split', pane = 2, args = { direction = 'Bottom', size = 0.5 }, new = 3 },
      { op = 'activate', pane = 1 },
    }, 'операции лэйаута')
  end)
end)

T.check('WT-PANE-9 делится только текущая панель: другие панели и окно не трогаются', function()
  each_os(function(c)
    local pane = F.pane({ id = 1 })
    local other = F.pane({ id = 50 })
    local win = F.window({ pane = pane })
    F.run_callback(ready_layout(c), win, pane)
    T.eq({ #other.splits, other.activated, #other.log }, { 0, 0, 0 }, 'соседняя панель')
    T.eq(win.performed, {}, 'действия окна')
    for _, e in ipairs(pane.log) do
      T.ok(e.pane == 1 or e.pane == pane.splits[1].pane.id, 'операция над чужой панелью: ' .. vim.inspect(e))
    end
  end)
end)

T.check('WT-PANE-9 повторный вызов делит левую панель снова: пять панелей, команда не идемпотентна', function()
  each_os(function(c)
    local pane = F.pane({ id = 1 })
    local win = F.window({ pane = pane })
    local cb = ready_layout(c)
    F.run_callback(cb, win, pane)
    F.run_callback(cb, win, pane)
    local created = {}
    for _, e in ipairs(pane.log) do
      if e.op == 'split' then created[#created + 1] = e.new end
    end
    T.eq(#created, 4, 'новых панелей после двух вызовов')
    T.eq(#pane.splits, 2, 'делений исходной панели')
    T.eq(pane.activated, 2, 'фокус возвращался в исходную')
  end)
end)

T.check('WT-PANE-9 нехватка места: первое деление не удалось — ничего не меняется; второе — фокус остаётся в новой панели', function()
  each_os(function(c)
    local cb = ready_layout(c)
    -- Первое деление падает (в WezTerm pane:split бросает ошибку, она уходит в лог).
    local p1 = F.pane({ id = 1 })
    p1.split = function() error('No space for split!') end
    local ok1 = pcall(F.run_callback, cb, F.window({ pane = p1 }), p1)
    T.ok(not ok1, 'колбэк не заметил ошибку первого деления')
    T.eq({ p1.activated, #p1.log }, { 0, 0 }, 'после неудачного первого деления')
    -- Второе деление падает: правая панель уже есть, фокус в исходную не возвращается.
    local p2 = F.pane({ id = 1 })
    local real_split = p2.split
    p2.split = function(self, args)
      local child = real_split(self, args)
      child.split = function() error('No space for split!') end
      return child
    end
    local ok2 = pcall(F.run_callback, cb, F.window({ pane = p2 }), p2)
    T.ok(not ok2, 'колбэк не заметил ошибку второго деления')
    T.eq(#p2.splits, 1, 'правая панель после неудачного второго деления')
    T.eq(p2.activated, 0, 'фокус вернулся в исходную панель')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-10 Воркспейсы, WT-PANE-11 Переименование вкладки
-- ---------------------------------------------------------------------------

local WS_PROMPT = 'Новый/существующий воркспейс:'
local TAB_PROMPT = 'Имя вкладки:'

T.check('WT-PANE-10 создание и переключение по имени: запрос переключает на воркспейс с введённым именем', function()
  each_os(function(c)
    local cb = prompt(c, 'phys:S', 'SHIFT', WS_PROMPT)
    local pane = F.pane()
    local win = F.window({ pane = pane, workspace = 'default' })
    F.run_callback(cb, win, pane, 'work')
    T.eq(win.performed, { { name = 'SwitchToWorkspace', args = { { name = 'work' } } } }, 'ввод work')
    T.ok(rawequal(win.calls[#win.calls][3], pane), 'SwitchToWorkspace не для текущей панели')
  end)
end)

T.check('WT-PANE-10 пустой ввод и отмена: воркспейс не меняется', function()
  each_os(function(c)
    local cb = prompt(c, 'phys:S', 'SHIFT', WS_PROMPT)
    for _, line in ipairs({ '', false }) do
      local win = F.window()
      -- false — отмена (WezTerm передаёт nil); '' — Enter на пустой строке.
      F.run_callback(cb, win, F.pane(), line or nil)
      T.eq(win.performed, {}, 'действия при вводе ' .. vim.inspect(line or nil))
    end
  end)
end)

T.check('WT-PANE-10 лаунчер: воркспейсы, пункт создания и вкладки окна с нечётким поиском, ничего сверх', function()
  each_os(function(c)
    local l = mode_command(c, 'phys:W')
    T.eq(l.name, 'ShowLauncherArgs', 'w в режиме WINDOWS')
    local flags = {}
    for f in l.args[1].flags:gmatch('[^|]+') do flags[#flags + 1] = vim.trim(f) end
    table.sort(flags)
    T.eq(flags, { 'FUZZY', 'TABS', 'WORKSPACES' }, 'флаги лаунчера')
  end)
end)

T.check('WT-PANE-11 новое имя: непустая строка становится заголовком текущей вкладки', function()
  each_os(function(c)
    local cb = prompt(c, 'phys:Comma', nil, TAB_PROMPT)
    local tab = F.tab({ title = 'pwsh' })
    local win = F.window({ tab = tab })
    F.run_callback(cb, win, F.pane(), 'server')
    T.eq(tab.titles, { 'server' }, 'set_title')
    T.eq(win.performed, {}, 'действия окна')
  end)
end)

T.check('WT-PANE-11 пустой ввод и отмена: заголовок не меняется', function()
  each_os(function(c)
    local cb = prompt(c, 'phys:Comma', nil, TAB_PROMPT)
    for _, line in ipairs({ '', false }) do
      local tab = F.tab({ title = 'pwsh' })
      F.run_callback(cb, F.window({ tab = tab }), F.pane(), line or nil)
      T.eq({ tab.title, #tab.titles }, { 'pwsh', 0 }, 'заголовок при вводе ' .. vim.inspect(line or nil))
    end
  end)
end)

T.check('WT-PANE-11 кириллица в имени: вкладка получает набранный текст как есть', function()
  each_os(function(c)
    local cb = prompt(c, 'phys:Comma', nil, TAB_PROMPT)
    local tab = F.tab()
    F.run_callback(cb, F.window({ tab = tab }), F.pane(), 'сервер')
    T.eq(tab.titles, { 'сервер' }, 'set_title')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-12 Каталог новой панели, вкладки и окна
-- ---------------------------------------------------------------------------

T.check('WT-PANE-12 сплит, вкладка, окно, воркспейс, лэйаут и вкладка истории — без явного каталога: его берёт WezTerm у текущей панели', function()
  each_os(function(c)
    -- Прямые сочетания и команды режима: ни у одного действия нет cwd.
    local spawning = {}
    for _, src in ipairs({ { 'config.keys', c.keys }, { 'windows', c.key_tables.windows } }) do
      for i, b in ipairs(src[2]) do
        for _, a in ipairs(flatten(b.action)) do
          local p = find_field(a, 'cwd')
          T.ok(not p, ('%s[%d] %s: явный каталог %s'):format(src[1], i, id_of(b.key, b.mods), tostring(p)))
          spawning[a.name] = true
        end
      end
    end
    for _, n in ipairs({ 'SplitPane', 'SpawnTab', 'SpawnWindow' }) do
      T.ok(spawning[n], 'среди привязок нет ' .. n)
    end
    -- Колбэки: лэйаут (split), воркспейс (SwitchToWorkspace), история (SpawnCommandInNewTab).
    local pane = F.pane({ id = 1, text = 'x\n' })
    F.run_callback(ready_layout(c), F.window({ pane = pane }), pane)
    for _, e in ipairs(pane.log) do
      T.ok(not find_field(e.args, 'cwd'), 'лэйаут: split с каталогом ' .. vim.inspect(e.args))
    end
    local win = F.window({ pane = pane })
    F.run_callback(prompt(c, 'phys:S', 'SHIFT', WS_PROMPT), win, pane, 'work')
    F.run_callback(mode_command(c, 'phys:B'), win, pane)
    T.eq(#win.performed, 2, 'действий воркспейса и истории')
    T.eq(win.performed[1], { name = 'SwitchToWorkspace', args = { { name = 'work' } } }, 'воркспейс без spawn')
    T.eq(win.performed[2].name, 'SpawnCommandInNewTab', 'вкладка истории')
    T.ok(not find_field(win.performed[2], 'cwd'), 'вкладка истории с каталогом: ' .. vim.inspect(win.performed[2]))
  end)
end)

T.check('WT-PANE-12 первое окно — в домашнем каталоге: default_cwd не задан, окно открывает сам WezTerm без каталога', function()
  each_os(function(_, os_name)
    local res = F.load_config({ triple = F.TRIPLES[os_name] })
    T.eq(res.config.default_cwd, nil, 'default_cwd')
    -- Обработчика gui-startup нет: первое окно открывает WezTerm, конфиг
    -- mux.spawn_window не вызывает и каталог не задаёт; «принять окно»
    -- (window-config-reloaded) только ставит размер и положение.
    T.eq(res.events['gui-startup'], nil, 'обработчик gui-startup')
    res.events['window-config-reloaded'](F.window(), F.pane())
    T.eq(#res.spawned, 0, 'окна, открытые конфигом')
  end)
end)

-- ---------------------------------------------------------------------------
-- WT-PANE-13 Мышь
-- ---------------------------------------------------------------------------

T.check('WT-PANE-13 мышь — привязки WezTerm по умолчанию: они не отключены и не переопределены', function()
  each_os(function(c)
    T.ok(c.disable_default_mouse_bindings ~= true, 'disable_default_mouse_bindings = true')
    T.eq(c.mouse_bindings, nil, 'mouse_bindings')
    T.ok(c.enable_tab_bar ~= false, 'enable_tab_bar = false: вкладки мышью недоступны')
  end)
end)

T.check('WT-PANE-13 фокус кликом: клик доходит до программы, фокус не следует за указателем', function()
  each_os(function(c)
    T.ok(c.swallow_mouse_click_on_pane_focus ~= true, 'swallow_mouse_click_on_pane_focus = true')
    T.ok(c.pane_focus_follows_mouse ~= true, 'pane_focus_follows_mouse = true')
  end)
end)

T.check('WT-PANE-13 вкладки мышью: кнопка «+» в панели вкладок не скрыта', function()
  each_os(function(c)
    T.ok(c.show_new_tab_button_in_tab_bar ~= false, 'show_new_tab_button_in_tab_bar = false')
  end)
end)

T.finish()
