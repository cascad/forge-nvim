-- Проверки wezterm-scrollback через поддельный wezterm (add-wezterm-spec-checks,
-- задача 3.7; design, решения 3–5): WT-SCROLL-1, -2, -4, -5…12, -13, -15.
--
-- `y` в copy mode идёт общим путём копирования — его поведение проверяет
-- clipboard.test.lua (WT-SCROLL-7).
--
-- Без GUI видно:
--   * настройки config (scrollback_lines, мышь, QuickSelect);
--   * привязки: config.keys, таблица режима windows и таблицы copy_mode и
--     search_mode — встроенные таблицы WezTerm 20240203 (фикстура, снятая с
--     бинарника), переписанные конфигом на phys:. Клавиши, которой нет в таблице
--     режима, WezTerm ищет в config.keys; без привязки её получает оверлей
--     режима (набор шаблона, игнор) — это уже поведение оверлея;
--   * выгрузка истории (WT-SCROLL-13): колбэк на поддельной панели пишет файл в
--     поддельный io и просит вкладку с nvim у поддельного окна.
-- Не видно и остаётся ручным (чек-листы review-baseline, статус MANUAL):
--   вытеснение строк, прокрутка и полоса, поведение оверлеев copy/search/
--   QuickSelect (курсор, отступы H/L, выделение, подсветка, круговой переход,
--   метки, раскладка при наборе символа прыжка и меток), текст, который
--   отдаёт get_lines_as_text (пустые строки, альтернативный экран), CRLF в
--   файле на Windows, альтернативный экран целиком (WT-SCROLL-14), полоса
--   прокрутки (WT-SCROLL-3).
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')

local ALL = { 'windows', 'macos', 'linux' }

local function CM(arg) return { name = 'CopyMode', args = { arg } } end
local POP = { name = 'PopKeyTable' }
-- Команда режима WINDOWS, открывающая экран, сначала выключает режим целиком (WT-WIN-19).
local LEAVE = { name = 'ClearKeyTableStack' }
local function multiple(...) return { name = 'Multiple', args = { { ... } } } end
local CLOSE = CM('Close')
-- Search с пустым шаблоном: тип «без учёта регистра», строка ввода начинается с
-- последнего шаблона вкладки (WT-SCROLL-8, WT-SCROLL-9).
local SEARCH = { name = 'Search', args = { { CaseInSensitiveString = '' } } }
local PASTE = { name = 'PasteFrom', args = { 'Clipboard' } }

-- ---------------------------------------------------------------------------
-- Помощники
-- ---------------------------------------------------------------------------

-- Конфиг по тройке, один раз на файл. Загрузка идёт внутри проверки: ошибка
-- загрузки — FAIL этой проверки, а не падение файла.
local loaded = {}
local function config(os_name)
  if not loaded[os_name] then
    loaded[os_name] = F.load_config({ triple = F.TRIPLES[os_name] })
  end
  return loaded[os_name].config
end

local function key_table(os_name, name)
  local t = (config(os_name).key_tables or {})[name]
  if type(t) ~= 'table' then error(('%s: нет таблицы режима %s'):format(os_name, name), 0) end
  return t
end

local function show(action)
  return vim.inspect(F.normalize_action(action), { newline = ' ', indent = '' })
end

local function where(os_name, list_name) return os_name .. ' ' .. list_name end

-- Действие привязки (key, mods) в списке; нет привязки — ошибка с парой.
local function action_of(list, key, mods, at)
  local b = F.find_binding(list, key, mods)
  if not b then error(('%s: %s %s не привязана'):format(at, key, F.norm_mods(mods)), 0) end
  return F.normalize_action(b.action)
end

local function unbound(list, key, mods, at)
  local b = F.find_binding(list, key, mods)
  if b then
    error(('%s: %s %s привязана к %s, а не должна'):format(at, key, F.norm_mods(mods), show(b.action)), 0)
  end
end

-- Список ожиданий { метка, key, mods, действие } на таблице одной тройки.
local function expect_all(list, at, rows)
  for _, row in ipairs(rows) do
    local label, key, mods, want = row[1], row[2], row[3], row[4]
    T.eq(action_of(list, key, mods, at), want, ('%s: %s (%s %s)'):format(at, label, key, F.norm_mods(mods)))
  end
end

-- Символ, к которому привязана клавиша, если она символьная (зависит от
-- раскладки): 'mapped:x' и одиночный символ без префикса; иначе nil.
local function symbol_of(key)
  return F.norm_key(key):match('^mapped:(.+)$')
end

-- ---------------------------------------------------------------------------
-- WT-SCROLL-1 Глубина истории
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-1 вытеснение старых строк — история 10000 строк (scrollback_lines)', function()
  for _, os_name in ipairs(ALL) do
    T.eq(config(os_name).scrollback_lines, 10000, os_name)
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-2 Прокрутка истории
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-2 Shift+PageUp и Shift+PageDown — на экран вверх и вниз, программе не уходят (и в полноэкранной программе)', function()
  for _, os_name in ipairs(ALL) do
    expect_all(config(os_name).keys, where(os_name, 'config.keys'), {
      { 'Shift+PageUp', 'PageUp', 'SHIFT', { name = 'ScrollByPage', args = { -1 } } },
      { 'Shift+PageDown', 'PageDown', 'SHIFT', { name = 'ScrollByPage', args = { 1 } } },
    })
  end
end)

-- Колесо, возврат к концу при вводе и три стрелки на щелчок на альтернативном
-- экране — штатное поведение WezTerm (значения по умолчанию 20240203 по его
-- документации: disable_default_mouse_bindings = false, scroll_to_bottom_on_input
-- = true, alternate_buffer_wheel_scroll_speed = 3). Контракт конфига — их не менять.
T.check('WT-SCROLL-2 колесо в шелле — штатные привязки мыши не отключены и не переопределены', function()
  for _, os_name in ipairs(ALL) do
    local c = config(os_name)
    T.ok(c.disable_default_mouse_bindings ~= true, os_name .. ': disable_default_mouse_bindings = true')
    T.eq(c.mouse_bindings, nil, os_name .. ': mouse_bindings')
  end
end)

T.check('WT-SCROLL-2 ввод возвращает к концу истории — scroll_to_bottom_on_input не выключен', function()
  for _, os_name in ipairs(ALL) do
    T.ok(config(os_name).scroll_to_bottom_on_input ~= false, os_name .. ': scroll_to_bottom_on_input = false')
  end
end)

T.check('WT-SCROLL-2 колесо в полноэкранной программе — три стрелки на щелчок (alternate_buffer_wheel_scroll_speed по умолчанию)', function()
  for _, os_name in ipairs(ALL) do
    T.eq(config(os_name).alternate_buffer_wheel_scroll_speed, nil, os_name .. ': alternate_buffer_wheel_scroll_speed')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-4 Очистка истории
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-4 очистка в шелле — Ctrl+Shift+Delete (физическая) стирает историю выше экрана, экран не трогает', function()
  for _, os_name in ipairs(ALL) do
    local keys = config(os_name).keys
    local b = F.find_binding(keys, 'phys:Delete', 'CTRL|SHIFT')
    T.ok(b, os_name .. ': Ctrl+Shift+Delete (phys:Delete CTRL|SHIFT) не привязана')
    T.eq({ b.key, F.normalize_action(b.action) }, { 'phys:Delete', { name = 'ClearScrollback', args = { 'ScrollbackOnly' } } },
      os_name .. ': Ctrl+Shift+Delete')
  end
end)

T.check('WT-SCROLL-4 Backspace на Mac не очищает — Ctrl+Shift+⌫ не перехвачен, очистка только на Delete (не на Ctrl+Shift+K)', function()
  for _, os_name in ipairs(ALL) do
    local keys = config(os_name).keys
    local at = where(os_name, 'config.keys')
    unbound(keys, 'Backspace', 'CTRL|SHIFT', at)
    unbound(keys, 'phys:Backspace', 'CTRL|SHIFT', at)
    local clear = {}
    for i, b in ipairs(keys) do
      if F.normalize_action(b.action).name == 'ClearScrollback' then
        clear[#clear + 1] = ('[%d] %s %s'):format(i, tostring(b.key), F.norm_mods(b.mods))
      end
    end
    T.eq(#clear, 1, at .. ': привязки ClearScrollback: ' .. table.concat(clear, ', '))
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-5 Copy mode: вход, выход и общие свойства
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-5 вход по Ctrl+Shift+X — ActivateCopyMode (без таймаута)', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(config(os_name).keys, 'phys:X', 'CTRL|SHIFT', where(os_name, 'config.keys')),
      { name = 'ActivateCopyMode' }, os_name .. ': Ctrl+Shift+X')
  end
end)

T.check('WT-SCROLL-5 вход из режима WINDOWS — физическая [ выключает WINDOWS, затем включает copy mode', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'windows'), 'phys:LeftBracket', nil, where(os_name, 'windows')),
      multiple(LEAVE, { name = 'ActivateCopyMode' }), os_name .. ': [ в режиме WINDOWS')
  end
end)

T.check('WT-SCROLL-5 выход без копирования — Esc, q, Ctrl+C и Ctrl+G закрывают copy mode', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'Esc', 'Escape', nil, CLOSE },
      { 'q', 'phys:Q', nil, CLOSE },
      { 'Ctrl+C', 'phys:C', 'CTRL', CLOSE },
      { 'Ctrl+G', 'phys:G', 'CTRL', CLOSE },
    })
  end
end)

T.check('WT-SCROLL-5 посторонние клавиши (i, x, a, 1–9) в copy mode не привязаны — программа их не получает', function()
  for _, os_name in ipairs(ALL) do
    local cm, keys = key_table(os_name, 'copy_mode'), config(os_name).keys
    local stray = { 'phys:I', 'phys:X', 'phys:A', 'mapped:i', 'mapped:x', 'mapped:a' }
    for d = 1, 9 do stray[#stray + 1] = 'phys:' .. d; stray[#stray + 1] = 'mapped:' .. d end
    for _, k in ipairs(stray) do
      unbound(cm, k, nil, where(os_name, 'copy_mode'))
      unbound(keys, k, nil, where(os_name, 'config.keys'))
    end
  end
end)

T.check('WT-SCROLL-5 привязки вне copy mode работают — в copy_mode нет сочетаний Ctrl+Shift, повторный Ctrl+Shift+X снова ActivateCopyMode', function()
  for _, os_name in ipairs(ALL) do
    for i, b in ipairs(key_table(os_name, 'copy_mode')) do
      local m = '|' .. F.norm_mods(b.mods) .. '|'
      T.ok(not (m:find('|CTRL|', 1, true) and m:find('|SHIFT|', 1, true)),
        ('%s copy_mode[%d]: %s %s перекрывает привязку Ctrl+Shift из config.keys'):format(os_name, i, tostring(b.key), F.norm_mods(b.mods)))
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-6 Copy mode: навигация на любой раскладке
-- ---------------------------------------------------------------------------

-- Клавиши из текста требования → физическая клавиша US-раскладки и движение.
local NAVIGATION = {
  { 'h', 'phys:H', nil, CM('MoveLeft') },
  { 'j', 'phys:J', nil, CM('MoveDown') },
  { 'k', 'phys:K', nil, CM('MoveUp') },
  { 'l', 'phys:L', nil, CM('MoveRight') },
  { '←', 'LeftArrow', nil, CM('MoveLeft') },
  { '↓', 'DownArrow', nil, CM('MoveDown') },
  { '↑', 'UpArrow', nil, CM('MoveUp') },
  { '→', 'RightArrow', nil, CM('MoveRight') },
  { 'w', 'phys:W', nil, CM('MoveForwardWord') },
  { 'Tab', 'Tab', nil, CM('MoveForwardWord') },
  { 'Alt+→', 'RightArrow', 'ALT', CM('MoveForwardWord') },
  { 'Alt+f', 'phys:F', 'ALT', CM('MoveForwardWord') },
  { 'b', 'phys:B', nil, CM('MoveBackwardWord') },
  { 'Shift+Tab', 'Tab', 'SHIFT', CM('MoveBackwardWord') },
  { 'Alt+←', 'LeftArrow', 'ALT', CM('MoveBackwardWord') },
  { 'Alt+b', 'phys:B', 'ALT', CM('MoveBackwardWord') },
  { 'e', 'phys:E', nil, CM('MoveForwardWordEnd') },
  { '0', 'phys:0', nil, CM('MoveToStartOfLine') },
  { 'Home', 'Home', nil, CM('MoveToStartOfLine') },
  { '^ (Shift+6)', 'phys:6', 'SHIFT', CM('MoveToStartOfLineContent') },
  { 'Alt+m', 'phys:M', 'ALT', CM('MoveToStartOfLineContent') },
  { '$ (Shift+4)', 'phys:4', 'SHIFT', CM('MoveToEndOfLineContent') },
  { 'End', 'End', nil, CM('MoveToEndOfLineContent') },
  { 'Enter', 'Enter', nil, CM('MoveToStartOfNextLine') },
  { 'g', 'phys:G', nil, CM('MoveToScrollbackTop') },
  { 'G (Shift+g)', 'phys:G', 'SHIFT', CM('MoveToScrollbackBottom') },
  { 'H (Shift+h)', 'phys:H', 'SHIFT', CM('MoveToViewportTop') },
  { 'M (Shift+m)', 'phys:M', 'SHIFT', CM('MoveToViewportMiddle') },
  { 'L (Shift+l)', 'phys:L', 'SHIFT', CM('MoveToViewportBottom') },
  { 'Ctrl+u', 'phys:U', 'CTRL', CM({ MoveByPage = -0.5 }) },
  { 'Ctrl+d', 'phys:D', 'CTRL', CM({ MoveByPage = 0.5 }) },
  { 'Ctrl+b', 'phys:B', 'CTRL', CM('PageUp') },
  { 'PageUp', 'PageUp', nil, CM('PageUp') },
  { 'Ctrl+f', 'phys:F', 'CTRL', CM('PageDown') },
  { 'PageDown', 'PageDown', nil, CM('PageDown') },
  { 'f', 'phys:F', nil, CM({ JumpForward = { prev_char = false } }) },
  { 'F (Shift+f)', 'phys:F', 'SHIFT', CM({ JumpBackward = { prev_char = false } }) },
  { 't', 'phys:T', nil, CM({ JumpForward = { prev_char = true } }) },
  { 'T (Shift+t)', 'phys:T', 'SHIFT', CM({ JumpBackward = { prev_char = true } }) },
  { ';', 'phys:Semicolon', nil, CM('JumpAgain') },
  { ',', 'phys:Comma', nil, CM('JumpReverse') },
}

T.check('WT-SCROLL-6 клавиши навигации из требования — на физических клавишах US-раскладки, с нужными движениями', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), NAVIGATION)
  end
end)

T.check('WT-SCROLL-6 в copy_mode нет символьных привязок букв, цифр и знаков (символьный остался только пробел)', function()
  for _, os_name in ipairs(ALL) do
    local symbols = {}
    for i, b in ipairs(key_table(os_name, 'copy_mode')) do
      local s = symbol_of(b.key)
      if s and s ~= ' ' then symbols[#symbols + 1] = ('[%d] %q %s'):format(i, tostring(b.key), F.norm_mods(b.mods)) end
    end
    T.eq(symbols, {}, os_name .. ' copy_mode: привязки по символу раскладки')
  end
end)

T.check('WT-SCROLL-6 g и G не путаются; gg как в vim — одиночная g уже в начале истории', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'g', 'phys:G', nil, CM('MoveToScrollbackTop') },
      { 'Shift+g', 'phys:G', 'SHIFT', CM('MoveToScrollbackBottom') },
    })
  end
end)

T.check('WT-SCROLL-6 русская раскладка — физические H J K L и Shift+G («р о л д», «П»)', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'H («р»)', 'phys:H', nil, CM('MoveLeft') },
      { 'J («о»)', 'phys:J', nil, CM('MoveDown') },
      { 'K («л»)', 'phys:K', nil, CM('MoveUp') },
      { 'L («д»)', 'phys:L', nil, CM('MoveRight') },
      { 'Shift+G («П»)', 'phys:G', 'SHIFT', CM('MoveToScrollbackBottom') },
    })
  end
end)

T.check('WT-SCROLL-6 знак $ на русской раскладке — Shift+4 (печатает «;») в конец содержимого строки', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'copy_mode'), 'phys:4', 'SHIFT', where(os_name, 'copy_mode')),
      CM('MoveToEndOfLineContent'), os_name .. ': Shift+4')
  end
end)

T.check('WT-SCROLL-6 прыжок к кириллической букве — физическая F («а») начинает прыжок вперёд', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'copy_mode'), 'phys:F', nil, where(os_name, 'copy_mode')),
      CM({ JumpForward = { prev_char = false } }), os_name .. ': F')
  end
end)

T.check('WT-SCROLL-6 H и L с отступом — Shift+H верх, Shift+L низ видимого экрана', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'Shift+h', 'phys:H', 'SHIFT', CM('MoveToViewportTop') },
      { 'Shift+l', 'phys:L', 'SHIFT', CM('MoveToViewportBottom') },
    })
  end
end)

T.check('WT-SCROLL-6 без GUI встроенных таблиц нет — конфиг не задаёт copy_mode и search_mode, остаются штатные', function()
  for _, os_name in ipairs(ALL) do
    local c = F.load_config({ triple = F.TRIPLES[os_name], gui = false }).config
    local kt = c.key_tables or {}
    T.eq({ kt.copy_mode, kt.search_mode }, { nil, nil }, os_name .. ' без GUI')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-7 Copy mode: выделение и копирование `y`
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-7 v и Space — посимвольное, Shift+V — построчное, Ctrl+V — прямоугольное выделение', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'v', 'phys:V', nil, CM({ SetSelectionMode = 'Cell' }) },
      { 'Space', 'mapped: ', nil, CM({ SetSelectionMode = 'Cell' }) },
      { 'Shift+v', 'phys:V', 'SHIFT', CM({ SetSelectionMode = 'Line' }) },
      { 'Ctrl+v', 'phys:V', 'CTRL', CM({ SetSelectionMode = 'Block' }) },
    })
  end
end)

T.check('WT-SCROLL-7 o и O — курсор на другой конец выделения', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'o', 'phys:O', nil, CM('MoveToSelectionOtherEnd') },
      { 'Shift+o', 'phys:O', 'SHIFT', CM('MoveToSelectionOtherEndHoriz') },
    })
  end
end)

T.check('WT-SCROLL-7 копирование без выхода — Ctrl+Shift+C, Ctrl+Insert, Cmd+C в copy mode не выключают его', function()
  for _, os_name in ipairs(ALL) do
    local cm, keys = key_table(os_name, 'copy_mode'), config(os_name).keys
    local copy_keys = { { 'phys:C', 'CTRL|SHIFT' }, { 'Insert', 'CTRL' } }
    if os_name ~= 'windows' then copy_keys[#copy_keys + 1] = { 'phys:C', 'SUPER' } end
    for _, k in ipairs(copy_keys) do
      unbound(cm, k[1], k[2], where(os_name, 'copy_mode'))
      local b = F.find_binding(keys, k[1], k[2])
      T.ok(b and b.action.name == 'Callback', ('%s config.keys: %s %s — не колбэк копирования'):format(os_name, k[1], k[2]))
      local win = F.window({ selection = 'abc' })
      F.run_callback(b.action, win, F.pane())
      T.eq(win.performed, { { name = 'CopyTextTo', args = { { text = 'abc', destination = 'ClipboardAndPrimarySelection' } } } },
        ('%s: %s %s в copy mode'):format(os_name, k[1], k[2]))
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-8 Copy mode: поиск `/`, `n`, `N`
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-8 переход в поиск (и на русской раскладке) — физическая / открывает search mode с текущим шаблоном', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'copy_mode'), 'phys:Slash', nil, where(os_name, 'copy_mode')), SEARCH,
      os_name .. ': / («.»)')
  end
end)

T.check('WT-SCROLL-8 n и N — к следующему (ниже) и предыдущему (выше) совпадению', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'n', 'phys:N', nil, CM('NextMatch') },
      { 'N («Т» с Shift)', 'phys:N', 'SHIFT', CM('PriorMatch') },
    })
  end
end)

T.check('WT-SCROLL-8 /, n, N добавлены конфигом — во встроенной таблице copy_mode 20240203 поиска нет', function()
  local builtin = F.real_default_key_tables().copy_mode
  T.ok(type(builtin) == 'table' and #builtin > 0, 'в фикстуре нет copy_mode')
  local found = {}
  for _, b in ipairs(builtin) do
    local a = F.from_real_action(b.action)
    local sub = a.name == 'CopyMode' and a.args[1] or nil
    if a.name == 'Search' or sub == 'NextMatch' or sub == 'PriorMatch'
        or vim.tbl_contains({ 'mapped:/', 'mapped:n', 'mapped:N' }, F.norm_key(b.key)) then
      found[#found + 1] = ('%s %s → %s'):format(b.key, b.mods, show(a))
    end
  end
  T.eq(found, {}, 'поиск во встроенной copy_mode')
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-9 Search mode: вход и набор шаблона
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-9 поиск из режима WINDOWS — f выключает WINDOWS и открывает search mode без учёта регистра', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'windows'), 'phys:F', nil, where(os_name, 'windows')), multiple(LEAVE, SEARCH),
      os_name .. ': f в режиме WINDOWS')
  end
end)

T.check('WT-SCROLL-9 кириллица в шаблоне — печатные клавиши search mode не перехватывает, только Ctrl+… и именованные', function()
  local named = { Enter = true, Escape = true, UpArrow = true, DownArrow = true, PageUp = true, PageDown = true }
  for _, os_name in ipairs(ALL) do
    for i, b in ipairs(key_table(os_name, 'search_mode')) do
      local mods = '|' .. F.norm_mods(b.mods) .. '|'
      T.ok(mods:find('|CTRL|', 1, true) or named[F.norm_key(b.key)],
        ('%s search_mode[%d]: %s %s перехватывает печатную клавишу'):format(os_name, i, tostring(b.key), F.norm_mods(b.mods)))
    end
  end
end)

T.check('WT-SCROLL-9 тип совпадения и очистка — Ctrl+R перебирает тип, Ctrl+U очищает шаблон', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'search_mode'), where(os_name, 'search_mode'), {
      { 'Ctrl+R', 'phys:R', 'CTRL', CM('CycleMatchType') },
      { 'Ctrl+U', 'phys:U', 'CTRL', CM('ClearPattern') },
    })
  end
end)

T.check('WT-SCROLL-9 переходы — ↑ и Ctrl+P к совпадению выше, ↓ и Ctrl+N ниже', function()
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'search_mode'), where(os_name, 'search_mode'), {
      { '↑', 'UpArrow', nil, CM('PriorMatch') },
      { 'Ctrl+P', 'phys:P', 'CTRL', CM('PriorMatch') },
      { '↓', 'DownArrow', nil, CM('NextMatch') },
      { 'Ctrl+N', 'phys:N', 'CTRL', CM('NextMatch') },
    })
  end
end)

T.check('WT-SCROLL-9 вставка в шаблон — Ctrl+V в search_mode не привязан, срабатывает вставка из config.keys', function()
  for _, os_name in ipairs(ALL) do
    unbound(key_table(os_name, 'search_mode'), 'phys:V', 'CTRL', where(os_name, 'search_mode'))
    T.eq(action_of(config(os_name).keys, 'phys:V', 'CTRL', where(os_name, 'config.keys')), PASTE, os_name .. ': Ctrl+V')
  end
end)

T.check('WT-SCROLL-9 клавиши управления поиском на любой раскладке — в search_mode нет привязок по символу', function()
  for _, os_name in ipairs(ALL) do
    local symbols = {}
    for i, b in ipairs(key_table(os_name, 'search_mode')) do
      if symbol_of(b.key) then symbols[#symbols + 1] = ('[%d] %q %s'):format(i, tostring(b.key), F.norm_mods(b.mods)) end
    end
    T.eq(symbols, {}, os_name .. ' search_mode: привязки по символу раскладки')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-10 Search mode: Enter
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-10 Enter после набора шаблона — принимает шаблон, панель в copy mode на совпадении', function()
  for _, os_name in ipairs(ALL) do
    local sm, at = key_table(os_name, 'search_mode'), where(os_name, 'search_mode')
    T.eq(action_of(sm, 'Enter', nil, at), CM('AcceptPattern'), os_name .. ': Enter')
    -- Запись заменена, а не дописана: при повторе WezTerm молча берёт последнюю.
    local n = 0
    for _, b in ipairs(sm) do
      if F.norm_key(b.key) == 'Enter' and F.norm_mods(b.mods) == F.norm_mods(nil) then n = n + 1 end
    end
    T.eq(n, 1, os_name .. ': записей Enter')
  end
end)

T.check('WT-SCROLL-10 ↑ и Ctrl+P остаются переходом вверх — Enter у них не отнят', function()
  for _, os_name in ipairs(ALL) do
    local sm, at = key_table(os_name, 'search_mode'), where(os_name, 'search_mode')
    T.eq(action_of(sm, 'UpArrow', nil, at), CM('PriorMatch'), os_name .. ': ↑')
  end
end)

T.check('WT-SCROLL-10 после Enter n и N ходят по совпадениям — в copy_mode n/N это NextMatch/PriorMatch', function()
  for _, os_name in ipairs(ALL) do
    local cm, at = key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode')
    T.eq(action_of(cm, 'phys:N', nil, at), CM('NextMatch'), os_name .. ': n')
    T.eq(action_of(cm, 'phys:N', 'SHIFT', at), CM('PriorMatch'), os_name .. ': N')
  end
end)

T.check('WT-SCROLL-10 после Enter n — это буква: n в search_mode не привязана', function()
  for _, os_name in ipairs(ALL) do
    local sm, at = key_table(os_name, 'search_mode'), where(os_name, 'search_mode')
    unbound(sm, 'phys:N', nil, at)
    unbound(sm, 'mapped:n', nil, at)
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-11 Search mode: выход
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-11 Esc закрывает всё — поиск вместе с copy mode', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'search_mode'), 'Escape', nil, where(os_name, 'search_mode')), CLOSE,
      os_name .. ': Esc')
  end
end)

T.check('WT-SCROLL-11 из поиска в copy mode на совпадении — Ctrl+Shift+X не в search_mode, срабатывает ActivateCopyMode', function()
  for _, os_name in ipairs(ALL) do
    unbound(key_table(os_name, 'search_mode'), 'phys:X', 'CTRL|SHIFT', where(os_name, 'search_mode'))
    T.eq(action_of(config(os_name).keys, 'phys:X', 'CTRL|SHIFT', where(os_name, 'config.keys')),
      { name = 'ActivateCopyMode' }, os_name .. ': Ctrl+Shift+X')
  end
end)

T.check('WT-SCROLL-11 q в поиске — дописывается в шаблон; Ctrl+G нигде не привязан', function()
  for _, os_name in ipairs(ALL) do
    local sm = key_table(os_name, 'search_mode')
    unbound(sm, 'phys:Q', nil, where(os_name, 'search_mode'))
    unbound(sm, 'mapped:q', nil, where(os_name, 'search_mode'))
    unbound(sm, 'phys:G', 'CTRL', where(os_name, 'search_mode'))
    unbound(config(os_name).keys, 'phys:G', 'CTRL', where(os_name, 'config.keys'))
    unbound(config(os_name).keys, 'mapped:g', 'CTRL', where(os_name, 'config.keys'))
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-12 QuickSelect
-- ---------------------------------------------------------------------------

-- Метки, шаблоны и глубина поиска — штатные значения WezTerm 20240203 (по его
-- документации: quick_select_alphabet = 'asdfqwerzxcvjklmiuopghtybn', штатные
-- шаблоны, QuickSelect без аргументов — 1000 строк). Контракт конфига — их не менять.
T.check('WT-SCROLL-12 копирование URL — Ctrl+Shift+U включает QuickSelect со штатными шаблонами и метками', function()
  for _, os_name in ipairs(ALL) do
    local c = config(os_name)
    T.eq(action_of(c.keys, 'phys:U', 'CTRL|SHIFT', where(os_name, 'config.keys')), { name = 'QuickSelect' },
      os_name .. ': Ctrl+Shift+U')
    T.eq({ c.quick_select_alphabet, c.quick_select_patterns }, { nil, nil }, os_name .. ': метки и шаблоны')
    T.ok(c.disable_default_quick_select_patterns ~= true, os_name .. ': штатные шаблоны отключены')
  end
end)

T.check('WT-SCROLL-12 вход из режима WINDOWS — Space выключает WINDOWS и включает QuickSelect', function()
  for _, os_name in ipairs(ALL) do
    T.eq(action_of(key_table(os_name, 'windows'), 'phys:Space', nil, where(os_name, 'windows')),
      multiple(LEAVE, { name = 'QuickSelect' }), os_name .. ': Space в режиме WINDOWS')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-13 Выгрузка истории в nvim
-- ---------------------------------------------------------------------------

-- Текст, как его отдаёт get_lines_as_text WezTerm: хвостовые пробелы строк
-- срезаны, пустых строк нет, в конце перевода строки нет (так в спеке; вывод
-- самого WezTerm — ручная проверка).
local DUMP_TEXT = 'PS C:\\> echo первая\nпервая\nPS C:\\> echo вторая\nвторая\nPS C:\\>'
local DUMP_DIMS = { cols = 120, viewport_rows = 40, scrollback_rows = 4321, physical_top = 4281 }

-- Колбэк выгрузки из таблицы режима windows: `b` — Multiple{ PopKeyTable, колбэк }.
-- → колбэк, результат load_config, путь файла выгрузки.
local function scrollback_callback(os_name, opts)
  opts = opts or {}
  local res = F.load_config({ triple = F.TRIPLES[os_name], unwritable = opts.unwritable })
  local b = F.find_binding((res.config.key_tables or {}).windows, 'phys:B', nil)
  T.ok(b, os_name .. ' windows: b (phys:B) не привязана')
  local a = F.normalize_action(b.action)
  T.ok(a.name == 'Multiple' and #a.args[1] == 2, os_name .. ' windows: b — не Multiple из двух действий: ' .. show(a))
  T.eq(a.args[1][1], LEAVE, os_name .. ' windows: b сначала выключает режим WINDOWS')
  local cb = a.args[1][2]
  T.ok(type(cb) == 'table' and cb.name == 'Callback', os_name .. ' windows: b — второе действие не колбэк: ' .. show(cb))
  return cb, res, res.wezterm.home_dir .. '/.wezterm_scrollback.txt'
end

T.check('WT-SCROLL-13 выгрузка вывода шелла — b пишет историю и экран в ~/.wezterm_scrollback.txt и открывает его в nvim + новой вкладкой', function()
  for _, os_name in ipairs(ALL) do
    local cb, res, path = scrollback_callback(os_name)
    local pane = F.pane({ text = DUMP_TEXT, dimensions = DUMP_DIMS })
    local win = F.window()
    F.run_callback(cb, win, pane)
    -- История и экран: все scrollback_rows строк панели.
    T.eq(vim.tbl_filter(function(e) return e.op == 'get_lines_as_text' end, pane.log),
      { { op = 'get_lines_as_text', pane = pane.id, n = DUMP_DIMS.scrollback_rows } }, os_name .. ': чтение истории')
    T.eq(res.writes, { [path] = DUMP_TEXT }, os_name .. ': файл выгрузки (последняя строка без перевода строки)')
    -- nvim из PATH, без NVIM_APPNAME и лаунчера nvim_forge, курсор на последней строке (`+`).
    T.eq(win.performed, { { name = 'SpawnCommandInNewTab', args = { { args = { 'nvim', '+', path } } } } },
      os_name .. ': новая вкладка')
    T.eq(win.toasts, {}, os_name .. ': уведомления')
  end
end)

T.check('WT-SCROLL-13 повторный вызов — файл перезаписан выводом второго вызова, открыта ещё одна вкладка', function()
  for _, os_name in ipairs(ALL) do
    local cb, res, path = scrollback_callback(os_name)
    local win = F.window()
    F.run_callback(cb, win, F.pane({ text = 'первый вызов\nдлинный вывод', dimensions = DUMP_DIMS }))
    F.run_callback(cb, win, F.pane({ text = 'второй', dimensions = DUMP_DIMS }))
    T.eq(res.writes, { [path] = 'второй' }, os_name .. ': файл после второго вызова')
    local spawn = { name = 'SpawnCommandInNewTab', args = { { args = { 'nvim', '+', path } } } }
    T.eq(win.performed, { spawn, spawn }, os_name .. ': вкладки')
  end
end)

T.check('WT-SCROLL-13 не удалось записать файл — уведомление «Не удалось записать …», nvim не запускается', function()
  for _, os_name in ipairs(ALL) do
    local path = F.HOME .. '/.wezterm_scrollback.txt'
    local cb, res = scrollback_callback(os_name, { unwritable = { [path] = true } })
    local win = F.window()
    F.run_callback(cb, win, F.pane({ text = DUMP_TEXT, dimensions = DUMP_DIMS }))
    T.eq(win.performed, {}, os_name .. ': действия')
    T.eq(res.writes, {}, os_name .. ': записи')
    T.eq(win.toasts, { { title = 'WezTerm', message = 'Не удалось записать ' .. path, timeout = 3000 } },
      os_name .. ': уведомление')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-15 Search mode: PageUp и PageDown
-- ---------------------------------------------------------------------------

T.check('WT-SCROLL-15 PageDown и PageUp в search mode — встроенные NextMatchPage и PriorMatchPage без изменений', function()
  local builtin = {}
  for _, b in ipairs(F.real_default_key_tables().search_mode or {}) do
    local _, _, id = F.norm_binding(b.key, b.mods)
    builtin[id] = F.from_real_action(b.action)
  end
  T.eq({ builtin['PageDown NONE'], builtin['PageUp NONE'] }, { CM('NextMatchPage'), CM('PriorMatchPage') },
    'встроенная search_mode 20240203')
  for _, os_name in ipairs(ALL) do
    expect_all(key_table(os_name, 'search_mode'), where(os_name, 'search_mode'), {
      { 'PageDown', 'PageDown', nil, CM('NextMatchPage') },
      { 'PageUp', 'PageUp', nil, CM('PriorMatchPage') },
    })
    -- В copy mode те же клавиши — на экран (WT-SCROLL-6), в обычную сторону.
    expect_all(key_table(os_name, 'copy_mode'), where(os_name, 'copy_mode'), {
      { 'PageDown', 'PageDown', nil, CM('PageDown') },
      { 'PageUp', 'PageUp', nil, CM('PageUp') },
    })
  end
end)

T.finish()
