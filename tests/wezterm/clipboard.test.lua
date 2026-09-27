-- Проверки wezterm-clipboard через поддельный wezterm: WT-CLIP-1…6 и WT-CLIP-10,
-- а также `y` в copy mode (WT-SCROLL-7): он идёт тем же путём копирования
-- (add-wezterm-spec-checks, задача 3.4; fix-copy-clobbers-clipboard, design D4).
--
-- Путь копирования один: колбэк читает выделение ОДИН раз и пишет в буфер
-- именно прочитанный текст (CopyTextTo). Голого CopyTo нет ни на клавишах, ни
-- в таблицах режимов: без выделения он пишет в буфер пустую строку.
--
-- Без GUI видно:
--   * какие клавиши перехвачены: config.keys, таблицы режимов copy_mode и
--     search_mode (если клавиши нет в таблице режима, WezTerm берёт её из
--     config.keys, а без привязки клавиша уходит программе или оверлею);
--   * что делает колбэк копирования на поддельном окне с выделением и без:
--     win.performed — действия по порядку.
-- Не видно и остаётся ручным (чек-листы review-baseline, статус MANUAL):
--   * текст выделения: обрезка пробелов, мягкий перенос, выделение из одних
--     пробелов → '' (это get_selection_text_for_pane самого WezTerm; подделка
--     отдаёт то, что отдал бы WezTerm);
--   * снятие выделения при перерисовке и окно гонки (WT-CLIP-9);
--   * bracketed paste, переводы строк, нетекстовый буфер, возврат вида к концу
--     истории, вставка в шаблон поиска оверлеем (WT-CLIP-6);
--   * кодирование Ctrl+C для kitty-программ (WT-CLIP-3), мышь (WT-CLIP-7, -8),
--     OSC 52 (WT-CLIP-11).
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')

local ALL = { 'windows', 'macos', 'linux' }
local NOT_WINDOWS = { 'macos', 'linux' }

-- Ожидаемые действия в форме подделки { name, args }.
-- ClipboardAndPrimarySelection: на Windows и macOS это один системный буфер,
-- на Linux — CLIPBOARD и PRIMARY (WT-CLIP-1).
local function copied(text)
  return { name = 'CopyTextTo', args = { { text = text, destination = 'ClipboardAndPrimarySelection' } } }
end
local COPY = copied('abc')
local CLEAR = { name = 'ClearSelection' }
local CTRL_C_TO_PROGRAM = { name = 'SendKey', args = { { key = 'c', mods = 'CTRL' } } }
local PASTE = { name = 'PasteFrom', args = { 'Clipboard' } }
local CLOSE_COPY_MODE = { name = 'CopyMode', args = { 'Close' } }

-- Клавиши копирования по платформам (WT-CLIP-1; Super+C на Linux — WT-CLIP-5).
-- smart — у клавиши двойная роль (умный Ctrl+C на Windows, WT-CLIP-2).
local CTRL_SHIFT_C = { label = 'Ctrl+Shift+C', key = 'phys:C', mods = 'CTRL|SHIFT' }
local CTRL_INSERT = { label = 'Ctrl+Insert', key = 'Insert', mods = 'CTRL' }
local CTRL_C = { label = 'Ctrl+C', key = 'phys:C', mods = 'CTRL', smart = true }
local CMD_C = { label = 'Cmd+C', key = 'phys:C', mods = 'SUPER' }
local SUPER_C = { label = 'Super+C', key = 'phys:C', mods = 'SUPER' }
local COPY_KEYS = {
  windows = { CTRL_C, CTRL_SHIFT_C, CTRL_INSERT },
  macos = { CTRL_SHIFT_C, CTRL_INSERT, CMD_C },
  linux = { CTRL_SHIFT_C, CTRL_INSERT, SUPER_C },
}

-- Клавиши вставки (WT-CLIP-6; Super+V на Linux — из текста требования).
local CTRL_V = { label = 'Ctrl+V', key = 'phys:V', mods = 'CTRL' }
local CTRL_SHIFT_V = { label = 'Ctrl+Shift+V', key = 'phys:V', mods = 'CTRL|SHIFT' }
local SHIFT_INSERT = { label = 'Shift+Insert', key = 'Insert', mods = 'SHIFT' }
local CMD_V = { label = 'Cmd+V', key = 'phys:V', mods = 'SUPER' }
local PASTE_KEYS = {
  windows = { CTRL_V, CTRL_SHIFT_V, SHIFT_INSERT },
  macos = { CTRL_V, CTRL_SHIFT_V, SHIFT_INSERT, CMD_V },
  linux = { CTRL_V, CTRL_SHIFT_V, SHIFT_INSERT, CMD_V },
}

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

local function binding(list, k, where)
  local b = F.find_binding(list, k.key, k.mods)
  if not b then error(('%s: %s (%s %s) не привязана'):format(where, k.label, k.key, F.norm_mods(k.mods)), 0) end
  return b
end

local function unbound(list, k, where)
  local b = F.find_binding(list, k.key, k.mods)
  if b then
    error(('%s: %s (%s %s) привязана к %s, а не должна'):format(where, k.label, k.key, F.norm_mods(k.mods), show(b.action)), 0)
  end
end

-- Нажать клавишу копирования из config.keys: колбэк на поддельных окне и панели.
-- → окно (win.performed — что сделал колбэк).
local function press(os_name, k, win, pane)
  local where = os_name .. ' config.keys'
  local b = binding(config(os_name).keys, k, where)
  if type(b.action) ~= 'table' or b.action.name ~= 'Callback' then
    error(('%s: %s — ожидался колбэк копирования выделения (action_callback), привязано %s;'
      .. ' голый CopyTo при пустом выделении пишет в буфер пустую строку'):format(where, k.label, show(b.action)), 0)
  end
  win = win or F.window()
  F.run_callback(b.action, win, pane or F.pane())
  return win
end

-- Окно с выделением, которое снимает ClearSelection — как в WezTerm: после
-- ClearSelection get_selection_text_for_pane отдаёт ''.
local function window_with_selection(text)
  local current = text
  local win = F.window()
  local perform = win.perform_action
  function win:get_selection_text_for_pane(_pane) return current end
  function win:perform_action(action, pane)
    perform(self, action, pane)
    if F.normalize_action(action).name == 'ClearSelection' then current = '' end
  end
  return win
end

local function names(performed)
  return vim.tbl_map(function(a) return F.normalize_action(a).name end, performed)
end

local function has_action(performed, name)
  return vim.tbl_contains(names(performed), name)
end

-- Буфер обмена записан любым из действий копирования.
local function wrote_clipboard(performed)
  return has_action(performed, 'CopyTo') or has_action(performed, 'CopyTextTo')
end

-- ---------------------------------------------------------------------------
-- WT-CLIP-1 Единое правило копирования
-- ---------------------------------------------------------------------------

T.check('WT-CLIP-1 есть выделение — клавиша копирования пишет его в буфер (CLIPBOARD и PRIMARY), программа нажатие не получает', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs(COPY_KEYS[os_name]) do
      local win = press(os_name, k, F.window({ selection = 'abc' }))
      local what = os_name .. ' ' .. k.label
      T.eq(win.performed[1], COPY, what .. ': первое действие')
      T.ok(not has_action(win.performed, 'SendKey'), what .. ': нажатие ушло программе: ' .. show(win.performed))
    end
  end
end)

T.check('WT-CLIP-1 нет выделения WezTerm (в т.ч. визуальное выделение nvim) — буфер не меняется, программа клавишу не получает', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs(COPY_KEYS[os_name]) do
      local win = press(os_name, k, F.window({ selection = '' }))
      local what = os_name .. ' ' .. k.label
      T.ok(not wrote_clipboard(win.performed), what .. ': без выделения записан буфер: ' .. show(win.performed))
      -- Ctrl+C на Windows без выделения уходит программе — это WT-CLIP-2.
      if not k.smart then T.eq(win.performed, {}, what .. ': действия без выделения') end
    end
  end
end)

T.check('WT-CLIP-1 выделение осталось в другой панели — клавиши копирования его не видят', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs(COPY_KEYS[os_name]) do
      local what = os_name .. ' ' .. k.label
      local left, right = F.pane({ id = 1 }), F.pane({ id = 2 })
      local function selection_in_left(win)
        function win:get_selection_text_for_pane(p) return rawequal(p, left) and 'abc' or '' end
        return win
      end
      -- Активна правая панель: WezTerm передаёт колбэку её.
      local win = press(os_name, k, selection_in_left(F.window()), right)
      T.ok(not wrote_clipboard(win.performed), what .. ': скопировано выделение неактивной панели')
      -- В своей панели то же выделение копируется, и действие выполняется для неё же.
      local own = press(os_name, k, selection_in_left(F.window()), left)
      T.eq(own.performed[1], COPY, what .. ': выделение активной панели')
      local call = vim.iter(own.calls):find(function(c) return c[1] == 'perform_action' end)
      T.ok(call and rawequal(call[3], left), what .. ': копирование выполнено не для панели, в которой нажата клавиша')
    end
  end
end)

T.check('WT-CLIP-1 выделение гаснет в момент нажатия — в буфер идёт прочитанный текст, выделение читается один раз', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs(COPY_KEYS[os_name]) do
      -- Окно отдаёт выделение только при первом чтении: дальше оно погасло.
      local reads = 0
      local win = F.window()
      function win:get_selection_text_for_pane(_pane)
        reads = reads + 1
        return reads == 1 and 'abc' or ''
      end
      press(os_name, k, win)
      local what = os_name .. ' ' .. k.label
      T.eq(win.performed[1], COPY, what .. ': в буфер ушло не прочитанное выделение')
      T.eq(reads, 1, what .. ': сколько раз прочитано выделение')
    end
  end
end)

-- Обход действия вглубь: Multiple и вложенные таблицы аргументов.
local function each_action(action, fn)
  local a = F.normalize_action(action)
  if type(a) ~= 'table' then return end
  if a.name then fn(a) end
  for _, v in pairs(a.args or {}) do
    if type(v) == 'table' then
      if v.name then each_action(v, fn) else for _, sub in pairs(v) do each_action(sub, fn) end end
    end
  end
end

T.check('WT-CLIP-1 голого CopyTo нет — ни в config.keys, ни в таблицах режимов, включая вложенные Multiple', function()
  for _, os_name in ipairs(ALL) do
    local c = config(os_name)
    local lists = { ['config.keys'] = c.keys or {} }
    for name, t in pairs(c.key_tables or {}) do lists['key_tables.' .. name] = t end
    for where, list in pairs(lists) do
      for i, b in ipairs(list) do
        each_action(b.action, function(a)
          T.ok(a.name ~= 'CopyTo', ('%s %s[%d] %s %s: %s'):format(os_name, where, i, tostring(b.key),
            F.norm_mods(b.mods), show(b.action)))
        end)
      end
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-CLIP-2 Умный Ctrl+C на Windows
-- ---------------------------------------------------------------------------

T.check('WT-CLIP-2 есть выделение — Ctrl+C копирует и снимает выделение, программа Ctrl+C не получает', function()
  local win = press('windows', CTRL_C, F.window({ selection = 'abc' }))
  T.eq(win.performed, { COPY, CLEAR })
end)

T.check('WT-CLIP-2 два нажатия подряд — первое копирует и снимает выделение, второе прерывает команду', function()
  local win = window_with_selection('abc')
  press('windows', CTRL_C, win)
  press('windows', CTRL_C, win)
  T.eq(win.performed, { COPY, CLEAR, CTRL_C_TO_PROGRAM })
end)

T.check('WT-CLIP-2 нет выделения (погасло или оно внутри nvim) — Ctrl+C уходит программе, буфер не меняется', function()
  local win = press('windows', CTRL_C, F.window({ selection = '' }))
  T.eq(win.performed, { CTRL_C_TO_PROGRAM })
end)

T.check('WT-CLIP-2 Ctrl+C в copy mode — copy mode закрывается без копирования, программа Ctrl+C не получает', function()
  local b = binding(key_table('windows', 'copy_mode'), CTRL_C, 'windows copy_mode')
  T.eq(b.action, CLOSE_COPY_MODE, 'copy_mode Ctrl+C')
end)

T.check('WT-CLIP-2 Ctrl+C в search mode — в таблице режима его нет, умный Ctrl+C копирует совпадение и снимает выделение', function()
  local search = key_table('windows', 'search_mode')
  unbound(search, CTRL_C, 'windows search_mode')
  unbound(search, { label = 'Ctrl+c (символ)', key = 'mapped:c', mods = 'CTRL' }, 'windows search_mode')
  T.eq(press('windows', CTRL_C, F.window({ selection = 'error' })).performed, { copied('error'), CLEAR }, 'выделенное совпадение')
  -- Без выделенного совпадения SendKey уходит оверлею поиска, а он его игнорирует
  -- (поведение оверлея — ручная проверка).
  T.eq(press('windows', CTRL_C, F.window({ selection = '' })).performed, { CTRL_C_TO_PROGRAM }, 'без совпадения')
end)

-- ---------------------------------------------------------------------------
-- WT-CLIP-3 Ctrl+C на macOS не перехватывается
-- ---------------------------------------------------------------------------

T.check('WT-CLIP-3 Ctrl+C при выделении — не перехвачен, уходит программе как прерывание (macOS, Linux)', function()
  for _, os_name in ipairs(NOT_WINDOWS) do
    local keys = config(os_name).keys
    unbound(keys, CTRL_C, os_name .. ' config.keys')
    unbound(keys, { label = 'Ctrl+c (символ)', key = 'mapped:c', mods = 'CTRL' }, os_name .. ' config.keys')
  end
end)

T.check('WT-CLIP-3 исключения режимов — в copy mode Ctrl+C закрывает его, в search mode не привязан (macOS, Linux)', function()
  for _, os_name in ipairs(NOT_WINDOWS) do
    T.eq(binding(key_table(os_name, 'copy_mode'), CTRL_C, os_name .. ' copy_mode').action, CLOSE_COPY_MODE,
      os_name .. ' copy_mode Ctrl+C')
    unbound(key_table(os_name, 'search_mode'), CTRL_C, os_name .. ' search_mode')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-CLIP-4 Ctrl+Shift+C и Ctrl+Insert
-- ---------------------------------------------------------------------------

T.check('WT-CLIP-4 копирование без снятия выделения — повторное нажатие копирует тот же текст', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs({ CTRL_SHIFT_C, CTRL_INSERT }) do
      local win = window_with_selection('abc')
      press(os_name, k, win)
      press(os_name, k, win)
      T.eq(win.performed, { COPY, COPY }, os_name .. ' ' .. k.label)
    end
  end
end)

T.check('WT-CLIP-4 без выделения клавиша никуда не уходит — буфер не меняется, nvim не получает <C-S-c> и <C-Insert>', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs({ CTRL_SHIFT_C, CTRL_INSERT }) do
      T.eq(press(os_name, k, F.window({ selection = '' })).performed, {}, os_name .. ' ' .. k.label)
    end
  end
end)

T.check('WT-CLIP-4 копирование в copy mode без выхода — в таблицах copy_mode и search_mode этих клавиш нет', function()
  for _, os_name in ipairs(ALL) do
    for _, mode in ipairs({ 'copy_mode', 'search_mode' }) do
      for _, k in ipairs({ CTRL_SHIFT_C, CTRL_INSERT }) do
        unbound(key_table(os_name, mode), k, os_name .. ' ' .. mode)
      end
    end
    -- Клавиша срабатывает из config.keys: копирует, copy mode не закрывает.
    for _, k in ipairs({ CTRL_SHIFT_C, CTRL_INSERT }) do
      T.eq(press(os_name, k, F.window({ selection = 'abc' })).performed, { COPY }, os_name .. ' ' .. k.label)
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-CLIP-5 Cmd+C на macOS (Super+C на Linux)
-- ---------------------------------------------------------------------------

T.check('WT-CLIP-5 выделение мышью — Cmd+C копирует, подсветка остаётся (macOS; Super+C на Linux)', function()
  for _, os_name in ipairs(NOT_WINDOWS) do
    local win = window_with_selection('abc')
    press(os_name, CMD_C, win)
    press(os_name, CMD_C, win)
    T.eq(win.performed, { COPY, COPY }, os_name .. ' Cmd+C')
  end
end)

T.check('WT-CLIP-5 выделение погасло (случай §42) или оно внутри nvim — Cmd+C не пишет пустую строку и в программу не уходит', function()
  for _, os_name in ipairs(NOT_WINDOWS) do
    T.eq(press(os_name, CMD_C, F.window({ selection = '' })).performed, {}, os_name .. ' Cmd+C без выделения')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-SCROLL-7 `y` в copy mode — тот же путь копирования
-- ---------------------------------------------------------------------------

local Y = { label = 'y', key = 'phys:Y', mods = nil }

-- Нажать `y` в copy mode: колбэк на поддельных окне и панели → окно.
local function press_y(os_name, win)
  local where = os_name .. ' copy_mode'
  local b = binding(key_table(os_name, 'copy_mode'), Y, where)
  if type(b.action) ~= 'table' or b.action.name ~= 'Callback' then
    error(('%s: y — ожидался колбэк копирования выделения, привязано %s;'
      .. ' голый CopyTo при пустом выделении пишет в буфер пустую строку'):format(where, show(b.action)), 0)
  end
  F.run_callback(b.action, win, F.pane())
  return win
end

T.check('WT-SCROLL-7 посимвольное выделение и y — выделенный текст в буфере, copy mode выключен', function()
  for _, os_name in ipairs(ALL) do
    T.eq(press_y(os_name, F.window({ selection = 'abc' })).performed, { COPY, CLOSE_COPY_MODE }, os_name .. ': y')
  end
end)

T.check('WT-SCROLL-7 y без выделения — буфер не трогается, copy mode выключен', function()
  for _, os_name in ipairs(ALL) do
    T.eq(press_y(os_name, F.window({ selection = '' })).performed, { CLOSE_COPY_MODE }, os_name .. ': y')
  end
end)

T.check('WT-SCROLL-7 y в таблице copy_mode ровно один — запись заменена, а не дописана', function()
  for _, os_name in ipairs(ALL) do
    local n = 0
    for _, b in ipairs(key_table(os_name, 'copy_mode')) do
      if F.norm_key(b.key) == 'phys:Y' and F.norm_mods(b.mods) == F.norm_mods(nil) then n = n + 1 end
    end
    T.eq(n, 1, os_name .. ': записей y')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-CLIP-6 Вставка
-- ---------------------------------------------------------------------------

T.check('WT-CLIP-6 вставка в шелл — Ctrl+V, Ctrl+Shift+V, Shift+Insert (и Cmd+V на macOS) вставляют буфер, программе не уходят', function()
  for _, os_name in ipairs(ALL) do
    for _, k in ipairs(PASTE_KEYS[os_name]) do
      T.eq(binding(config(os_name).keys, k, os_name .. ' config.keys').action, PASTE, os_name .. ' ' .. k.label)
    end
  end
end)

T.check('WT-CLIP-6 вставка в copy mode и search mode — Ctrl+V в copy mode даёт блок, остальные клавиши вставки идут из config.keys', function()
  for _, os_name in ipairs(ALL) do
    local copy_mode, search = key_table(os_name, 'copy_mode'), key_table(os_name, 'search_mode')
    T.eq(binding(copy_mode, CTRL_V, os_name .. ' copy_mode').action,
      { name = 'CopyMode', args = { { SetSelectionMode = 'Block' } } }, os_name .. ' copy_mode Ctrl+V')
    for _, k in ipairs(PASTE_KEYS[os_name]) do
      if k ~= CTRL_V then unbound(copy_mode, k, os_name .. ' copy_mode') end
      unbound(search, k, os_name .. ' search_mode')
    end
  end
end)

-- ---------------------------------------------------------------------------
-- WT-CLIP-10 Независимость от раскладки
-- ---------------------------------------------------------------------------

-- Клавиша от раскладки не зависит: физическая (phys:) или именованная (Insert).
local function layout_independent(key)
  local k = F.norm_key(key)
  return k:match('^phys:') ~= nil or k:match('^mapped:') == nil
end

T.check('WT-CLIP-10 копирование и вставка привязаны к физическим C и V или к именованной Insert', function()
  for _, os_name in ipairs(ALL) do
    local keys = config(os_name).keys
    local copy_actions = {}
    for _, k in ipairs(COPY_KEYS[os_name]) do copy_actions[binding(keys, k, os_name .. ' config.keys').action] = true end
    local seen = 0
    for i, b in ipairs(keys) do
      local name = F.normalize_action(b.action).name
      if copy_actions[b.action] or name == 'CopyTo' or name == 'CopyTextTo' or name == 'PasteFrom' then
        seen = seen + 1
        local k = F.norm_key(b.key)
        T.ok(layout_independent(b.key) and (k == 'phys:C' or k == 'phys:V' or k == 'Insert'),
          ('%s config.keys[%d]: %s %s — %s зависит от раскладки'):format(os_name, i, tostring(b.key), F.norm_mods(b.mods), show(b.action)))
      end
    end
    T.eq(seen, #COPY_KEYS[os_name] + #PASTE_KEYS[os_name], os_name .. ': число привязок копирования и вставки')
  end
end)

T.check('WT-CLIP-10 Ctrl+C и Ctrl+V на русской раскладке (Windows) — физические C и V', function()
  local keys = config('windows').keys
  T.eq(binding(keys, CTRL_C, 'windows config.keys').key, 'phys:C', 'Ctrl+C')
  T.eq(press('windows', CTRL_C, F.window({ selection = '' })).performed, { CTRL_C_TO_PROGRAM }, 'Ctrl+«с» без выделения')
  T.eq(press('windows', CTRL_C, F.window({ selection = 'abc' })).performed, { COPY, CLEAR }, 'Ctrl+«с» с выделением')
  local paste = binding(keys, CTRL_V, 'windows config.keys')
  T.eq({ paste.key, paste.action }, { 'phys:V', PASTE }, 'Ctrl+«м»')
end)

T.check('WT-CLIP-10 Cmd+C и Cmd+V на русской раскладке (macOS) — физические C и V', function()
  local keys = config('macos').keys
  T.eq(binding(keys, CMD_C, 'macos config.keys').key, 'phys:C', 'Cmd+C')
  T.eq(press('macos', CMD_C, F.window({ selection = 'abc' })).performed, { COPY }, 'Cmd+«с» с выделением')
  local paste = binding(keys, CMD_V, 'macos config.keys')
  T.eq({ paste.key, paste.action }, { 'phys:V', PASTE }, 'Cmd+«м»')
end)

T.finish()
