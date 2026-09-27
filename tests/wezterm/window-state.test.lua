-- WT-STATE-1…8 (openspec/specs/wezterm-window-state) через поддельный wezterm
-- (add-wezterm-spec-checks, задача 3.8; размещение новых окон и сброс шрифта —
-- fix-window-state-new-windows, design D7). Одна проверка — один сценарий.
--
-- Здесь — то, что видно в конфиге:
--   * файл состояния: путь, чтение, битый JSON, отсутствие, запись по Ctrl+Shift+S;
--   * шрифт: config.font_size, крупнее / мельче / сброс через config overrides;
--   * «принять окно»: обработчик window-config-reloaded на поддельном окне
--     (overrides nil — новое окно) и поддельных wezterm.gui.screens(): размер,
--     центр, overrides {}.
-- Не здесь (исход решает WezTerm или оконная система — ручные проверки):
-- присылает ли WezTerm событие каждому новому окну (Ctrl+Shift+N, CLI,
-- повторный запуск, возврат в воркспейс), что он делает с overrides
-- (перечитывание конфига окна, сброс режимов WINDOWS/RESIZE), вид и срок
-- уведомления, реальные пиксели и масштаб экрана, число строк и столбцов.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')
local B = require('bootstrap')

local TR = F.TRIPLES
local ORDER = { 'windows', 'macos', 'linux' }
local HOME = { windows = 'C:\\Users\\tester', macos = '/Users/tester', linux = '/home/tester' }
local STATE_NAME = '.wezterm_forge_window.json'
-- Состояние «окно 1454×1335, шрифт 14» — пример из спеки.
local SAVED = '{"font_size":14.0,"h":1335,"w":1454}'

-- ---------------------------------------------------------------------------
-- Помощники
-- ---------------------------------------------------------------------------

local function near(actual, expected, what)
  T.ok(type(actual) == 'number' and math.abs(actual - expected) < 1e-9,
    ('%s: получено %s, ожидалось ≈ %s'):format(what or 'число', tostring(actual), tostring(expected)))
end

local function norm_path(p) return (p:gsub('\\', '/')) end

-- Путь файла состояния — тот, что конфиг открывает при загрузке (разделитель
-- у конфига свой, поэтому путь берётся у него, а сверяется отдельной проверкой
-- WT-STATE-4).
local state_paths = {}
local function state_path(os_name)
  if not state_paths[os_name] then
    local res = F.load_config({ triple = TR[os_name], home = HOME[os_name] })
    for _, o in ipairs(res.opened) do
      if o.path:sub(-#STATE_NAME) == STATE_NAME then
        state_paths[os_name] = o.path
        break
      end
    end
    T.ok(state_paths[os_name], os_name .. ': конфиг при загрузке не читает ' .. STATE_NAME)
  end
  return state_paths[os_name]
end

--- Загрузить конфиг: o.state — содержимое файла состояния (nil — файла нет),
--- o.files — файлы, оставшиеся от прошлой «сессии» (res.files), o.screens,
--- o.unwritable.
local function load(os_name, o)
  o = o or {}
  local files = {}
  for k, v in pairs(o.files or {}) do files[k] = v end
  if o.state ~= nil then files[state_path(os_name)] = o.state end
  return F.load_config({
    triple = TR[os_name], home = HOME[os_name], files = files,
    screens = o.screens, unwritable = o.unwritable,
  })
end

--- Окно этого конфига. effective_config() = config + overrides — так WezTerm
--- собирает конфиг окна (fake_wezterm, F.window).
local function window_of(res, o)
  o = o or {}
  return F.window({
    effective_config = { font_size = res.config.font_size },
    config_overrides = o.overrides,
    dimensions = o.dims,
    active_key_table = o.key_table,
  })
end

local function action_for(res, key, mods)
  local b = F.find_binding(res.config.keys, key, mods)
  T.ok(b, ('нет привязки %s %s в config.keys'):format(key, mods))
  return b.action
end

local function press(res, win, key, mods)
  F.run_callback(action_for(res, key, mods), win, F.pane())
  return win
end

local function font(win) return win:effective_config().font_size end

local function saved_state(res, os_name)
  local s = res.writes[state_path(os_name)]
  T.ok(s, 'файл состояния не записан')
  return vim.json.decode(s)
end

local function dims(w, h, dpi)
  return { pixel_width = w, pixel_height = h, dpi = dpi or 96, is_full_screen = false }
end

local function screens(active, main)
  return { active = active, main = main or active, by_name = {}, virtual_screen = active }
end
local S2560 = { name = 'S1', x = 0, y = 0, width = 2560, height = 1440, scale = 1.0 }

local GEO = { set_inner_size = true, set_position = true }

--- Событие window-config-reloaded для окна gui (WezTerm шлёт его каждому
--- новому окну и при каждом пересчёте конфига окна).
local function config_reloaded(res, gui)
  local ev = res.events['window-config-reloaded']
  T.ok(type(ev) == 'function', 'нет обработчика window-config-reloaded')
  ev(gui, F.pane())
  local geo, other = {}, {}
  for _, c in ipairs(gui.calls) do
    if GEO[c[1]] then geo[#geo + 1] = { c[1], c[2], c[3] } else other[#other + 1] = c[1] end
  end
  return geo, other
end

--- Открыть новое окно: overrides nil (так начинает каждое новое окно WezTerm)
--- и событие window-config-reloaded. o.res — конфиг уже загружен (та же
--- сессия). → { res, gui, geo = вызовы размера/положения, other = прочие
--- вызовы окна }.
local function new_window(os_name, o)
  o = o or {}
  local res = o.res or load(os_name, o)
  local gui = F.window({ effective_config = { font_size = res.config.font_size } })
  local geo, other = config_reloaded(res, gui)
  return { res = res, gui = gui, geo = geo, other = other }
end

local function warnings(res)
  return vim.tbl_filter(function(l) return l[1] ~= 'info' end, res.logs)
end

local function expect_quiet_window(s, what)
  T.eq(s.other, {}, what .. ': кроме размера и положения окно ничего не получает (не развёрнуто, не во весь экран)')
  T.eq(s.gui.performed, {}, what .. ': действия над окном')
  T.eq(s.gui.toasts, {}, what .. ': уведомления')
  T.eq(s.gui.override_calls, { {} }, what .. ': окно принято — overrides {}')
  T.eq(warnings(s.res), {}, what .. ': предупреждения в журнале')
end

-- ---------------------------------------------------------------------------
-- WT-STATE-1 Первое окно при запуске WezTerm
-- ---------------------------------------------------------------------------

T.check('WT-STATE-1 размер не сохранён: 0,62×0,72 экрана с округлением вниз, по центру, не развёрнуто', function()
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { screens = screens(S2560) })
    T.eq(s.geo, { { 'set_inner_size', 1587, 1036 }, { 'set_position', 486, 202 } }, os_name)
    expect_quiet_window(s, os_name)
  end
end)

T.check('WT-STATE-1 размер сохранён: окно сохранённого размера по центру активного экрана', function()
  -- Активный экран — второй монитор справа; основной — другой. Центр — по активному.
  local active = { name = 'S2', x = 2560, y = 0, width = 2560, height = 1440, scale = 1.0 }
  local main = { name = 'S1', x = 0, y = 0, width = 1920, height = 1080, scale = 1.0 }
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { state = SAVED, screens = screens(active, main) })
    T.eq(s.geo, { { 'set_inner_size', 1454, 1335 }, { 'set_position', 2560 + 553, 52 } }, os_name)
    expect_quiet_window(s, os_name)
  end
end)

T.check('WT-STATE-1 сохранено в развёрнутом окне: при запуске — обычное окно размером с прежнюю область, по центру', function()
  for _, os_name in ipairs(ORDER) do
    local before = load(os_name)
    press(before, window_of(before, { dims = dims(2560, 1377) }), 'phys:S', 'CTRL|SHIFT')
    local s = new_window(os_name, { files = before.files, screens = screens(S2560) })
    T.eq(s.geo, { { 'set_inner_size', 2560, 1377 }, { 'set_position', 0, 31 } }, os_name)
    expect_quiet_window(s, os_name)
  end
end)

T.check('WT-STATE-1 экран с другим масштабом: те же физические пиксели, масштаб не учитывается', function()
  for _, os_name in ipairs(ORDER) do
    -- Сохранение на экране 200 %: в файл идут физические пиксели окна, dpi не пересчитывается.
    local before = load(os_name)
    press(before, window_of(before, { dims = dims(1454, 1335, 192) }), 'phys:S', 'CTRL|SHIFT')
    local st = saved_state(before, os_name)
    T.eq({ st.w, st.h }, { 1454, 1335 }, os_name .. ': сохранённый размер')
    local hi = vim.tbl_extend('force', S2560, { scale = 2.0 })
    local lo = vim.tbl_extend('force', S2560, { scale = 1.0 })
    local s2 = new_window(os_name, { files = before.files, screens = screens(hi) })
    local s1 = new_window(os_name, { files = before.files, screens = screens(lo) })
    T.eq(s1.geo[1], { 'set_inner_size', 1454, 1335 }, os_name .. ': экран 100 %')
    T.eq(s2.geo, s1.geo, os_name .. ': экран 200 % и 100 %')
  end
end)

T.check('WT-STATE-1 сохранённый размер больше экрана: размер не уменьшается, положение — от сохранённого размера', function()
  local small = { name = 'S1', x = 0, y = 0, width = 1920, height = 1080, scale = 1.0 }
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { state = '{"font_size":12.0,"h":1600,"w":2560}', screens = screens(small) })
    T.eq(s.geo, { { 'set_inner_size', 2560, 1600 }, { 'set_position', -320, -260 } }, os_name)
    expect_quiet_window(s, os_name)
  end
end)

T.check('WT-STATE-1 сведения об экране недоступны: 1500×950 без центрирования, сохранённый размер не применяется', function()
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, {
      state = SAVED,
      -- Недоступный API экрана: wezterm.gui.screens() бросает ошибку.
      screens = function() error('screens: нет сведений об экране', 0) end,
    })
    T.eq(s.geo, { { 'set_inner_size', 1500, 950 } }, os_name)
    T.eq(s.other, {}, os_name .. ': прочие вызовы окна')
    T.eq(s.gui.override_calls, { {} }, os_name .. ': окно принято и при ошибке — overrides {}')
    T.eq(#warnings(s.res), 1, os_name .. ': предупреждение «нет сведений об экране» в журнале')
  end
end)

T.check('WT-STATE-1 положение из командной строки (--position) перекрыто центрированием', function()
  -- Окно с --position WezTerm открывает сам (обработчика gui-startup нет) и
  -- ставит в 10,10; «принять окно» затем ставит его в центр, как любое новое.
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { screens = screens(S2560) })
    T.eq(res.events['gui-startup'], nil, os_name .. ': обработчик gui-startup')
    local s = new_window(os_name, { res = res })
    T.eq(s.geo, { { 'set_inner_size', 1587, 1036 }, { 'set_position', 486, 202 } }, os_name .. ': центр, а не 10,10')
  end
end)

T.check('WT-STATE-1 запуск с программой вместо шелла: программу запускает сам WezTerm, размер и положение как обычно', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = screens(S2560) })
    -- Обработчика gui-startup нет: первое окно с программой из командной
    -- строки открывает WezTerm (spawn_tab_in_domain_if_mux_is_empty), конфиг
    -- mux.spawn_window не вызывает и команду не подменяет.
    T.eq(res.events['gui-startup'], nil, os_name .. ': обработчик gui-startup')
    local s = new_window(os_name, { res = res })
    T.eq(#res.spawned, 0, os_name .. ': mux.spawn_window из конфига')
    T.eq(s.geo, { { 'set_inner_size', 1454, 1335 }, { 'set_position', 553, 52 } }, os_name)
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-2 Остальные окна — стандартного размера
-- ---------------------------------------------------------------------------

T.check('WT-STATE-2 новое окно по Ctrl+Shift+N — как первое: сохранённый размер по центру активного экрана', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = screens(S2560) })
    T.eq(F.normalize_action(action_for(res, 'phys:N', 'CTRL|SHIFT')), { name = 'SpawnWindow' }, os_name .. ': Ctrl+Shift+N')
    if os_name ~= 'windows' then
      T.eq(F.normalize_action(action_for(res, 'phys:N', 'SUPER')), { name = 'SpawnWindow' }, os_name .. ': Cmd+N')
    end
    -- Новое окно приходит с overrides nil — и встаёт, как первое (сценарий
    -- WT-STATE-1 «размер сохранён»): один путь для всех окон.
    local first = new_window(os_name, { res = res })
    local second = new_window(os_name, { res = res })
    T.eq(second.geo, { { 'set_inner_size', 1454, 1335 }, { 'set_position', 553, 52 } }, os_name .. ': новое окно')
    T.eq(second.geo, first.geo, os_name .. ': новое окно как первое')
    expect_quiet_window(second, os_name)
    -- Размер в знакоместах конфиг не задаёт: до «принять окно» окно
    -- мгновение стоит стандартные 80×24 WezTerm.
    T.eq({ res.config.initial_cols, res.config.initial_rows }, { nil, nil }, os_name .. ': initial_cols/rows')
  end
end)

T.check('WT-STATE-2 размер ещё не сохранён: новое окно 1587×1036 по центру экрана 2560×1440', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { screens = screens(S2560) })
    new_window(os_name, { res = res })
    local s = new_window(os_name, { res = res })
    T.eq(s.geo, { { 'set_inner_size', 1587, 1036 }, { 'set_position', 486, 202 } }, os_name)
  end
end)

T.check('WT-STATE-2 сохранено в этой же сессии: новое окно — сохранённого размера без перечитывания конфига', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { screens = screens(S2560) })
    press(res, window_of(res, { dims = dims(1600, 1000), overrides = {} }), 'phys:S', 'CTRL|SHIFT')
    local s = new_window(os_name, { res = res })
    T.eq(s.geo[1], { 'set_inner_size', 1600, 1000 }, os_name)
  end
end)

T.check('WT-STATE-2 сведения об экране недоступны: новое окно 1500×950 без центрирования', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = function() error('нет экрана', 0) end })
    local s = new_window(os_name, { res = res })
    T.eq(s.geo, { { 'set_inner_size', 1500, 950 } }, os_name)
    T.eq(s.gui.override_calls, { {} }, os_name .. ': overrides {} и при ошибке')
  end
end)

T.check('WT-STATE-2 уже открытые окна не двигаются: окно с overrides {} или {font_size} событие не трогает', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = screens(S2560) })
    for _, ov in ipairs({ {}, { font_size = 16.94 } }) do
      local win = window_of(res, { overrides = ov })
      local geo, other = config_reloaded(res, win)
      T.eq({ geo, other, win.override_calls }, { {}, {}, {} }, os_name .. ' ' .. vim.inspect(ov))
    end
  end
end)

T.check('WT-STATE-2 размер и положение задаёт только «принять окно»: ни обработчики, ни привязки не трогают принятое окно', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = screens(S2560) })
    local touched, failed, probed = {}, {}, 0
    -- Каждый обработчик и колбэк выполняется на поддельном ПРИНЯТОМ окне
    -- (overrides {}); колбэкам запросов (PromptInputLine) — ещё и строка.
    local function probe(what, fn, ...)
      local win = window_of(res, { dims = dims(1454, 1335), key_table = 'windows', overrides = {} })
      local ok, err = pcall(fn, win, F.pane(), ...)
      probed = probed + 1
      if not ok then failed[#failed + 1] = what .. ': ' .. tostring(err) end
      for _, c in ipairs(win.calls) do
        if GEO[c[1]] then touched[#touched + 1] = what .. ': ' .. c[1] end
      end
    end
    -- format-tab-title окна не получает (WT-UI-15) — вне проверки.
    for name, fn in pairs(res.events) do
      if name ~= 'format-tab-title' then probe('событие ' .. name, fn) end
    end
    for _, cb in ipairs(res.callbacks) do probe('колбэк ' .. cb.event, cb.fn, 'строка') end
    table.sort(touched)
    T.eq(failed, {}, os_name .. ': обработчик или колбэк упал — проверка была бы пустой')
    T.ok(probed > #res.callbacks, os_name .. ': не выполнено ни одного обработчика событий')
    T.eq(touched, {}, os_name)
  end
end)

T.check('WT-STATE-2 один путь размещения: обработчика gui-startup нет, window-config-reloaded есть; в журнале — строка на окно', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = screens(S2560) })
    T.eq(res.events['gui-startup'], nil, os_name .. ': gui-startup')
    T.eq(type(res.events['window-config-reloaded']), 'function', os_name .. ': window-config-reloaded')
    new_window(os_name, { res = res })
    local infos = vim.tbl_filter(function(l) return l[1] == 'info' end, res.logs)
    T.eq(#infos, 1, os_name .. ': строк «принять окно» в журнале')
    T.ok(infos[1] and infos[1][2]:find('saved 1454×1335', 1, true), os_name .. ': журнал: ' .. vim.inspect(infos))
  end
end)

T.check('WT-STATE-2 overrides nil не ставит ни один путь: «принять окно» и колбэки шрифта (×1,1, ÷1,1, сброс)', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED, screens = screens(S2560) })
    local wins = { new_window(os_name, { res = res }).gui }
    for _, ov in ipairs({ vim.NIL, {}, { font_size = 16.94 } }) do
      for _, key in ipairs({ 'phys:Equal', 'phys:Minus', 'phys:0' }) do
        local win = window_of(res, { overrides = ov ~= vim.NIL and ov or nil })
        press(res, win, key, 'CTRL')
        wins[#wins + 1] = win
      end
    end
    for i, w in ipairs(wins) do
      for _, c in ipairs(w.override_calls) do
        T.ok(c ~= vim.NIL, ('%s: окно %d: set_config_overrides(nil)'):format(os_name, i))
      end
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-3 Запомнить размер окна и шрифта
-- ---------------------------------------------------------------------------

T.check('WT-STATE-3 сохранение по Ctrl+Shift+S: размер окна и шрифт в файл, уведомление, в программу не уходит', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local win = window_of(res, { dims = dims(1454, 1335), overrides = { font_size = 12 * 1.1 } })
    press(res, win, 'phys:S', 'CTRL|SHIFT')
    local st = saved_state(res, os_name)
    T.eq({ st.w, st.h }, { 1454, 1335 }, os_name .. ': размер в файле')
    near(st.font_size, 13.2, os_name .. ': шрифт в файле')
    T.eq(win.toasts, { {
      title = 'WezTerm',
      message = 'Сохранено: окно 1454×1335, шрифт 13.2 (так и откроется в след. раз)',
      timeout = 3000,
    } }, os_name .. ': уведомление')
    T.eq(win.performed, {}, os_name .. ': программе ничего не отправлено')
  end
end)

T.check('WT-STATE-3 в файл — точный размер шрифта, в уведомлении — округлённый до одного знака', function()
  local res = load('windows')
  local win = window_of(res, { dims = dims(1454, 1335), overrides = { font_size = 12 / 1.1 } })
  press(res, win, 'phys:S', 'CTRL|SHIFT')
  local st = saved_state(res, 'windows')
  near(st.font_size, 12 / 1.1, 'шрифт в файле')
  T.ok(math.abs(st.font_size - 10.9) > 1e-3, 'в файл записан округлённый шрифт: ' .. tostring(st.font_size))
  T.eq(win.toasts[1].message, 'Сохранено: окно 1454×1335, шрифт 10.9 (так и откроется в след. раз)')
end)

T.check('WT-STATE-3 файл перезаписывается целиком: действует последнее сохранение', function()
  local res = load('macos', { state = '{"extra":1,"font_size":20,"h":2,"w":1}' })
  press(res, window_of(res, { dims = dims(1000, 700) }), 'phys:S', 'CTRL|SHIFT')
  press(res, window_of(res, { dims = dims(1454, 1335) }), 'phys:S', 'CTRL|SHIFT')
  T.eq(saved_state(res, 'macos'), { font_size = 20, h = 1335, w = 1454 },
    'прежнее содержимое не хранится (шрифт 20 — из конфига, прочитанного при загрузке)')
end)

T.check('WT-STATE-3 русская раскладка: сочетание задано физической клавишей S', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local b = F.find_binding(res.config.keys, 'phys:S', 'CTRL|SHIFT')
    T.ok(b and b.key:match('^phys:'), os_name .. ': Ctrl+Shift+S не по физической позиции')
    T.eq(b.action.name, 'Callback', os_name)
  end
end)

-- Таблицы режимов WINDOWS и RESIZE несут копии сочетаний терминала с тем же
-- действием (WT-WIN-4): это не перекрытие. Перекрытие — другое действие.
local function not_overridden(res, os_name, name, list, key, mods)
  local b = F.find_binding(list, key, mods)
  if b == nil then return end
  local k = F.find_binding(res.config.keys, key, mods)
  T.ok(k and rawequal(b.action, k.action), ('%s: %s перехватывает %s %s'):format(os_name, name, key, mods))
end

T.check('WT-STATE-3 в copy mode, search mode и режимах WINDOWS/RESIZE сочетание не перекрыто таблицами режимов', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    for name, list in pairs(res.config.key_tables) do
      for _, mods in ipairs({ 'CTRL|SHIFT', 'SUPER|SHIFT' }) do
        not_overridden(res, os_name, name, list, 'phys:S', mods)
        not_overridden(res, os_name, name, list, 'mapped:s', mods)
      end
    end
  end
end)

T.check('WT-STATE-3 Cmd+Shift+S вне Windows — то же, что Ctrl+Shift+S', function()
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    local res = load(os_name)
    local ctrl = action_for(res, 'phys:S', 'CTRL|SHIFT')
    local cmd = action_for(res, 'phys:S', 'SUPER|SHIFT')
    T.ok(rawequal(ctrl, cmd), os_name .. ': Cmd+Shift+S — другой колбэк, чем Ctrl+Shift+S')
  end
end)

T.check('WT-STATE-3 Win+Shift+S на Windows не занят (системный снимок экрана)', function()
  local res = load('windows')
  T.eq(F.find_binding(res.config.keys, 'phys:S', 'SUPER|SHIFT'), nil)
end)

T.check('WT-STATE-3 файл не записывается: уведомление «Не удалось записать состояние окна», файл не изменился', function()
  for _, os_name in ipairs(ORDER) do
    local path = state_path(os_name)
    local res = load(os_name, { state = SAVED, unwritable = { [path] = true } })
    local win = window_of(res, { dims = dims(800, 600) })
    press(res, win, 'phys:S', 'CTRL|SHIFT')
    T.eq(res.files[path], SAVED, os_name .. ': файл состояния')
    T.eq(res.writes, {}, os_name .. ': записи')
    T.eq(win.toasts, { { title = 'WezTerm', message = 'Не удалось записать состояние окна', timeout = 3000 } }, os_name)
  end
end)

T.check('WT-STATE-3 без Ctrl+Shift+S ничего не запоминается: смена шрифта, запуск и статус файл не пишут', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { screens = screens(S2560) })
    local win = window_of(res, { dims = dims(1454, 1335) })
    for _, key in ipairs({ 'phys:Equal', 'phys:Minus', 'phys:0' }) do
      local mods_list = os_name == 'windows' and { 'CTRL', 'CTRL|SHIFT' } or { 'CTRL', 'CTRL|SHIFT', 'SUPER', 'SUPER|SHIFT' }
      for _, mods in ipairs(mods_list) do press(res, win, key, mods) end
    end
    new_window(os_name, { res = res })
    res.events['update-right-status'](win, F.pane())
    T.eq(res.writes, {}, os_name)
  end
end)

T.check('WT-STATE-3 режим WINDOWS не выключается: сохранение не выходит из режима и не перечитывает конфиг окна', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local win = window_of(res, { dims = dims(1454, 1335), key_table = 'windows' })
    press(res, win, 'phys:S', 'CTRL|SHIFT')
    T.ok(res.writes[state_path(os_name)], os_name .. ': состояние не сохранено')
    T.eq(win.performed, {}, os_name .. ': действия (PopKeyTable и т.п.)')
    T.eq(win.override_calls, {}, os_name .. ': set_config_overrides (перечитывание конфига окна)')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-4 Файл состояния
-- ---------------------------------------------------------------------------

T.check('WT-STATE-4 файл .wezterm_forge_window.json в домашнем каталоге пользователя, вне репозитория', function()
  for _, os_name in ipairs(ORDER) do
    local p = norm_path(state_path(os_name))
    T.eq(p, norm_path(HOME[os_name]) .. '/' .. STATE_NAME, os_name)
    T.ok(p:sub(1, #B.root + 1) ~= norm_path(B.root) .. '/', os_name .. ': файл в репозитории')
  end
end)

T.check('WT-STATE-4 файла нет: окно долей экрана, шрифт 12, без ошибок и уведомлений', function()
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { screens = screens(S2560) })
    T.eq(s.res.config.font_size, 12, os_name .. ': шрифт')
    T.eq(s.geo[1], { 'set_inner_size', 1587, 1036 }, os_name .. ': размер')
    expect_quiet_window(s, os_name)
  end
end)

T.check('WT-STATE-4 битый файл (не JSON) — как без файла, без ошибок и уведомлений', function()
  for _, os_name in ipairs(ORDER) do
    for _, bad in ipairs({ '{"font_size":14.0,"h":1335,"w":14', '', 'не json' }) do
      local s = new_window(os_name, { state = bad, screens = screens(S2560) })
      T.eq(s.res.config.font_size, 12, os_name .. ' ' .. vim.inspect(bad) .. ': шрифт')
      T.eq(s.geo[1], { 'set_inner_size', 1587, 1036 }, os_name .. ' ' .. vim.inspect(bad) .. ': размер')
      expect_quiet_window(s, os_name)
    end
  end
end)

T.check('WT-STATE-4 старый формат без шрифта: размер из файла, шрифт 12', function()
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { state = '{"h":1335,"w":1454}', screens = screens(S2560) })
    T.eq(s.res.config.font_size, 12, os_name .. ': шрифт')
    T.eq(s.geo[1], { 'set_inner_size', 1454, 1335 }, os_name .. ': размер')
  end
end)

T.check('WT-STATE-4 только шрифт без размеров: весь файл пропускается — окно долей экрана, шрифт 12', function()
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { state = '{"font_size":14}', screens = screens(S2560) })
    T.eq(s.res.config.font_size, 12, os_name .. ': шрифт')
    T.eq(s.geo[1], { 'set_inner_size', 1587, 1036 }, os_name .. ': размер')
  end
end)

T.check('WT-STATE-4 дробные ширина и высота округляются вниз, на разумность не проверяются', function()
  for _, os_name in ipairs(ORDER) do
    local s = new_window(os_name, { state = '{"h":1335.9,"w":1454.5}', screens = screens(S2560) })
    T.eq(s.geo[1], { 'set_inner_size', 1454, 1335 }, os_name .. ': дробные')
    local tiny = new_window(os_name, { state = '{"font_size":2,"h":10,"w":10}', screens = screens(S2560) })
    T.eq(tiny.geo[1], { 'set_inner_size', 10, 10 }, os_name .. ': 10×10')
    T.eq(tiny.res.config.font_size, 2, os_name .. ': шрифт 2')
  end
end)

T.check('WT-STATE-4 файл удалён при работающем WezTerm: после перечитывания шрифт 12, размер окон не меняется', function()
  for _, os_name in ipairs(ORDER) do
    local before = load(os_name, { state = SAVED })
    T.eq(before.config.font_size, 14, os_name .. ': до удаления')
    local after = load(os_name) -- перечитывание конфига: файла уже нет
    T.eq(after.config.font_size, 12, os_name .. ': после перечитывания')
    for _, c in ipairs(after.calls) do
      T.ok(c[1] ~= 'mux.spawn_window' and c[1] ~= 'gui.screens',
        os_name .. ': вычисление конфига трогает окна: ' .. tostring(c[1]))
    end
  end
end)

T.check('WT-STATE-4 файл удалён, новое окно: доля экрана и шрифт 12, открытые окна не трогаются', function()
  for _, os_name in ipairs(ORDER) do
    local before = load(os_name, { state = SAVED, screens = screens(S2560) })
    local open = window_of(before, { overrides = {} })
    -- Файл удалён: новое окно пересчитывает конфиг (overrides nil → {}), файла нет.
    local after = load(os_name, { screens = screens(S2560) })
    local s = new_window(os_name, { res = after })
    T.eq(s.geo[1], { 'set_inner_size', 1587, 1036 }, os_name .. ': размер нового окна')
    T.eq(after.config.font_size, 12, os_name .. ': шрифт нового окна')
    local geo = config_reloaded(after, open)
    T.eq({ geo, open.override_calls }, { {}, {} }, os_name .. ': открытое окно')
  end
end)

T.check('WT-STATE-4 репозиторий не затрагивается: сохранение пишет только файл в домашнем каталоге', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    T.eq(res.writes, {}, os_name .. ': записи при загрузке')
    press(res, window_of(res, { dims = dims(1454, 1335) }), 'phys:S', 'CTRL|SHIFT')
    local written = vim.tbl_keys(res.writes)
    T.eq(written, { state_path(os_name) }, os_name .. ': записанные файлы')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-5 Шрифт по умолчанию и сохранённый шрифт
-- ---------------------------------------------------------------------------

T.check('WT-STATE-5 запуск с сохранённым шрифтом 14: шрифт в конфиге 14', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name, { state = SAVED }).config.font_size, 14, os_name)
  end
end)

T.check('WT-STATE-5 шрифт не сохранён (нет font_size или нет файла) — 12', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.font_size, 12, os_name .. ': файла нет')
    T.eq(load(os_name, { state = '{"h":1335,"w":1454}' }).config.font_size, 12, os_name .. ': нет font_size')
  end
end)

T.check('WT-STATE-5 шрифт читается из файла при каждом вычислении конфига', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED })
    local read = false
    for _, o in ipairs(res.opened) do
      if o.path == state_path(os_name) and o.mode:sub(1, 1) == 'r' then read = true end
    end
    T.ok(read, os_name .. ': файл состояния не читается при вычислении конфига')
    T.eq(load(os_name, { state = '{"font_size":16,"h":1,"w":1}' }).config.font_size, 16, os_name .. ': второе вычисление')
  end
end)

T.check('WT-STATE-5 сохранение в этой же сессии и новое окно: новое окно — с сохранённым шрифтом, окно B — со старым', function()
  for _, os_name in ipairs(ORDER) do
    local session = load(os_name, { screens = screens(S2560) })
    T.eq(session.config.font_size, 12, os_name .. ': запуск')
    local a = window_of(session, { dims = dims(1454, 1335), overrides = {} })
    local b = window_of(session, { overrides = {} })
    press(session, a, 'phys:Equal', 'CTRL')
    press(session, a, 'phys:Equal', 'CTRL')
    press(session, a, 'phys:S', 'CTRL|SHIFT')
    -- Новое окно: «принять окно» ставит overrides {} вместо nil — WezTerm
    -- заново вычисляет конфиг окна, и файл читается на момент открытия.
    local s = new_window(os_name, { res = session })
    T.eq(s.gui.override_calls, { {} }, os_name .. ': конфиг нового окна пересчитан')
    local recomputed = load(os_name, { files = session.files })
    near(recomputed.config.font_size, 14.52, os_name .. ': шрифт нового окна')
    -- Окно B конфиг не пересчитывало: шрифт прежний, пока нет перечитывания.
    T.eq(b.override_calls, {}, os_name .. ': окно B')
    T.eq(font(b), 12, os_name .. ': шрифт окна B')
  end
end)

T.check('WT-STATE-5 перечитывание не трогает шрифт, изменённый клавишами: он живёт в overrides окна', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name) -- шрифт 12
    local a = window_of(res)
    press(res, a, 'phys:Minus', 'CTRL')
    near(a.overrides and a.overrides.font_size, 12 / 1.1, os_name .. ': overrides окна A')
    -- Перечитывание: в файле уже шрифт 14. WezTerm сохраняет overrides окна.
    local reloaded = load(os_name, { state = SAVED })
    local a2 = window_of(reloaded, { overrides = a:get_config_overrides() })
    local b2 = window_of(reloaded)
    near(font(a2), 12 / 1.1, os_name .. ': окно A после перечитывания')
    T.eq(font(b2), 14, os_name .. ': окно B после перечитывания')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-6 Шрифт крупнее и мельче
-- ---------------------------------------------------------------------------

T.check('WT-STATE-6 крупнее: Ctrl+= дважды — 13,2, затем 14,52; предела нет; в программу не уходит', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local win = window_of(res)
    press(res, win, 'phys:Equal', 'CTRL')
    near(font(win), 13.2, os_name .. ': первое нажатие')
    press(res, win, 'phys:Equal', 'CTRL')
    near(font(win), 14.52, os_name .. ': второе нажатие')
    T.eq(win.performed, {}, os_name .. ': программе ничего не отправлено')
    local big = window_of(res, { overrides = { font_size = 100 } })
    press(res, big, 'phys:Equal', 'CTRL')
    near(font(big), 110, os_name .. ': 100 → 110')
  end
end)

T.check('WT-STATE-6 мельче: Ctrl+- — примерно 10,9', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local win = press(res, window_of(res), 'phys:Minus', 'CTRL')
    near(font(win), 12 / 1.1, os_name)
    T.eq(('%.1f'):format(font(win)), '10.9', os_name)
  end
end)

T.check('WT-STATE-6 русская раскладка и Shift: Ctrl+Shift+= и Ctrl+Shift+- — так же, клавиши физические', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    for _, key in ipairs({ 'phys:Equal', 'phys:Minus' }) do
      for _, mods in ipairs({ 'CTRL', 'CTRL|SHIFT' }) do
        local b = F.find_binding(res.config.keys, key, mods)
        T.ok(b and b.key:match('^phys:'), ('%s: %s %s не по физической позиции'):format(os_name, key, mods))
      end
    end
    local up = press(res, window_of(res), 'phys:Equal', 'CTRL|SHIFT')
    local down = press(res, window_of(res), 'phys:Minus', 'CTRL|SHIFT')
    near(font(up), 13.2, os_name .. ': Ctrl+Shift+=')
    near(font(down), 12 / 1.1, os_name .. ': Ctrl+Shift+-')
  end
end)

T.check('WT-STATE-6 Super (Cmd на macOS, Super на Linux) — так же, как Ctrl', function()
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    local res = load(os_name)
    for _, mods in ipairs({ 'SUPER', 'SUPER|SHIFT' }) do
      near(font(press(res, window_of(res), 'phys:Equal', mods)), 13.2, os_name .. ': ' .. mods .. '+=')
      near(font(press(res, window_of(res), 'phys:Minus', mods)), 12 / 1.1, os_name .. ': ' .. mods .. '+-')
    end
  end
end)

T.check('WT-STATE-6 Super-варианты только вне Windows (и сброс WT-STATE-7): на Windows Win+=, Win+-, Win+0 не привязаны', function()
  local res = load('windows')
  for _, key in ipairs({ 'phys:Equal', 'phys:Minus', 'phys:0' }) do
    for _, mods in ipairs({ 'SUPER', 'SUPER|SHIFT' }) do
      T.eq(F.find_binding(res.config.keys, key, mods), nil, ('windows: %s %s'):format(key, mods))
    end
  end
end)

T.check('WT-STATE-6 только активное окно: другие окна и конфиг для новых окон не меняются', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local a, b = window_of(res), window_of(res)
    press(res, a, 'phys:Equal', 'CTRL')
    near(font(a), 13.2, os_name .. ': окно A')
    T.eq({ font(b), b.override_calls }, { 12, {} }, os_name .. ': окно B')
    T.eq(res.config.font_size, 12, os_name .. ': шрифт конфига (новые окна)')
  end
end)

T.check('WT-STATE-6 цифровой блок не занят: Ctrl и «+»/«-» цифрового блока уходят в программу', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    T.eq(res.config.disable_default_key_bindings, true, os_name .. ': встроенные привязки WezTerm (Ctrl+«+») включены')
    for _, b in ipairs(res.config.keys) do
      local k = F.norm_key(b.key)
      T.ok(not (k:find('Keypad', 1, true) or k:find('Numpad', 1, true) or k == 'Add' or k == 'Subtract'
        or k == 'mapped:+' or k == 'mapped:-'), ('%s: занята клавиша цифрового блока или символ: %s %s'):format(os_name, b.key, tostring(b.mods)))
    end
  end
end)

T.check('WT-STATE-6 смена шрифта в режиме WINDOWS: в таблицах режимов то же действие, сочетание перечитывает конфиг окна', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    for _, tbl in ipairs({ 'windows', 'resize_pane' }) do
      for _, key in ipairs({ 'phys:Equal', 'phys:Minus', 'phys:0' }) do
        not_overridden(res, os_name, tbl, res.config.key_tables[tbl], key, 'CTRL')
      end
    end
    -- Смена шрифта — set_config_overrides: WezTerm перечитывает конфиг окна и
    -- при этом снимает таблицы клавиш (выход из WINDOWS — поведение WezTerm).
    local win = press(res, window_of(res, { key_table = 'windows' }), 'phys:Equal', 'CTRL')
    T.eq(#win.override_calls, 1, os_name .. ': set_config_overrides')
    near(font(win), 13.2, os_name .. ': шрифт')
  end
end)

T.check('WT-STATE-6 смена шрифта в copy mode: сочетание не занято copy/search mode, copy mode не закрывается', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    for _, tbl in ipairs({ 'copy_mode', 'search_mode' }) do
      for _, key in ipairs({ 'phys:Equal', 'phys:Minus', 'phys:0' }) do
        not_overridden(res, os_name, tbl, res.config.key_tables[tbl], key, 'CTRL')
      end
    end
    local win = press(res, window_of(res, { key_table = 'copy_mode' }), 'phys:Equal', 'CTRL')
    near(font(win), 13.2, os_name .. ': шрифт')
    T.eq(win.performed, {}, os_name .. ': действия над панелью (CopyMode Close и т.п.)')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-7 Сброс шрифта
-- ---------------------------------------------------------------------------

T.check('WT-STATE-7 сброс к сохранённому: Ctrl+0 — шрифт из файла, только в активном окне', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED })
    local a = window_of(res, { overrides = { font_size = 16.94 } })
    local b = window_of(res, { overrides = { font_size = 20 } })
    press(res, a, 'phys:0', 'CTRL')
    T.eq(a.overrides and a.overrides.font_size, nil, os_name .. ': overrides.font_size снят')
    T.eq(font(a), 14, os_name .. ': окно A')
    T.eq(font(b), 20, os_name .. ': окно B не тронуто')
  end
end)

T.check('WT-STATE-7 сброс без сохранённого — 12', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = '{"h":1335,"w":1454}' })
    local win = press(res, window_of(res, { overrides = { font_size = 13.2 } }), 'phys:0', 'CTRL')
    T.eq(font(win), 12, os_name)
  end
end)

T.check('WT-STATE-7 сохранено в этой же сессии: сброс даёт шрифт из файла на момент нажатия, а не 12', function()
  for _, os_name in ipairs(ORDER) do
    local session = load(os_name) -- запуск со шрифтом 12
    local a = window_of(session, { dims = dims(1454, 1335), overrides = { font_size = 12 * 1.1 * 1.1 } })
    press(session, a, 'phys:S', 'CTRL|SHIFT')
    press(session, a, 'phys:Minus', 'CTRL')
    near(font(a), 13.2, os_name .. ': перед сбросом')
    press(session, a, 'phys:0', 'CTRL')
    -- Сброс — set_config_overrides без font_size: WezTerm заново вычисляет
    -- конфиг окна, и файл читается снова.
    local recomputed = load(os_name, { files = session.files })
    local a2 = window_of(recomputed, { overrides = a:get_config_overrides() })
    near(font(a2), 14.52, os_name .. ': после сброса')
  end
end)

T.check('WT-STATE-7 окно без изменений после сохранения в другом окне: сброс перечитывает конфиг окна', function()
  for _, os_name in ipairs(ORDER) do
    local session = load(os_name)
    local a = window_of(session, { dims = dims(1454, 1335) })
    press(session, a, 'phys:Equal', 'CTRL')
    press(session, a, 'phys:S', 'CTRL|SHIFT')
    local b = window_of(session) -- шрифт не трогали: overrides у окна нет
    T.eq(b:get_config_overrides(), nil, os_name .. ': overrides окна B до сброса')
    press(session, b, 'phys:0', 'CTRL')
    -- Два шага: шрифт из файла, затем без него — WezTerm заново вычисляет
    -- конфиг окна, итог — {}.
    T.eq(#b.override_calls, 2, os_name .. ': set_config_overrides окна B')
    near(b.override_calls[1].font_size, 13.2, os_name .. ': шаг 1 — шрифт из файла')
    T.eq(b.override_calls[2], {}, os_name .. ': шаг 2 — без font_size')
    local recomputed = load(os_name, { files = session.files })
    near(font(window_of(recomputed, { overrides = b:get_config_overrides() })), 13.2, os_name .. ': окно B после сброса')
  end
end)

T.check('WT-STATE-7 Win+0 на Windows шрифт не сбрасывает: Win+0 и Win+Shift+0 не привязаны, шрифт окна не меняется', function()
  local res = load('windows', { state = SAVED })
  for _, mods in ipairs({ 'SUPER', 'SUPER|SHIFT' }) do
    T.eq(F.find_binding(res.config.keys, 'phys:0', mods), nil, 'windows: ' .. mods .. '+0')
  end
end)

T.check('WT-STATE-7 повторный сброс не видит новое сохранение — теперь видит: каждый сброс — два шага, шрифт из файла на момент нажатия', function()
  for _, os_name in ipairs(ORDER) do
    local session = load(os_name)
    local b = window_of(session, { overrides = {} })
    press(session, b, 'phys:0', 'CTRL')
    -- Окно A сохраняет 14,52.
    local a = window_of(session, { dims = dims(1454, 1335), overrides = { font_size = 14.52 } })
    press(session, a, 'phys:S', 'CTRL|SHIFT')
    local n = #b.override_calls
    press(session, b, 'phys:0', 'CTRL')
    local calls = { unpack(b.override_calls, n + 1) }
    T.eq(#calls, 2, os_name .. ': повторный сброс — два вызова overrides')
    near(calls[1].font_size, 14.52, os_name .. ': шаг 1 — шрифт из файла на момент нажатия')
    T.eq(calls[2], {}, os_name .. ': шаг 2 — без font_size (значение другое, WezTerm пересчитывает конфиг)')
  end
end)

T.check('WT-STATE-7 сброс из {}, из nil и из {font_size}: последние два вызова — шрифт из файла, затем без него; прочие поля сохраняются', function()
  for _, os_name in ipairs(ORDER) do
    for _, st in ipairs({ { SAVED, 14 }, { '{"h":1335,"w":1454}', 12 } }) do
      local res = load(os_name, { state = st[1] })
      for _, ov in ipairs({ vim.NIL, {}, { font_size = 16.94 }, { font_size = 16.94, color_scheme = 'X' } }) do
        local win = window_of(res, { overrides = ov ~= vim.NIL and vim.deepcopy(ov) or nil })
        press(res, win, 'phys:0', 'CTRL')
        local keep = (ov ~= vim.NIL and ov.color_scheme) and { color_scheme = 'X' } or {}
        local what = ('%s файл %s, overrides %s'):format(os_name, st[1], vim.inspect(ov))
        T.eq(win.override_calls, { vim.tbl_extend('force', keep, { font_size = st[2] }), keep }, what)
      end
    end
  end
end)

T.check('WT-STATE-7 сброшенное окно следует за файлом: после сброса overrides без font_size', function()
  for _, os_name in ipairs(ORDER) do
    local session = load(os_name)
    local b = window_of(session, { overrides = {} })
    press(session, b, 'phys:Equal', 'CTRL')
    press(session, b, 'phys:0', 'CTRL')
    T.eq(b:get_config_overrides(), {}, os_name .. ': overrides окна B после сброса')
    -- Перечитывание с сохранённым 14: окно без font_size в overrides берёт шрифт из файла.
    local reloaded = load(os_name, { state = SAVED })
    T.eq(font(window_of(reloaded, { overrides = b:get_config_overrides() })), 14, os_name .. ': шрифт окна B')
  end
end)

T.check('WT-STATE-7 Ctrl+Shift+0 и Super (вне Windows) — так же; клавиша физическая (русская раскладка)', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name, { state = SAVED })
    local mods_list = os_name == 'windows' and { 'CTRL', 'CTRL|SHIFT' } or { 'CTRL', 'CTRL|SHIFT', 'SUPER', 'SUPER|SHIFT' }
    for _, mods in ipairs(mods_list) do
      local b = F.find_binding(res.config.keys, 'phys:0', mods)
      T.ok(b and b.key:match('^phys:'), ('%s: %s+0 не по физической позиции'):format(os_name, mods))
      local win = press(res, window_of(res, { overrides = { font_size = 16.94 } }), 'phys:0', mods)
      T.eq(font(win), 14, os_name .. ': ' .. mods .. '+0')
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-STATE-8 Размер окна не зависит от шрифта
-- ---------------------------------------------------------------------------

T.check('WT-STATE-8 крупный шрифт в том же окне: пиксельный размер окна прежний', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    T.eq(res.config.adjust_window_size_when_changing_font_size, false, os_name .. ': adjust_window_size_when_changing_font_size')
    local win = window_of(res, { dims = dims(1454, 1335) })
    for _ = 1, 3 do press(res, win, 'phys:Equal', 'CTRL') end
    press(res, win, 'phys:0', 'CTRL')
    for _, c in ipairs(win.calls) do
      T.ok(not GEO[c[1]], os_name .. ': смена шрифта меняет размер окна: ' .. c[1])
    end
  end
end)

T.check('WT-STATE-8 сохранение после смены шрифта: прежний размер окна и новый шрифт', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local win = window_of(res, { dims = dims(1454, 1335) })
    for _ = 1, 3 do press(res, win, 'phys:Equal', 'CTRL') end
    press(res, win, 'phys:S', 'CTRL|SHIFT')
    local st = saved_state(res, os_name)
    T.eq({ st.w, st.h }, { 1454, 1335 }, os_name .. ': размер')
    near(st.font_size, 12 * 1.1 * 1.1 * 1.1, os_name .. ': шрифт')
  end
end)

T.finish()
