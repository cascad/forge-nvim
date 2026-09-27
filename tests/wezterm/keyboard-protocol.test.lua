-- Проверки wezterm-keyboard-protocol (WT-KBD-*) через подделку wezterm
-- (add-wezterm-spec-checks, задача 3.1). Характеризация базовой линии (фаза 1):
-- код как есть, в части, видимой в конфиге.
--
-- Автоматически: настройки протокола по тройкам (WT-KBD-1, -2, -5), Alt как Meta
-- (WT-KBD-4), маска IME (WT-KBD-3), клавиши, которые WezTerm шлёт от себя
-- (WT-KBD-7: SendKey F13 на Ctrl+[ и Ctrl+C без выделения на Windows).
-- Вручную (исход зависит от кодировщика клавиш WezTerm, ConPTY, IME, раскладки
-- ОС; design, решение 4): что именно получает программа — сценарии с набором
-- текста в Claude Code и nvim, kitty push/set/pop и запрос `CSI ?u`, байты
-- `CSI 25~` / 0x03 / `CSI 27;5;99~`, правый Alt/AltGr, WT-KBD-6 и WT-KBD-8 целиком.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')

local OSES = { 'windows', 'macos', 'linux' }

local loaded = {}
--- Конфиг для тройки (загружается один раз; проверки его не меняют).
local function load(os_name)
  if not loaded[os_name] then loaded[os_name] = F.load_config({ triple = F.TRIPLES[os_name] }) end
  return loaded[os_name]
end

local function binding(os_name, key, mods)
  local b, _, count = F.find_binding(load(os_name).config.keys, key, mods)
  T.ok(b, ('%s: нет привязки %s %s'):format(os_name, key, mods or 'NONE'))
  T.eq(count, 1, ('%s: %s %s — записей'):format(os_name, key, mods or 'NONE'))
  return b
end

-- ---------------------------------------------------------------------------
-- WT-KBD-1 Windows — win32-input-mode, kitty выключен
-- ---------------------------------------------------------------------------
T.check('WT-KBD-1 Windows: протокол win32-input-mode, kitty keyboard protocol выключен', function()
  local c = load('windows').config
  T.eq(c.allow_win32_input_mode, true, 'allow_win32_input_mode')
  T.eq(c.enable_kitty_keyboard, false, 'enable_kitty_keyboard')
end)

-- ---------------------------------------------------------------------------
-- WT-KBD-2 macOS — kitty включён (Linux — ветка «не Windows», Purpose спеки)
-- ---------------------------------------------------------------------------
T.check('WT-KBD-2 macOS: kitty keyboard protocol включён', function()
  T.eq(load('macos').config.enable_kitty_keyboard, true, 'enable_kitty_keyboard')
end)

T.check('WT-KBD-2 Linux получает ветку «не Windows»: kitty включён', function()
  T.eq(load('linux').config.enable_kitty_keyboard, true, 'enable_kitty_keyboard')
end)

-- ---------------------------------------------------------------------------
-- WT-KBD-3 macOS — маска IME
-- ---------------------------------------------------------------------------
T.check('WT-KBD-3 инвариант маски: macos_forward_to_ime_modifier_mask = "SHIFT", без CTRL, ALT и SUPER', function()
  T.eq(load('macos').config.macos_forward_to_ime_modifier_mask, 'SHIFT', 'macos_forward_to_ime_modifier_mask')
end)

T.check('WT-KBD-3 привязки Ctrl+Shift+Space и Cmd+C на macOS — по физической клавише (раньше IME)', function()
  for _, p in ipairs({ { 'phys:Space', 'CTRL|SHIFT' }, { 'phys:C', 'SUPER' } }) do
    local b = binding('macos', p[1], p[2])
    T.ok(tostring(b.key):match('^phys:'), ('macos: %s %s задана не через phys: (%s)'):format(p[1], p[2], tostring(b.key)))
  end
end)

-- ---------------------------------------------------------------------------
-- WT-KBD-4 Alt как Meta
-- ---------------------------------------------------------------------------
T.check('WT-KBD-4 Alt как Meta: составной символ не вводится ни левым, ни правым Alt', function()
  for _, os_name in ipairs(OSES) do
    local c = load(os_name).config
    T.eq(c.send_composed_key_when_left_alt_is_pressed, false, os_name .. ': send_composed_key_when_left_alt_is_pressed')
    T.eq(c.send_composed_key_when_right_alt_is_pressed, false, os_name .. ': send_composed_key_when_right_alt_is_pressed')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-KBD-5 CSI-u выключен
-- ---------------------------------------------------------------------------
T.check('WT-KBD-5 устаревшая кодировка CSI-u выключена на всех платформах', function()
  for _, os_name in ipairs(OSES) do
    T.eq(load(os_name).config.enable_csi_u_key_encoding, false, os_name .. ': enable_csi_u_key_encoding')
  end
end)

-- ---------------------------------------------------------------------------
-- WT-KBD-7 Клавиши, которые WezTerm отправляет сам
-- ---------------------------------------------------------------------------
local SEND_F13 = { name = 'SendKey', args = { { key = 'F13' } } }
local SEND_CTRL_C = { name = 'SendKey', args = { { key = 'c', mods = 'CTRL' } } }

T.check('WT-KBD-7 Ctrl+[ — WezTerm шлёт F13 без модификаторов', function()
  for _, os_name in ipairs(OSES) do
    T.eq(binding(os_name, 'phys:LeftBracket', 'CTRL').action, SEND_F13, os_name .. ': действие Ctrl+[')
  end
end)

T.check('WT-KBD-7 Windows: Ctrl+C без выделения — WezTerm шлёт программе Ctrl+C', function()
  local b = binding('windows', 'phys:C', 'CTRL')
  local win = F.window({ selection = '' })
  F.run_callback(b.action, win, F.pane())
  T.eq(win.performed, { SEND_CTRL_C }, 'windows: действия Ctrl+C без выделения')
end)

--- Все клавиши, которые конфиг может отправить программе: SendKey в
--- config.keys и в таблицах режимов (в том числе внутри Multiple и
--- PromptInputLine) и в действиях колбэков, выполненных на поддельном окне с
--- выделением и без. → список { where, key, mods }.
local function sent_keys(res)
  local out = {}
  local visit
  local function run(cb, where)
    for _, sel in ipairs({ '', 'выделение' }) do
      local win = F.window({ selection = sel, effective_config = { font_size = 12 } })
      F.run_callback(cb, win, F.pane(), 'строка')
      for i, a in ipairs(win.performed) do visit(a, ('%s → колбэк(выделение %q)[%d]'):format(where, sel, i)) end
    end
  end
  visit = function(a, where)
    a = F.normalize_action(a)
    if type(a) ~= 'table' then return end
    if a.name == 'SendKey' then
      local k = a.args and a.args[1] or {}
      out[#out + 1] = { where = where, key = k.key, mods = k.mods }
    elseif a.name == 'Multiple' then
      for i, x in ipairs(a.args and a.args[1] or {}) do visit(x, ('%s.Multiple[%d]'):format(where, i)) end
    elseif a.name == 'PromptInputLine' then
      local p = a.args and a.args[1] or {}
      if p.action then visit(p.action, where .. '.PromptInputLine') end
    elseif a.name == 'Callback' then
      run(a, where)
    end
  end
  local c = res.config
  for i, b in ipairs(c.keys) do visit(b.action, ('keys[%d] %s %s'):format(i, b.key, b.mods or 'NONE')) end
  local names = vim.tbl_keys(c.key_tables or {})
  table.sort(names)
  for _, name in ipairs(names) do
    for i, b in ipairs(c.key_tables[name]) do
      visit(b.action, ('key_tables.%s[%d] %s %s'):format(name, i, b.key, b.mods or 'NONE'))
    end
  end
  return out
end

T.check('WT-KBD-7 других клавиш от себя WezTerm не шлёт: F13 везде, Ctrl+C — только на Windows', function()
  for _, os_name in ipairs(OSES) do
    -- Свежая загрузка: колбэки пишут в поддельные файлы и не должны влиять на другие проверки.
    local sent = sent_keys(F.load_config({ triple = F.TRIPLES[os_name] }))
    local got = {}
    for _, s in ipairs(sent) do
      local id = ('%s %s'):format(tostring(s.key), s.mods or 'NONE')
      got[id] = got[id] or {}
      table.insert(got[id], s.where)
    end
    local want = { ['F13 NONE'] = true }
    if os_name == 'windows' then want['c CTRL'] = true end
    local extra, missing = {}, {}
    for id, where in pairs(got) do
      if not want[id] then extra[#extra + 1] = id .. ' ← ' .. table.concat(where, '; ') end
    end
    for id in pairs(want) do
      if not got[id] then missing[#missing + 1] = id end
    end
    table.sort(extra)
    table.sort(missing)
    T.ok(#extra == 0 and #missing == 0, ('%s: лишние %s; нет %s'):format(os_name,
      #extra > 0 and table.concat(extra, ' | ') or '—', #missing > 0 and table.concat(missing, ', ') or '—'))
  end
end)

T.finish()
