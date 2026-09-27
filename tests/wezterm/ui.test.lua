-- WT-UI-1…15 (openspec/specs/wezterm-ui) в части конфига, через поддельный
-- wezterm (add-wezterm-spec-checks, задача 3.9). Характеризация базовой линии —
-- код как есть (design, решение 4); одна проверка — один сценарий требования.
--
-- Здесь — то, что видно в конфиге: выбор default_prog по поддельным PATH и
-- файлам; схема, шрифты, поля, звонок, курсор, панель вкладок, притушение;
-- правая часть панели вкладок из update-right-status (бейдж режима по
-- active_key_table, имя воркспейса) и частота её обновления.
-- Не здесь (исход решает WezTerm, шелл, ОС или отрисовка — ручные проверки
-- review-baseline): цвета схемы на экране, какой шрифт реально нашёлся и окно
-- «wezterm Configuration Error», login-шелл вне Windows, смена диска в
-- PowerShell, мигание курсора и форма от программы, вид и раскладка панели
-- вкладок (ширина вкладок, кнопка «+», обрезка слева), чей active_key_table
-- при copy mode в другой панели.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')

local TR = F.TRIPLES
local ORDER = { 'windows', 'macos', 'linux' }

-- Поддельные PATH и файлы Windows (WT-UI-1). pwsh.exe «лежит файлом» — есть в
-- таблице файлов; псевдоним Microsoft Store как файл не открывается (так на
-- машине владельца, спека WT-UI-1) — в таблице файлов его нет, он только
-- виден в каталоге (listed: wezterm.glob видит, io.open — нет).
local SYS_PATH = 'C:\\WINDOWS\\system32;C:\\WINDOWS;C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0'
local PWSH_DIR = 'C:\\Program Files\\PowerShell\\7'
local PWSH_FILE = PWSH_DIR .. '\\pwsh.exe'
local STORE_DIR = 'C:\\Users\\tester\\AppData\\Local\\Microsoft\\WindowsApps'
local PATH_WITH_PWSH = SYS_PATH .. ';' .. PWSH_DIR
local PWSH_INSTALLED = { [PWSH_FILE] = '' }

local STORE_PWSH = STORE_DIR .. '\\pwsh.exe'
local PWSH = { PWSH_FILE, '-NoLogo' }
local POWERSHELL = { 'powershell.exe', '-NoLogo' }

-- Бейджи режимов — таблица WT-UI-12; ключ — имя таблицы клавиш режима
-- (WT-WIN-1, WT-WIN-11, WT-SCROLL-5, WT-SCROLL-9).
local BADGES = {
  { key_table = 'windows', label = 'WINDOWS', color = '#f9e2af' },
  { key_table = 'resize_pane', label = 'RESIZE', color = '#fab387' },
  { key_table = 'copy_mode', label = 'COPY', color = '#89b4fa' },
  { key_table = 'search_mode', label = 'SEARCH', color = '#a6e3a1' },
}
local BADGE_TEXT_COLOR = '#1e1e2e'
local WORKSPACE_COLOR = '#6c7086'

-- ---------------------------------------------------------------------------
-- Помощники
-- ---------------------------------------------------------------------------

local cache = {}
local function load(os_name)
  cache[os_name] = cache[os_name] or F.load_config({ triple = TR[os_name] })
  return cache[os_name]
end

local function prog(env_path, files, listed)
  local res = F.load_config({ triple = TR.windows, env = { PATH = env_path }, files = files, listed = listed })
  return res.config.default_prog, res
end

local function action_of(list, key, mods, what)
  local b = F.find_binding(list, key, mods)
  T.ok(b, ('%s: нет привязки %s %s'):format(what or '?', key, tostring(mods)))
  return F.normalize_action(b.action)
end

--- Отрезки правой части статуса: текст и атрибуты, действующие на него.
--- Имитирует разбор wezterm.format 20240203: Background/Foreground/Attribute
--- копятся, 'ResetAttributes' сбрасывает всё, включая цвета (CellAttributes::default()).
local function segments(elems)
  local st, out = {}, {}
  for _, e in ipairs(elems or {}) do
    if e == 'ResetAttributes' then
      st = {}
    elseif type(e) == 'table' then
      if e.Background then st.bg = e.Background.Color
      elseif e.Foreground then st.fg = e.Foreground.Color
      elseif e.Attribute then
        if e.Attribute.Intense ~= nil then st.intense = e.Attribute.Intense end
      elseif e.Text then
        out[#out + 1] = { text = e.Text, bg = st.bg, fg = st.fg, intense = st.intense or false }
      end
    end
  end
  return out
end

local function visible(segs)
  local out = {}
  for _, s in ipairs(segs) do
    if vim.trim(s.text) ~= '' then out[#out + 1] = s end
  end
  return out
end

--- Выполнить update-right-status для окна o{ key_table, workspace, focused }.
local function status(os_name, o)
  o = o or {}
  local res = load(os_name)
  local win = F.window({ active_key_table = o.key_table, workspace = o.workspace })
  if o.focused ~= nil then
    function win:is_focused() return o.focused end
  end
  res.events['update-right-status'](win, F.pane())
  return win, visible(segments(win.right_status))
end

local function full_text(win)
  local parts = {}
  for _, s in ipairs(segments(win.right_status)) do parts[#parts + 1] = s.text end
  return table.concat(parts)
end

local function expect_badge(seg, b, what)
  T.eq(vim.trim(seg.text), '▶ ' .. b.label .. '  ·  Esc выход', what .. ': надпись бейджа')
  T.eq({ bg = seg.bg, fg = seg.fg, intense = seg.intense },
    { bg = b.color, fg = BADGE_TEXT_COLOR, intense = true }, what .. ': вид бейджа')
end

local function expect_workspace(seg, name, what)
  T.eq(vim.trim(seg.text), name, what .. ': имя воркспейса')
  T.eq({ fg = seg.fg, bg = seg.bg, intense = seg.intense }, { fg = WORKSPACE_COLOR, intense = false },
    what .. ': вид имени воркспейса')
end

local function cells(s) return vim.fn.strdisplaywidth(s) end

-- Данные format-tab-title без лишних полей: обращение к полю, которого
-- нет, — ошибка (обработчик читает только то, что WezTerm отдаёт).
local function strict(t, what)
  return setmetatable(t, { __index = function(_, k) error(('%s: поля %s нет'):format(what, tostring(k)), 2) end })
end

--- Заголовки вкладок из format-tab-title. o: cols — ширина вкладки в
--- знакоместах (панели активной вкладки), n — число вкладок, title —
--- заголовок активной панели, tab_title — имя вкладки, workspace.
--- Обработчик не должен трогать окно и асинхронные API: подделка считает
--- вызовы (res.calls) и падает на неизвестных полях аргументов.
local function tab_titles(os_name, o)
  local res = o.workspace and F.load_config({ triple = TR[os_name], workspace = o.workspace }) or load(os_name)
  local ev = res.events['format-tab-title']
  T.ok(type(ev) == 'function', os_name .. ': нет обработчика format-tab-title')
  local tabs = {}
  for i = 1, o.n do
    tabs[i] = strict({
      tab_index = i - 1, is_active = i == 1, tab_title = o.tab_title or '',
      active_pane = strict({ title = o.title }, 'active_pane'),
    }, 'tab')
  end
  local panes = o.cols and { strict({ left = 0, top = 0, width = o.cols, height = 30 }, 'pane') } or {}
  local before = #res.calls
  local out = {}
  for i = 1, o.n do out[i] = ev(tabs[i], tabs, panes, res.config, false, res.config.tab_max_width) end
  T.eq(#res.calls, before, os_name .. ': format-tab-title вызывает API WezTerm сверх чистых функций')
  return out, res
end

-- ---------------------------------------------------------------------------
-- WT-UI-1 Шелл по умолчанию на Windows
-- ---------------------------------------------------------------------------

T.check('WT-UI-1 PowerShell 7 установлен файлом в каталоге PATH: найденный полный путь, -NoLogo', function()
  T.eq(prog(PATH_WITH_PWSH, PWSH_INSTALLED), PWSH)
end)

T.check('WT-UI-1 PowerShell 7 из Microsoft Store: псевдоним виден в каталоге, хотя как файл не открывается — запускается он', function()
  local p, res = prog(SYS_PATH .. ';' .. STORE_DIR, {}, { STORE_PWSH })
  T.eq(p, { STORE_PWSH, '-NoLogo' })
  -- Наличие — без открытия: io.open на псевдониме упал бы (так было раньше).
  for _, o in ipairs(res.opened) do
    T.ok(not o.path:lower():find('pwsh.exe', 1, true), 'конфиг открывает pwsh.exe как файл: ' .. o.path)
  end
end)

T.check('WT-UI-1 оба варианта установлены: берётся найденный первым по порядку PATH', function()
  local both = { [PWSH_FILE] = '' }
  T.eq(prog(SYS_PATH .. ';' .. PWSH_DIR .. ';' .. STORE_DIR, both, { STORE_PWSH }), PWSH, 'MSI раньше Store')
  T.eq(prog(SYS_PATH .. ';' .. STORE_DIR .. ';' .. PWSH_DIR, both, { STORE_PWSH }), { STORE_PWSH, '-NoLogo' },
    'Store раньше MSI')
  T.eq(prog('C:\\A;' .. STORE_DIR .. ';C:\\Sys', { ['C:\\A\\pwsh.exe'] = '' }, { STORE_PWSH }),
    { 'C:\\A\\pwsh.exe', '-NoLogo' }, 'C:\\A раньше Store')
end)

T.check('WT-UI-1 PowerShell 7 нет: powershell.exe -NoLogo, конфиг грузится', function()
  T.eq(prog(SYS_PATH, {}), POWERSHELL, 'pwsh.exe нет в PATH')
  T.eq(prog(nil, {}), POWERSHELL, 'PATH пуст')
end)

T.check('WT-UI-1 смена диска командой cd: шелл по умолчанию — PowerShell, не cmd.exe', function()
  for _, case in ipairs({ { PATH_WITH_PWSH, PWSH_INSTALLED }, { SYS_PATH, {} }, { nil, {} } }) do
    local p = prog(case[1], case[2])
    T.ok(type(p) == 'table' and (p[1]:lower():match('pwsh%.exe$') or p[1] == 'powershell.exe'),
      'default_prog не PowerShell: ' .. vim.inspect(p))
  end
end)

T.check('WT-UI-1 pwsh установлен при работающем WezTerm: решает PATH процесса, перечитывание его не обновляет', function()
  -- Файл уже на диске, но каталога нет в PATH, с которым запущен WezTerm.
  T.eq(prog(SYS_PATH, PWSH_INSTALLED), POWERSHELL, 'запуск со старым PATH')
  T.eq(prog(SYS_PATH, PWSH_INSTALLED), POWERSHELL, 'перечитывание конфига с тем же PATH')
  T.eq(prog(PATH_WITH_PWSH, PWSH_INSTALLED), PWSH, 'перезапуск с обновлённым PATH')
end)

-- ---------------------------------------------------------------------------
-- WT-UI-2 Шелл по умолчанию на macOS и Linux
-- ---------------------------------------------------------------------------

T.check('WT-UI-2 вне Windows конфиг шелл не задаёт: default_prog нет, SHELL и PATH не читаются', function()
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    local res = F.load_config({
      triple = TR[os_name],
      env = { PATH = '/usr/local/bin:/usr/bin:/bin', SHELL = '/bin/zsh' },
      files = { ['/usr/local/bin/pwsh'] = '', ['/usr/local/bin/pwsh.exe'] = '' },
    })
    T.eq(res.config.default_prog, nil, os_name .. ': default_prog')
    T.ok(not vim.tbl_contains(res.getenv, 'SHELL'), os_name .. ': конфиг читает SHELL')
    T.ok(not vim.tbl_contains(res.getenv, 'PATH'), os_name .. ': конфиг ищет шелл по PATH')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-UI-3 … WT-UI-11: настройки вида
-- ---------------------------------------------------------------------------

T.check('WT-UI-3 тёмная схема Catppuccin Mocha на всех ОС, цвета схемы не переопределены', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.eq(c.color_scheme, 'Catppuccin Mocha', os_name)
    T.eq(c.colors, nil, os_name .. ': config.colors')
  end
end)

T.check('WT-UI-3 светлая тема ОС и её смена: схема та же — конфиг от темы не зависит', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    -- У подделки нет wezterm.gui.get_appearance: вызови конфиг его при загрузке —
    -- загрузка упала бы. Значит, тема ОС при вычислении конфига не читается.
    T.eq(res.wezterm.gui.get_appearance, nil, 'подделка не должна отдавать get_appearance')
    -- Ни один обработчик событий не меняет конфиг принятого окна (overrides)
    -- на лету. Новое окно (overrides nil) «принять окно» переводит в {} — это
    -- пересчёт конфига окна при открытии (WT-STATE-2), а не реакция на тему.
    -- format-tab-title окна не получает (WT-UI-15) — его здесь нет.
    for name, fn in pairs(res.events) do
      if name ~= 'format-tab-title' then
        local win = F.window({ active_key_table = 'windows', config_overrides = {} })
        fn(win, F.pane())
        T.eq(win.override_calls, {}, ('%s: обработчик %s меняет конфиг окна'):format(os_name, name))
      end
    end
  end
end)

T.check('WT-UI-4 нет запасного шрифта из списка: в списке только CaskaydiaCove (два имени), одинаково на всех ОС', function()
  for _, os_name in ipairs(ORDER) do
    local fonts = load(os_name).config.font
    T.ok(type(fonts) == 'table' and type(fonts.font) == 'table', os_name .. ': config.font не font_with_fallback')
    local families = {}
    for i, f in ipairs(fonts.font) do families[i] = f.family end
    -- Каждое имя из списка, которого нет в системе, — окно «wezterm
    -- Configuration Error»; запасные — встроенные шрифты WezTerm.
    T.eq(families, { 'CaskaydiaCove NF', 'CaskaydiaCove Nerd Font' }, os_name .. ': семейства')
  end
end)

T.check('WT-UI-4 символа нет в шрифтах: предупреждений о недостающих глифах нет', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.warn_about_missing_glyphs, false, os_name)
  end
end)

T.check('WT-UI-5 высота строки — 1,05 стандартной', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.line_height, 1.05, os_name)
  end
end)

T.check('WT-UI-6 системный заголовок и рамка для размера: window_decorations = "TITLE | RESIZE"', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.window_decorations, 'TITLE | RESIZE', os_name)
  end
end)

T.check('WT-UI-7 поля 6/14/4/4, правое поле под полосой прокрутки', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.eq(c.window_padding, { left = 6, right = 14, top = 4, bottom = 4 }, os_name .. ': поля')
    T.eq(c.enable_scroll_bar, true, os_name .. ': полоса прокрутки')
  end
end)

T.check('WT-UI-8 звонок без звука и без мигания экрана', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.eq(c.audible_bell, 'Disabled', os_name .. ': audible_bell')
    -- visual_bell не задан: у WezTerm по умолчанию длительности вспышки 0 — экран не мигает.
    T.eq(c.visual_bell, nil, os_name .. ': visual_bell')
  end
end)

T.check('WT-UI-9 мигающий блочный курсор 500 мс без плавного затухания', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.eq({
      style = c.default_cursor_style, rate = c.cursor_blink_rate,
      ease_in = c.cursor_blink_ease_in, ease_out = c.cursor_blink_ease_out, fps = c.animation_fps,
    }, { style = 'BlinkingBlock', rate = 500, ease_in = 'Constant', ease_out = 'Constant', fps = 1 }, os_name)
  end
end)

T.check('WT-UI-10 панель вкладок всегда видна, внизу, простая, вкладка не шире 24 знакомест', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.ok(c.enable_tab_bar ~= false, os_name .. ': enable_tab_bar = false')
    T.eq({
      hide_one = c.hide_tab_bar_if_only_one_tab, fancy = c.use_fancy_tab_bar,
      bottom = c.tab_bar_at_bottom, max_width = c.tab_max_width,
    }, { hide_one = false, fancy = false, bottom = true, max_width = 24 }, os_name)
  end
end)

T.check('WT-UI-10 одна вкладка: « 1: <заголовок> », кнопка «+», левая часть статуса пуста', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    T.ok(res.config.tab_and_split_indices_are_zero_based ~= true, os_name .. ': номера вкладок с 0')
    T.ok(res.config.show_new_tab_button_in_tab_bar ~= false, os_name .. ': кнопка «+» скрыта')
    local titles = tab_titles(os_name, { cols = 118, n = 1, title = 'pwsh' })
    T.eq(titles[1], ' 1: pwsh ', os_name .. ': заголовок вкладки')
    local win = status(os_name)
    T.eq(win.left_status, '', os_name .. ': левая часть статуса')
  end
end)

T.check('WT-UI-10 длинное название вкладки: не шире 24 знакомест, обрезано справа', function()
  for _, os_name in ipairs(ORDER) do
    local t = tab_titles(os_name, { cols = 200, n = 1, title = string.rep('x', 40) })[1]
    T.eq(cells(t), 24, os_name .. ': ширина')
    T.eq(t:sub(1, 4), ' 1: ', os_name .. ': начало заголовка')
  end
end)

T.check('WT-UI-10 название вкладки — имя вкладки, если задано, иначе заголовок активной панели', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(tab_titles(os_name, { cols = 200, n = 1, title = 'pwsh', tab_title = 'сборка' })[1], ' 1: сборка ', os_name)
  end
end)

T.check('WT-UI-11 неактивные панели: насыщенность 85 %, яркость 75 %', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.inactive_pane_hsb, { saturation = 0.85, brightness = 0.75 }, os_name)
  end
end)

-- ---------------------------------------------------------------------------
-- WT-UI-12 Бейдж активного режима
-- ---------------------------------------------------------------------------

T.check('WT-UI-12 бейдж каждого из четырёх режимов: надпись, цвет режима, жирный тёмный текст, перед именем воркспейса', function()
  for _, os_name in ipairs(ORDER) do
    for _, b in ipairs(BADGES) do
      local what = os_name .. ' ' .. b.key_table
      local _, segs = status(os_name, { key_table = b.key_table })
      T.eq(#segs, 2, what .. ': видимых отрезков (бейдж, воркспейс)')
      expect_badge(segs[1], b, what)
      expect_workspace(segs[2], 'default', what)
    end
  end
end)

T.check('WT-UI-12 ни один режим не активен — бейджа нет', function()
  for _, os_name in ipairs(ORDER) do
    local _, segs = status(os_name)
    T.eq(#segs, 1, os_name .. ': видимых отрезков')
    expect_workspace(segs[1], 'default', os_name)
  end
end)

T.check('WT-UI-12 вход в режим WINDOWS и выход по Esc: бейдж WINDOWS появляется и гаснет', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    local enter = action_of(c.keys, 'phys:Space', 'CTRL|SHIFT', os_name)
    T.eq({ enter.name, enter.args and enter.args[1].name }, { 'ActivateKeyTable', 'windows' }, os_name .. ': Ctrl+Shift+Space')
    T.eq(action_of(c.key_tables.windows, 'Escape', 'NONE', os_name), { name = 'PopKeyTable' }, os_name .. ': Esc')
    local _, on = status(os_name, { key_table = 'windows' })
    expect_badge(on[1], BADGES[1], os_name .. ': после входа')
    local _, off = status(os_name)
    T.eq(#off, 1, os_name .. ': после Esc бейджа нет')
  end
end)

T.check('WT-UI-12 подрежим RESIZE: оранжевый бейдж, после Esc бейджа нет — RESIZE заменил WINDOWS', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    local r_act = action_of(c.key_tables.windows, 'phys:R', 'NONE', os_name)
    T.eq(r_act.name, 'ActivateKeyTable', os_name .. ': r в режиме WINDOWS')
    T.eq({ r_act.args[1].name, r_act.args[1].replace_current }, { 'resize_pane', true }, os_name .. ': r заменяет WINDOWS')
    T.eq(action_of(c.key_tables.resize_pane, 'Escape', 'NONE', os_name), { name = 'PopKeyTable' }, os_name .. ': Esc в RESIZE')
    local _, segs = status(os_name, { key_table = 'resize_pane' })
    expect_badge(segs[1], BADGES[2], os_name)
  end
end)

T.check('WT-UI-12 copy mode и поиск: COPY после Ctrl+Shift+X, SEARCH после /, после Esc бейджа нет', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.eq(action_of(c.keys, 'phys:X', 'CTRL|SHIFT', os_name), { name = 'ActivateCopyMode' }, os_name .. ': Ctrl+Shift+X')
    T.eq(action_of(c.key_tables.copy_mode, 'phys:Slash', 'NONE', os_name).name, 'Search', os_name .. ': / в copy mode')
    -- Esc в search mode закрывает весь copy mode (CopyMode Close), а не возвращает в него.
    T.eq(action_of(c.key_tables.search_mode, 'Escape', 'NONE', os_name), { name = 'CopyMode', args = { 'Close' } },
      os_name .. ': Esc в search mode')
    local _, copy = status(os_name, { key_table = 'copy_mode' })
    expect_badge(copy[1], BADGES[3], os_name .. ': COPY')
    local _, search = status(os_name, { key_table = 'search_mode' })
    expect_badge(search[1], BADGES[4], os_name .. ': SEARCH')
  end
end)

T.check('WT-UI-12 оверлей без бейджа (QuickSelect и др.): не таблица клавиш — бейджа нет', function()
  for _, os_name in ipairs(ORDER) do
    local c = load(os_name).config
    T.eq(action_of(c.keys, 'phys:U', 'CTRL|SHIFT', os_name), { name = 'QuickSelect' }, os_name .. ': Ctrl+Shift+U')
    -- Оверлеи — не таблицы клавиш: active_key_table() у WezTerm для них nil;
    -- таблица с другим именем бейджа тоже не даёт.
    for _, case in ipairs({ { what = 'оверлей' }, { what = 'другая таблица', key_table = 'some_other_table' } }) do
      local _, segs = status(os_name, { key_table = case.key_table })
      T.eq(#segs, 1, os_name .. ' ' .. case.what .. ': видимых отрезков')
      expect_workspace(segs[1], 'default', os_name)
    end
  end
end)

T.check('WT-UI-12 два окна: бейдж у каждого окна свой', function()
  for _, os_name in ipairs(ORDER) do
    local res = load(os_name)
    local w1 = F.window({ active_key_table = 'windows' })
    local w2 = F.window({})
    res.events['update-right-status'](w1, F.pane())
    T.eq(w2.right_status, nil, os_name .. ': статус второго окна тронут при обновлении первого')
    res.events['update-right-status'](w2, F.pane())
    local s1, s2 = visible(segments(w1.right_status)), visible(segments(w2.right_status))
    expect_badge(s1[1], BADGES[1], os_name .. ': первое окно')
    T.eq(#s2, 1, os_name .. ': во втором окне бейджа нет')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-UI-13 Имя воркспейса
-- ---------------------------------------------------------------------------

T.check('WT-UI-13 воркспейс по умолчанию: у правого края серым написано default', function()
  for _, os_name in ipairs(ORDER) do
    local _, segs = status(os_name)
    expect_workspace(segs[#segs], 'default', os_name)
  end
end)

T.check('WT-UI-13 переключение воркспейса: показывается имя текущего', function()
  for _, os_name in ipairs(ORDER) do
    local _, segs = status(os_name, { workspace = 'work' })
    expect_workspace(segs[#segs], 'work', os_name)
  end
end)

T.check('WT-UI-13 имя рядом с бейджем: слева бейдж, справа имя воркспейса', function()
  for _, os_name in ipairs(ORDER) do
    local _, segs = status(os_name, { key_table = 'windows', workspace = 'work' })
    T.eq(#segs, 2, os_name)
    expect_badge(segs[1], BADGES[1], os_name)
    expect_workspace(segs[2], 'work', os_name)
  end
end)

-- ---------------------------------------------------------------------------
-- WT-UI-14 Частота обновления статуса
-- ---------------------------------------------------------------------------

T.check('WT-UI-14 статус обновляется каждые 100 мс', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.status_update_interval, 100, os_name)
  end
end)

T.check('WT-UI-14 окно без фокуса: бейдж и имя те же, фокус не учитывается', function()
  for _, os_name in ipairs(ORDER) do
    local _, on = status(os_name, { key_table = 'windows', focused = false })
    expect_badge(on[1], BADGES[1], os_name .. ': режим включён')
    local _, off = status(os_name, { focused = false })
    T.eq(#off, 1, os_name .. ': режим выключен по таймауту — бейджа нет')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-UI-15 Правая часть панели вкладок при нехватке места
-- ---------------------------------------------------------------------------
-- Все символы правой части — в одно знакоместо (ASCII, кириллица, ▶ U+25B6 и
-- · U+00B7: у WezTerm 20240203 ширина 1, пока treat_east_asian_ambiguous_width_as_wide
-- не включён). Ширину вкладок задаёт format-tab-title: n·w + 3 («+») + R ≤ cols,
-- где R — самый длинный бейдж с отступом и имя воркспейса.
local LONG = 'очень длинное название вкладки для проверки'
local NEW_TAB_BUTTON = 3

--- Ширина правой части, которую рисует update-right-status в режиме kt.
local function right_width(os_name, kt, workspace)
  return cells(full_text(status(os_name, { key_table = kt, workspace = workspace })))
end

T.check('WT-UI-15 бейдж WINDOWS с именем default — около 38 знакомест', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(load(os_name).config.treat_east_asian_ambiguous_width_as_wide, nil, os_name .. ': ширина ▶ и ·')
    T.eq(right_width(os_name, 'windows'), 38, os_name)
  end
end)

local function expect_fit(os_name, titles, cols, what)
  local total = NEW_TAB_BUTTON + right_width(os_name, 'windows')
  for i, t in ipairs(titles) do
    total = total + cells(t)
    T.eq(t:sub(1, #(' ' .. i .. ': ')), ' ' .. i .. ': ', ('%s: вкладка %d начинается с « N: »'):format(what, i))
  end
  T.ok(total <= cols, ('%s: вкладки, «+» и правая часть — %d знакомест, окно %d'):format(what, total, cols))
end

T.check('WT-UI-15 бейдж обрезан — больше нет: 4 длинные вкладки сужены до 19, бейдж и default целиком', function()
  for _, os_name in ipairs(ORDER) do
    local titles = tab_titles(os_name, { cols = 118, n = 4, title = LONG })
    for _, t in ipairs(titles) do T.eq(cells(t), 19, os_name .. ': ширина вкладки') end
    expect_fit(os_name, titles, 118, os_name)
  end
end)

T.check('WT-UI-15 вкладки не помещаются: 5 длинных вкладок сужены до 15, правая часть целиком', function()
  for _, os_name in ipairs(ORDER) do
    local titles = tab_titles(os_name, { cols = 118, n = 5, title = LONG })
    for _, t in ipairs(titles) do T.eq(cells(t), 15, os_name .. ': ширина вкладки') end
    expect_fit(os_name, titles, 118, os_name)
  end
end)

T.check('WT-UI-15 мало вкладок: 2 длинные вкладки по 24, не сужены', function()
  for _, os_name in ipairs(ORDER) do
    local titles = tab_titles(os_name, { cols = 118, n = 2, title = LONG })
    for _, t in ipairs(titles) do T.eq(cells(t), 24, os_name .. ': ширина вкладки') end
    expect_fit(os_name, titles, 118, os_name)
  end
end)

T.check('WT-UI-15 вход в режим не сдвигает вкладки: резерв под самый длинный бейдж, любой режим в него влезает', function()
  for _, os_name in ipairs(ORDER) do
    local widest = right_width(os_name, 'windows')
    for _, kt in ipairs({ 'windows', 'resize_pane', 'copy_mode', 'search_mode' }) do
      T.ok(right_width(os_name, kt) <= widest, os_name .. ': бейдж ' .. kt .. ' шире резерва')
    end
    -- format-tab-title не знает режима: заголовки не зависят от него.
    T.eq(tab_titles(os_name, { cols = 118, n = 4, title = LONG }), tab_titles(os_name, { cols = 118, n = 4, title = LONG }),
      os_name)
  end
end)

T.check('WT-UI-15 окно уже правой части: вкладки по одному знакоместу', function()
  for _, os_name in ipairs(ORDER) do
    for _, t in ipairs(tab_titles(os_name, { cols = 28, n = 2, title = LONG })) do
      T.eq(cells(t), 1, os_name .. ': ширина вкладки')
    end
  end
end)

T.check('WT-UI-15 длинное имя воркспейса сужает вкладки; короткое название одной вкладки не меняется', function()
  for _, os_name in ipairs(ORDER) do
    local plain = tab_titles(os_name, { cols = 118, n = 4, title = LONG })
    local long_ws = tab_titles(os_name, { cols = 118, n = 4, title = LONG, workspace = 'очень-длинный-воркспейс' })
    T.ok(cells(long_ws[1]) < cells(plain[1]), os_name .. ': длинное имя воркспейса не сузило вкладки')
    T.eq(tab_titles(os_name, { cols = 118, n = 1, title = 'nvim' })[1], ' 1: nvim ', os_name .. ': короткое название')
  end
end)

T.check('WT-UI-15 без сведений о панелях — обрезка до tab_max_width, как у WezTerm по умолчанию', function()
  for _, os_name in ipairs(ORDER) do
    T.eq(cells(tab_titles(os_name, { n = 3, title = LONG })[1]), 24, os_name)
  end
end)

T.finish()
