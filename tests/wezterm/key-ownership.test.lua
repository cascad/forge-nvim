-- Проверки wezterm-key-ownership (WT-KEYS-*) через подделку wezterm
-- (add-wezterm-spec-checks, задачи 3.2 и 3.3). Характеризация базовой линии
-- (фаза 1): код как есть.
--
-- Часть WezTerm (3.2): WT-KEYS-1, -2, -3, -5, -8 — по config.keys и
-- config.key_tables из подделки для трёх троек.
-- Межслойная часть (3.3): WT-KEYS-4, -6, -7 — сочетания WezTerm сверяются с
-- привязками nvim_forge (tests/lib/nvim_keymaps.lua) в одной записи nvim
-- (tests/lib/keynames.lua).
--
-- ОГРАНИЧЕНИЕ межслойной части (design, решение 6): сторона nvim собрана в
-- headless nvim БЕЗ плагинов — config.ru_keys, config.options, config.keymaps
-- плюс статически прочитанные `keys` спек lazy.nvim. Не видны буферные
-- привязки, привязки из LspAttach и из config-функций плагинов (cmp:
-- <C-Space>, <Tab> в меню дополнения; окна telescope, neo-tree), `keys =
-- function` и то, что ставится в vim.schedule. Пересечение с ними WT-KEYS-7
-- проверяется вручную.
--
-- Вручную (исход зависит от оконной системы и кодировщика клавиш):
-- WT-KEYS-9 целиком; что программа получает на пропущенные сочетания (WT-KBD-6).
--
-- Самопроверки `SELF: keynames …` — перевода сочетаний в запись nvim.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local B = require('bootstrap')
local T = require('check')
local F = require('fake_wezterm')
local KN = require('keynames')
local NK = require('nvim_keymaps')

-- Композиционный корень файла: процесс nvim для стороны nvim_forge и его песочница.
local NVIM = vim.v.progpath
local NVIM_SANDBOX = B.sandbox .. '/nvim'
local RU_KEYS = B.root .. '/nvim_forge/lua/config/ru_keys.lua'

local OSES = { 'windows', 'macos', 'linux' }

local loaded = {}
--- Конфиг для тройки (загружается один раз; проверки его не меняют).
local function cfg(os_name)
  if not loaded[os_name] then loaded[os_name] = F.load_config({ triple = F.TRIPLES[os_name] }).config end
  return loaded[os_name]
end

local function pair_text(b)
  local _, _, id = F.norm_binding(b.key, b.mods)
  return id
end

--- Короткая запись действия для сообщений.
local function action_text(a)
  a = F.normalize_action(a)
  if type(a) ~= 'table' then return tostring(a) end
  if a.name == 'Callback' then return 'Callback(' .. tostring(a.event) .. ')' end
  if a.args == nil then return a.name end
  return a.name .. vim.inspect(a.args, { newline = ' ', indent = '' })
end

-- WT-KEYS-10: подмены сочетаний nvim_forge — только Windows, колбэк.
local KEYS10 = {
  { 'phys:F', 'CTRL|SHIFT', 'Ctrl+Shift+F' }, { 'phys:P', 'CTRL|SHIFT', 'Ctrl+Shift+P' },
  { 'phys:E', 'CTRL|SHIFT', 'Ctrl+Shift+E' }, { 'phys:D', 'CTRL|SHIFT', 'Ctrl+Shift+D' },
  { 'F5', 'CTRL|SHIFT', 'Ctrl+Shift+F5' }, { 'phys:Period', 'CTRL', 'Ctrl+.' },
  { 'Enter', 'CTRL', 'Ctrl+Enter' }, { 'phys:Slash', 'CTRL', 'Ctrl+/' }, { 'phys:Space', 'CTRL', 'Ctrl+Space' },
}
local KEYS10_LHS = { '<C-S-f>', '<C-S-p>', '<C-S-e>', '<C-S-d>', '<C-S-F5>', '<C-.>', '<C-CR>', '<C-/>', '<C-Space>' }
local KEYS10_CANON = {}
for _, lhs in ipairs(KEYS10_LHS) do KEYS10_CANON[KN.canon(lhs)] = true end

--- Сочетания nvim_forge без подмен WT-KEYS-10 на Windows: их WezTerm
--- перехватывает, но отдаёт nvim_forge подменной клавишей (или программе —
--- исходным нажатием), а это не «перехват у nvim».
local function without_keys10(os_name, list)
  if os_name ~= 'windows' then return list end
  return vim.tbl_filter(function(lhs) return not KEYS10_CANON[KN.canon(lhs)] end, list)
end

local function binding(os_name, key, mods)
  local b, _, count = F.find_binding(cfg(os_name).keys, key, mods)
  T.ok(b, ('%s: нет привязки %s %s'):format(os_name, key, mods or 'NONE'))
  T.eq(count, 1, ('%s: %s %s — записей'):format(os_name, key, mods or 'NONE'))
  return b
end

--- Перехваты вне режимов в записи nvim: каноническая клавиша → { привязки }.
local function intercepts(os_name)
  local out = {}
  for i, b in ipairs(cfg(os_name).keys) do
    local k, err = KN.from_wezterm(b.key, b.mods)
    T.ok(k, ('%s: keys[%d] %s %s не переводится в запись nvim: %s'):format(os_name, i, tostring(b.key),
      tostring(b.mods), tostring(err)))
    out[k] = out[k] or {}
    table.insert(out[k], b)
  end
  return out
end

--- Какие из сочетаний (запись nvim) WezTerm перехватывает на тройке.
local function intercepted_of(os_name, lhs_list)
  local W, hit = intercepts(os_name), {}
  for _, lhs in ipairs(lhs_list) do
    local c = KN.canon(lhs)
    if W[c] then
      local pairs_ = {}
      for _, b in ipairs(W[c]) do pairs_[#pairs_ + 1] = pair_text(b) .. ' → ' .. action_text(b.action) end
      hit[#hit + 1] = ('%s (%s)'):format(lhs, table.concat(pairs_, '; '))
    end
  end
  return hit
end

-- ===========================================================================
-- SELF: keynames — перевод сочетаний WezTerm в запись nvim
-- ===========================================================================
T.check('SELF: keynames переводит phys:, именованные клавиши и модификаторы в запись nvim', function()
  local cases = {
    { 'phys:F', 'CTRL|SHIFT', '<C-S-f>' },
    { 'phys:LeftBracket', 'CTRL', '<C-[>' },
    { 'phys:2', 'SHIFT|CTRL', '<C-S-2>' },
    { 'phys:Equal', 'SUPER', '<D-=>' },
    { 'phys:Space', 'CTRL|SHIFT', '<C-S-Space>' },
    { 'phys:Delete', 'CTRL|SHIFT', '<C-S-Del>' },
    { 'phys:Backslash', 'CTRL', '<C-Bslash>' },
    { 'Enter', 'CTRL|SHIFT|ALT', '<C-S-A-CR>' },
    { 'Return', nil, '<CR>' },
    { 'Tab', 'CTRL', '<C-Tab>' },
    { 'Insert', 'SHIFT', '<S-Insert>' },
    { 'PageUp', 'NONE', '<PageUp>' },
    { 'LeftArrow', 'CTRL|SHIFT', '<C-S-Left>' },
    { 'F5', 'CTRL|SHIFT', '<C-S-F5>' },
    { 'phys:L', 'CMD|OPT', '<A-D-l>' },
    { 'phys:Comma', '', ',' },
    { 'mapped: ', 'NONE', '<Space>' },
    { 'x', 'CTRL', '<C-x>' },
  }
  for _, c in ipairs(cases) do
    T.eq(KN.wezterm_lhs(c[1], c[2]), c[3], ('wezterm_lhs(%q, %s)'):format(c[1], tostring(c[2])))
  end
  T.eq({ KN.wezterm_lhs('phys:Nope', 'CTRL') }, { nil, 'неизвестная физическая клавиша phys:Nope' })
  T.eq({ KN.wezterm_lhs('phys:A', 'HYPER') }, { nil, 'неизвестный модификатор HYPER' })
end)

T.check('SELF: keynames.canon — запись таблицы привязок nvim, без упрощения до другой клавиши', function()
  local cases = {
    { '<C-S-f>', '<C-S-F>' }, { '<C-S-F>', '<C-S-F>' }, { '<C-v>', '<C-V>' }, { '<C-V>', '<C-V>' },
    { '<D-A-l>', '<M-D-l>' }, { '<A-D-l>', '<M-D-l>' }, { '<A-CR>', '<M-CR>' },
    -- Разные клавиши остаются разными (vim.keycode слил бы их: <Esc>, <S-NL>, <NL>).
    { '<C-[>', '<C-[>' }, { '<Esc>', '<Esc>' }, { '<C-S-j>', '<C-S-J>' }, { '<C-j>', '<C-J>' },
    { '<C-S-2>', '<C-S-2>' }, { '<S-D-s>', '<D-S>' }, { '<C-S-F5>', '<C-S-F5>' },
  }
  for _, c in ipairs(cases) do T.eq(KN.canon(c[1]), c[2], ('canon(%q)'):format(c[1])) end
  T.ok(KN.canon('<C-[>') ~= KN.canon('<Esc>'), 'Ctrl+[ и Esc слились')
  T.ok(KN.canon('<C-S-j>') ~= KN.canon('<S-NL>'), 'Ctrl+Shift+J и Shift+NL слились')
end)

T.check('SELF: keynames.split делит каноническую запись на клавиши', function()
  T.eq(KN.split(KN.canon('g<C-v>')), { 'g', '<C-V>' })
  T.eq(KN.split(KN.canon('<lt>x')), { '<lt>', 'x' })
  T.eq(KN.split(KN.canon('<C-S-а>ё')), { '<C-S-а>', 'ё' })
  T.eq(KN.split('<Esc><Esc>'), { '<Esc>', '<Esc>' })
  T.eq(KN.from_wezterm('phys:F', 'SHIFT|CTRL'), KN.canon('<C-S-f>'))
end)

-- ===========================================================================
-- WT-KEYS-1 Встроенные привязки клавиш WezTerm отключены
-- ===========================================================================
T.check('WT-KEYS-1 встроенные привязки клавиш выключены, привязки мыши — встроенные', function()
  for _, os_name in ipairs(OSES) do
    local c = cfg(os_name)
    T.eq(c.disable_default_key_bindings, true, os_name .. ': disable_default_key_bindings')
    T.ok(c.disable_default_mouse_bindings ~= true, os_name .. ': disable_default_mouse_bindings = true')
    T.eq(c.mouse_bindings, nil, os_name .. ': mouse_bindings')
  end
end)

T.check('WT-KEYS-1 встроенные сочетания без явной привязки уходят в программу (на Windows Ctrl+Shift+F/P — подмена WT-KEYS-10)', function()
  for _, os_name in ipairs(OSES) do
    local hit = intercepted_of(os_name, without_keys10(os_name, { '<C-S-f>', '<C-S-p>', '<C-PageUp>', '<C-PageDown>', '<A-CR>' }))
    T.eq(hit, {}, os_name .. ': перехвачены')
  end
end)

T.check('WT-KEYS-1 Ctrl+Shift+K и Ctrl+Shift+L — фокус на панель выше и правее', function()
  for _, os_name in ipairs(OSES) do
    T.eq(binding(os_name, 'phys:K', 'CTRL|SHIFT').action, { name = 'ActivatePaneDirection', args = { 'Up' } },
      os_name .. ': Ctrl+Shift+K')
    T.eq(binding(os_name, 'phys:L', 'CTRL|SHIFT').action, { name = 'ActivatePaneDirection', args = { 'Right' } },
      os_name .. ': Ctrl+Shift+L')
  end
end)

T.check('WT-KEYS-1 встроенных Cmd-сочетаний на macOS нет: Cmd+W, Cmd+K, Cmd+F, Cmd+1', function()
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    T.eq(intercepted_of(os_name, { '<D-w>', '<D-k>', '<D-f>', '<D-1>' }), {}, os_name .. ': перехвачены')
  end
end)

-- ===========================================================================
-- WT-KEYS-2 Привязки по физической позиции клавиши
-- ===========================================================================

-- Именованные клавиши требования (Enter, Tab, Esc, Space, Insert, Delete,
-- PageUp/PageDown, Home/End, стрелки) в каноническом имени подделки
-- (F.norm_key): 'mapped: ' — символ пробела, show-keys печатает его «Space».
local NAMED = {
  Enter = true, Tab = true, Escape = true, ['mapped: '] = true, Insert = true, Delete = true,
  PageUp = true, PageDown = true, Home = true, End = true, F5 = true,
  LeftArrow = true, RightArrow = true, UpArrow = true, DownArrow = true,
}

T.check('WT-KEYS-2 буквы, цифры и знаки — только phys:, остальное — именованные клавиши (keys и все таблицы режимов)', function()
  local bad = {}
  for _, os_name in ipairs(OSES) do
    local c = cfg(os_name)
    local lists = { { 'keys', c.keys } }
    local names = vim.tbl_keys(c.key_tables or {})
    table.sort(names)
    for _, name in ipairs(names) do lists[#lists + 1] = { 'key_tables.' .. name, c.key_tables[name] } end
    for _, l in ipairs(lists) do
      for i, b in ipairs(l[2]) do
        local k = F.norm_key(b.key)
        if not k:match('^phys:') and not NAMED[k] then
          bad[#bad + 1] = ('%s %s[%d] %s %s'):format(os_name, l[1], i, tostring(b.key), b.mods or 'NONE')
        end
      end
    end
  end
  T.eq(bad, {}, 'привязки не по phys: и не именованной клавишей')
end)

T.check('WT-KEYS-2 Ctrl+Shift+2 — вторая вкладка по позиции клавиши', function()
  for _, os_name in ipairs(OSES) do
    T.eq(binding(os_name, 'phys:2', 'CTRL|SHIFT').action, { name = 'ActivateTab', args = { 1 } }, os_name)
  end
end)

T.check('WT-KEYS-2 Ctrl+[ и Ctrl+C (Windows) — по позиции клавиши', function()
  for _, os_name in ipairs(OSES) do binding(os_name, 'phys:LeftBracket', 'CTRL') end
  binding('windows', 'phys:C', 'CTRL')
end)

T.check('WT-KEYS-2 Cmd+C и Cmd+V на macOS — по позиции клавиши', function()
  T.eq(binding('macos', 'phys:C', 'SUPER').action.name, 'Callback', 'Cmd+C')
  T.eq(binding('macos', 'phys:V', 'SUPER').action, { name = 'PasteFrom', args = { 'Clipboard' } }, 'Cmd+V')
end)

-- ===========================================================================
-- WT-KEYS-3 Полный набор перехватов вне режимов
-- ===========================================================================

-- Таблица требования: { платформы, клавиша, модификаторы, действие, сочетание }.
-- Платформы: 'both' — Windows и macOS, 'win' — только Windows, 'mac' — только
-- macOS (Super-сочетания шрифта — тоже 'mac': на Windows их нет, WT-KEYS-3). Linux получает набор macOS (Purpose спеки). Действие — вид действия
-- WezTerm; смысл каждого проверяет свой ID (колонка «Где описано»).
local TABLE = {
  { 'win', 'phys:C', 'CTRL', 'Callback', 'Ctrl+C' },
  { 'both', 'phys:V', 'CTRL', 'PasteFrom', 'Ctrl+V' },
  { 'both', 'phys:V', 'CTRL|SHIFT', 'PasteFrom', 'Ctrl+Shift+V' },
  { 'both', 'Insert', 'SHIFT', 'PasteFrom', 'Shift+Insert' },
  { 'both', 'phys:C', 'CTRL|SHIFT', 'Callback', 'Ctrl+Shift+C' },
  { 'both', 'Insert', 'CTRL', 'Callback', 'Ctrl+Insert' },
  { 'mac', 'phys:C', 'SUPER', 'Callback', 'Cmd+C' },
  { 'mac', 'phys:V', 'SUPER', 'PasteFrom', 'Cmd+V' },
  { 'both', 'phys:S', 'CTRL|SHIFT', 'Callback', 'Ctrl+Shift+S' },
  { 'mac', 'phys:S', 'SUPER|SHIFT', 'Callback', 'Cmd+Shift+S' },
  { 'both', 'phys:Equal', 'CTRL', 'Callback', 'Ctrl+=' },
  { 'both', 'phys:Equal', 'CTRL|SHIFT', 'Callback', 'Ctrl+Shift+=' },
  { 'mac', 'phys:Equal', 'SUPER', 'Callback', 'Super+=' },
  { 'mac', 'phys:Equal', 'SUPER|SHIFT', 'Callback', 'Super+Shift+=' },
  { 'both', 'phys:Minus', 'CTRL', 'Callback', 'Ctrl+-' },
  { 'both', 'phys:Minus', 'CTRL|SHIFT', 'Callback', 'Ctrl+Shift+-' },
  { 'mac', 'phys:Minus', 'SUPER', 'Callback', 'Super+-' },
  { 'mac', 'phys:Minus', 'SUPER|SHIFT', 'Callback', 'Super+Shift+-' },
  { 'both', 'phys:0', 'CTRL', 'Callback', 'Ctrl+0' },
  { 'both', 'phys:0', 'CTRL|SHIFT', 'Callback', 'Ctrl+Shift+0' },
  { 'mac', 'phys:0', 'SUPER', 'Callback', 'Super+0' },
  { 'mac', 'phys:0', 'SUPER|SHIFT', 'Callback', 'Super+Shift+0' },
  { 'both', 'phys:LeftBracket', 'CTRL', 'SendKey', 'Ctrl+[' },
  { 'both', 'phys:Space', 'CTRL|SHIFT', 'ActivateKeyTable', 'Ctrl+Shift+Space' },
  { 'both', 'Enter', 'CTRL|SHIFT', 'SplitPane', 'Ctrl+Shift+Enter' },
  { 'both', 'Enter', 'CTRL|SHIFT|ALT', 'SplitPane', 'Ctrl+Shift+Alt+Enter' },
  { 'both', 'phys:H', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+H' },
  { 'both', 'phys:J', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+J' },
  { 'both', 'phys:K', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+K' },
  { 'both', 'phys:L', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+L' },
  { 'both', 'LeftArrow', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+←' },
  { 'both', 'DownArrow', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+↓' },
  { 'both', 'UpArrow', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+↑' },
  { 'both', 'RightArrow', 'CTRL|SHIFT', 'ActivatePaneDirection', 'Ctrl+Shift+→' },
  { 'both', 'phys:Z', 'CTRL|SHIFT', 'TogglePaneZoomState', 'Ctrl+Shift+Z' },
  { 'both', 'phys:W', 'CTRL|SHIFT', 'CloseCurrentPane', 'Ctrl+Shift+W' },
  { 'both', 'phys:T', 'CTRL|SHIFT', 'SpawnTab', 'Ctrl+Shift+T' },
  { 'mac', 'phys:T', 'SUPER', 'SpawnTab', 'Cmd+T' },
  { 'both', 'Tab', 'CTRL', 'ActivateTabRelative', 'Ctrl+Tab' },
  { 'both', 'PageDown', 'CTRL|SHIFT', 'ActivateTabRelative', 'Ctrl+Shift+PageDown' },
  { 'both', 'Tab', 'CTRL|SHIFT', 'ActivateTabRelative', 'Ctrl+Shift+Tab' },
  { 'both', 'PageUp', 'CTRL|SHIFT', 'ActivateTabRelative', 'Ctrl+Shift+PageUp' },
  { 'both', 'phys:N', 'CTRL|SHIFT', 'SpawnWindow', 'Ctrl+Shift+N' },
  { 'mac', 'phys:N', 'SUPER', 'SpawnWindow', 'Cmd+N' },
  { 'both', 'phys:X', 'CTRL|SHIFT', 'ActivateCopyMode', 'Ctrl+Shift+X' },
  { 'both', 'phys:U', 'CTRL|SHIFT', 'QuickSelect', 'Ctrl+Shift+U' },
  { 'both', 'phys:Delete', 'CTRL|SHIFT', 'ClearScrollback', 'Ctrl+Shift+Delete' },
  { 'both', 'PageUp', 'SHIFT', 'ScrollByPage', 'Shift+PageUp' },
  { 'both', 'PageDown', 'SHIFT', 'ScrollByPage', 'Shift+PageDown' },
  { 'both', 'phys:R', 'CTRL|SHIFT', 'ReloadConfiguration', 'Ctrl+Shift+R' },
  { 'mac', 'phys:H', 'SUPER', 'HideApplication', 'Cmd+H' },
  { 'mac', 'phys:M', 'SUPER', 'Hide', 'Cmd+M' },
  { 'mac', 'phys:Q', 'SUPER', 'QuitApplication', 'Cmd+Q' },
}
for i = 1, 9 do
  table.insert(TABLE, { 'both', 'phys:' .. i, 'CTRL|SHIFT', 'ActivateTab', 'Ctrl+Shift+' .. i })
end
for _, k in ipairs(KEYS10) do
  table.insert(TABLE, { 'win', k[1], k[2], 'Callback', k[3] })
end

local PLATFORM_ROWS = { windows = { both = true, win = true }, macos = { both = true, mac = true },
  linux = { both = true, mac = true } }
local TABLE_COUNT = { windows = 48 + #KEYS10, macos = 61, linux = 61 }

T.check('WT-KEYS-3 таблица требования: 48 перехватов на Windows плюс 9 подмен WT-KEYS-10, 61 на macOS, остальные платформы — как macOS', function()
  local n = { windows = 0, macos = 0, linux = 0 }
  for _, row in ipairs(TABLE) do
    for os_name, rows in pairs(PLATFORM_ROWS) do
      if rows[row[1]] then n[os_name] = n[os_name] + 1 end
    end
  end
  T.eq(n, TABLE_COUNT, 'строк таблицы на платформу (самопроверка данных теста)')
end)

for _, os_name in ipairs(OSES) do
  T.check(('WT-KEYS-3 перехваты вне режимов на %s — ровно таблица требования (%d)'):format(os_name,
    TABLE_COUNT[os_name]), function()
    local want = {}
    for _, row in ipairs(TABLE) do
      if PLATFORM_ROWS[os_name][row[1]] then
        local _, _, id = F.norm_binding(row[2], row[3])
        want[id] = { action = row[4], label = row[5] }
      end
    end
    local got = {}
    for _, b in ipairs(cfg(os_name).keys) do
      got[pair_text(b)] = F.normalize_action(b.action).name
    end
    local missing, extra, wrong = {}, {}, {}
    for id, w in pairs(want) do
      if got[id] == nil then
        missing[#missing + 1] = w.label .. ' (' .. id .. ')'
      elseif got[id] ~= w.action then
        wrong[#wrong + 1] = ('%s (%s): %s, ожидалось %s'):format(w.label, id, got[id], w.action)
      end
    end
    for id, name in pairs(got) do
      if not want[id] then extra[#extra + 1] = id .. ' → ' .. name end
    end
    table.sort(missing)
    table.sort(extra)
    table.sort(wrong)
    T.eq({ missing = missing, extra = extra, wrong_action = wrong }, { missing = {}, extra = {}, wrong_action = {} },
      os_name)
    T.eq(#cfg(os_name).keys, TABLE_COUNT[os_name], os_name .. ': записей в config.keys')
  end)
end

T.check('WT-KEYS-3 клавиша без модификатора не перехватывается; с одним Shift — только PageUp, PageDown, Insert', function()
  for _, os_name in ipairs(OSES) do
    local bare, shift = {}, {}
    for _, b in ipairs(cfg(os_name).keys) do
      local k, m = F.norm_binding(b.key, b.mods)
      if m == 'NONE' then bare[#bare + 1] = k end
      if m == 'SHIFT' then shift[#shift + 1] = k end
    end
    table.sort(shift)
    T.eq(bare, {}, os_name .. ': без модификатора')
    T.eq(shift, { 'Insert', 'PageDown', 'PageUp' }, os_name .. ': с одним Shift')
  end
end)

T.check('WT-KEYS-3 сочетаний вне таблицы нет: Ctrl+Shift+B, Ctrl+Shift+Y, Alt+Enter, Ctrl+B', function()
  for _, os_name in ipairs(OSES) do
    T.eq(intercepted_of(os_name, { '<C-S-b>', '<C-S-y>', '<A-CR>', '<C-b>' }), {}, os_name .. ': перехвачены')
  end
end)

T.check('WT-KEYS-3 Ctrl+C на macOS не перехватывается', function()
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    T.eq(intercepted_of(os_name, { '<C-c>' }), {}, os_name .. ': перехвачены')
  end
end)

T.check('WT-KEYS-3 Win+Shift+S на Windows не перехватывается', function()
  T.eq(intercepted_of('windows', { '<D-S-s>' }), {}, 'windows: перехвачены')
end)

T.check('WT-KEYS-3 Super-сочетания шрифта только вне Windows: на Windows ни одной пары с SUPER', function()
  for _, b in ipairs(cfg('windows').keys) do
    T.ok(not tostring(b.mods or ''):find('SUPER', 1, true),
      ('windows: %s %s — пара с SUPER'):format(tostring(b.key), tostring(b.mods)))
  end
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    for _, key in ipairs({ 'phys:Equal', 'phys:Minus', 'phys:0' }) do
      for _, mods in ipairs({ 'SUPER', 'SUPER|SHIFT' }) do
        T.eq(binding(os_name, key, mods).action.name, 'Callback', ('%s: %s %s'):format(os_name, key, mods))
      end
    end
  end
end)

-- ===========================================================================
-- WT-KEYS-5 Ctrl+Tab и Ctrl+Shift+Tab принадлежат WezTerm
-- ===========================================================================
T.check('WT-KEYS-5 Ctrl+Tab — следующая вкладка, Ctrl+Shift+Tab — предыдущая, клавиша именованная', function()
  for _, os_name in ipairs(OSES) do
    local next_ = binding(os_name, 'Tab', 'CTRL')
    local prev = binding(os_name, 'Tab', 'CTRL|SHIFT')
    T.eq(next_.action, { name = 'ActivateTabRelative', args = { 1 } }, os_name .. ': Ctrl+Tab')
    T.eq(prev.action, { name = 'ActivateTabRelative', args = { -1 } }, os_name .. ': Ctrl+Shift+Tab')
    T.eq({ F.norm_key(next_.key), F.norm_key(prev.key) }, { 'Tab', 'Tab' }, os_name .. ': клавиша')
  end
end)

T.check('WT-KEYS-5 голые Tab и Shift+Tab не перехватываются', function()
  for _, os_name in ipairs(OSES) do
    T.eq(intercepted_of(os_name, { '<Tab>', '<S-Tab>' }), {}, os_name .. ': перехвачены')
  end
end)

-- ===========================================================================
-- WT-KEYS-8 У каждого сочетания одно действие (design, решение 5)
-- ===========================================================================

--- Повторы пар (клавиша, модификаторы) в списке: { id, n, same } по id.
--- same — у всех записей пары структурно одно действие (колбэки — по идентичности).
local function duplicates(list)
  local by, order = {}, {}
  for _, b in ipairs(list) do
    local id = pair_text(b)
    if not by[id] then by[id] = {}; order[#order + 1] = id end
    table.insert(by[id], F.normalize_action(b.action))
  end
  local out = {}
  for _, id in ipairs(order) do
    local acts = by[id]
    if #acts > 1 then
      local same = true
      for i = 2, #acts do same = same and T.equal(acts[i], acts[1]) end
      local texts = {}
      for _, a in ipairs(acts) do texts[#texts + 1] = action_text(a) end
      out[#out + 1] = { id = id, n = #acts, same = same, actions = texts }
    end
  end
  return out
end

T.check('WT-KEYS-8 в config.keys и таблицах режимов, кроме copy_mode, каждая пара встречается один раз', function()
  local bad = {}
  for _, os_name in ipairs(OSES) do
    local c = cfg(os_name)
    local lists = { { 'keys', c.keys } }
    local names = vim.tbl_keys(c.key_tables or {})
    table.sort(names)
    for _, name in ipairs(names) do
      if name ~= 'copy_mode' then lists[#lists + 1] = { 'key_tables.' .. name, c.key_tables[name] } end
    end
    for _, l in ipairs(lists) do
      for _, d in ipairs(duplicates(l[2])) do
        bad[#bad + 1] = ('%s %s: пара %s ×%d — %s'):format(os_name, l[1], d.id, d.n, table.concat(d.actions, ' | '))
      end
    end
  end
  T.ok(#bad == 0, 'повторы пар:\n' .. table.concat(bad, '\n'))
end)

T.check('WT-KEYS-8 в copy_mode повторы только с тем же действием, их 10', function()
  for _, os_name in ipairs(OSES) do
    local dups = duplicates(cfg(os_name).key_tables.copy_mode)
    local diff, ids = {}, {}
    for _, d in ipairs(dups) do
      ids[#ids + 1] = d.id
      if not d.same or d.n ~= 2 then
        diff[#diff + 1] = ('пара %s ×%d — %s'):format(d.id, d.n, table.concat(d.actions, ' | '))
      end
    end
    T.ok(#diff == 0, os_name .. ' key_tables.copy_mode: повторы с разными действиями:\n' .. table.concat(diff, '\n'))
    T.eq(#dups, 10, os_name .. ' key_tables.copy_mode: пар, записанных дважды (' .. table.concat(ids, ', ') .. ')')
    -- Сценарий требования: Shift+G записан во встроенной таблице в двух формах.
    T.ok(vim.tbl_contains(ids, 'phys:G SHIFT'), os_name .. ' key_tables.copy_mode: Shift+G не среди повторов')
  end
end)

-- ===========================================================================
-- Межслойная часть: WT-KEYS-4, WT-KEYS-6, WT-KEYS-7 (design, решение 6)
-- ===========================================================================

local side_cache, side_error
--- Привязки nvim_forge (один процесс nvim на файл). Процесс не собрался, что-то
--- из nvim_forge не загрузилось или stdpath вне песочницы — error: проверки,
--- которые на них опираются, падают, а не проходят на неполных данных.
local function collect_side()
  local s = NK.collect({ root = B.root, sandbox = NVIM_SANDBOX, nvim = NVIM })
  if #s.errors > 0 then error('nvim_forge без плагинов загрузился с ошибками:\n' .. table.concat(s.errors, '\n'), 0) end
  if s.errmsg ~= '' then error('v:errmsg после загрузки nvim_forge: ' .. s.errmsg, 0) end
  local sb = vim.fs.normalize(NVIM_SANDBOX):lower()
  for name, p in pairs(s.stdpath) do
    if vim.fs.normalize(p):lower():sub(1, #sb) ~= sb then
      error(('stdpath(%q) процесса nvim вне песочницы: %s'):format(name, p), 0)
    end
  end
  -- Все привязки nvim_forge одной записью: { lhs, keys, modes, source }.
  s.all = {}
  for _, m in ipairs(s.maps) do
    s.all[#s.all + 1] = { lhs = m.lhs, keys = m.keys, modes = { m.mode }, source = 'config.keymaps' }
  end
  for _, k in ipairs(s.lazy) do
    s.all[#s.all + 1] = { lhs = k.canon, keys = k.keys, modes = k.modes, source = k.file }
  end
  return s
end

local function nvim_side()
  if side_cache then return side_cache end
  if side_error then error(side_error, 0) end
  local ok, s = pcall(collect_side)
  if not ok then
    side_error = tostring(s)
    error(side_error, 0)
  end
  side_cache = s
  return s
end

--- Клавиши (каноническая запись), которые есть в привязках nvim_forge →
--- { 'режим lhs (источник)', … }.
local function forge_keys()
  local out = {}
  for _, m in ipairs(nvim_side().all) do
    for _, k in ipairs(m.keys) do
      out[k] = out[k] or {}
      table.insert(out[k], ('%s %s (%s)'):format(table.concat(m.modes, ','), m.lhs, m.source))
    end
  end
  return out
end

-- ru_keys nvim_forge ставит к каждой привязке псевдоним на русской раскладке
-- (<D-A-l> → <D-A-д>): это та же физическая клавиша, WezTerm (phys:) её не
-- различает. Функция перевода берётся из самого nvim_forge.
local function with_ru_aliases(lhs_list)
  local ru = dofile(RU_KEYS)
  local out = {}
  for _, lhs in ipairs(lhs_list) do
    out[KN.canon(lhs)] = lhs
    local alias = ru.translate_lhs(lhs)
    if alias then out[KN.canon(alias)] = lhs .. ' (псевдоним ru_keys)' end
  end
  return out
end

-- WT-KEYS-4: сочетания, оставленные nvim (текст требования), в записи nvim.
local KEYS4_ALL = {
  '<C-S-f>', '<C-S-p>', '<C-S-e>', '<C-S-d>', '<C-S-F5>', '<C-PageUp>', '<C-PageDown>', '<A-CR>',
  '<C-.>', '<C-CR>', '<C-/>', '<C-Space>', '<Tab>', '<S-Tab>', '<Esc>', '<C-b>', '<C-j>',
}
local KEYS4_MAC = { '<D-A-l>' }
-- Из них без плагинов не видно (ограничение в шапке файла): где на самом деле.
local KEYS4_INVISIBLE = { ['<C-Space>'] = 'cmp, config-функция плагина (nvim_forge/lua/plugins/completion.lua)' }

for _, os_name in ipairs(OSES) do
  T.check('WT-KEYS-4 сочетания, оставленные nvim, WezTerm не перехватывает на ' .. os_name, function()
    local list = vim.deepcopy(KEYS4_ALL)
    if os_name ~= 'windows' then vim.list_extend(list, KEYS4_MAC) end
    T.eq(intercepted_of(os_name, without_keys10(os_name, list)), {}, os_name .. ': перехвачены')
  end)
end

T.check('WT-KEYS-4 эти сочетания есть в привязках nvim_forge (кроме невидимых без плагинов)', function()
  local have, missing = forge_keys(), {}
  for _, lhs in ipairs(vim.list_extend(vim.deepcopy(KEYS4_ALL), KEYS4_MAC)) do
    if not KEYS4_INVISIBLE[lhs] and not have[KN.canon(lhs)] then missing[#missing + 1] = lhs end
  end
  T.eq(missing, {}, 'нет в привязках nvim_forge')
end)

T.check('WT-KEYS-4 Alt+клавиша без Ctrl, F1–F12 и Ctrl+буква (кроме Ctrl+V и Ctrl+C на Windows) не перехватываются', function()
  for _, os_name in ipairs(OSES) do
    local alt, fkeys, ctrl_letters = {}, {}, {}
    for _, b in ipairs(cfg(os_name).keys) do
      local k, m = F.norm_binding(b.key, b.mods)
      local mods = {}
      for part in m:gmatch('[^|]+') do mods[part] = true end
      if mods.ALT and not mods.CTRL then alt[#alt + 1] = k .. ' ' .. m end
      local fn = tonumber(k:match('^phys:F(%d+)$') or k:match('^F(%d+)$'))
      local subst = os_name == 'windows' and k == 'F5' and m == 'CTRL|SHIFT'  -- подмена WT-KEYS-10
      if fn and fn >= 1 and fn <= 12 and not subst then fkeys[#fkeys + 1] = k .. ' ' .. m end
      local letter = k:match('^phys:(%u)$') or k:match('^mapped:(%a)$')
      if m == 'CTRL' and letter then ctrl_letters[#ctrl_letters + 1] = letter:upper() end
    end
    table.sort(ctrl_letters)
    T.eq(alt, {}, os_name .. ': Alt без Ctrl')
    T.eq(fkeys, {}, os_name .. ': F1–F12')
    T.eq(ctrl_letters, os_name == 'windows' and { 'C', 'V' } or { 'V' }, os_name .. ': Ctrl+буква')
  end
end)

T.check('WT-KEYS-6 Ctrl+[ — WezTerm шлёт F13, клавишу Esc не перехватывает', function()
  for _, os_name in ipairs(OSES) do
    T.eq(binding(os_name, 'phys:LeftBracket', 'CTRL').action, { name = 'SendKey', args = { { key = 'F13' } } },
      os_name .. ': Ctrl+[')
    local esc = {}
    for _, b in ipairs(cfg(os_name).keys) do
      if F.norm_key(b.key) == 'Escape' or F.norm_key(b.key) == 'phys:Escape' then esc[#esc + 1] = pair_text(b) end
    end
    T.eq(esc, {}, os_name .. ': привязки на Esc')
  end
end)

T.check('WT-KEYS-6 <F13> привязан в nvim_forge в режимах n, i и x', function()
  local modes = {}
  for _, m in ipairs(nvim_side().maps) do
    if m.lhs == KN.canon('<F13>') then modes[m.mode] = true end
  end
  T.eq({ n = modes.n, i = modes.i, x = modes.x }, { n = true, i = true, x = true }, 'режимы <F13>')
end)

-- WT-KEYS-7: единственное исключение требования — Ctrl+C на Windows (без
-- выделения WezTerm отдаёт его nvim). Ctrl+V принадлежит WezTerm везде, у
-- nvim_forge привязок <C-v> нет (resolve-key-ownership-conflicts, решение 1).
-- Ctrl+[ сравнивается как <C-[> — отдельно от <Esc> (KN.canon): до nvim он
-- доходит как F13, и <F13> nvim_forge — его намеренная привязка (WT-KEYS-6).
local KEYS7_EXCEPTIONS = {
  windows = { '<C-c>' },
  macos = {},
  linux = {},
}
-- Подмены WT-KEYS-10 — не пересечение: WezTerm отдаёт эти сочетания
-- nvim_forge подменными клавишами (список — из таблицы WT-KEYS-10).
for _, lhs in ipairs(KEYS10_LHS) do table.insert(KEYS7_EXCEPTIONS.windows, lhs) end

for _, os_name in ipairs(OSES) do
  T.check('WT-KEYS-7 пересечение перехватов WezTerm с привязками nvim_forge на ' .. os_name
    .. ' — только исключения требования', function()
    local W, have = intercepts(os_name), forge_keys()
    local got, detail = {}, {}
    for k, bs in pairs(W) do
      if have[k] then
        got[#got + 1] = k
        local p = {}
        for _, b in ipairs(bs) do p[#p + 1] = pair_text(b) end
        detail[#detail + 1] = ('%s: WezTerm %s; nvim_forge %s'):format(k, table.concat(p, ', '), table.concat(have[k], '; '))
      end
    end
    local want = {}
    for _, lhs in ipairs(KEYS7_EXCEPTIONS[os_name]) do want[#want + 1] = KN.canon(lhs) end
    table.sort(got)
    table.sort(want)
    table.sort(detail)
    -- Пересечение — только исключения; <C-c> на Windows — обязательно. Подмены
    -- WT-KEYS-10 из config-функций плагинов (<C-Space>) без плагинов не видны.
    local allowed, extra = {}, {}
    for _, k in ipairs(want) do allowed[k] = true end
    for _, k in ipairs(got) do if not allowed[k] then extra[#extra + 1] = k end end
    T.ok(#extra == 0, ('%s: лишнее пересечение %s\n%s'):format(os_name, table.concat(extra, ' '),
      table.concat(detail, '\n')))
    if os_name == 'windows' then
      T.ok(vim.tbl_contains(got, KN.canon('<C-c>')), 'windows: Ctrl+C не делится с визуальной привязкой <C-c>')
    end
  end)
end

T.check('WT-KEYS-7 Ctrl+V в nvim: у nvim_forge нет <C-v> ни в одном режиме (n, v, x, s, i, c); <C-c> — визуальная привязка', function()
  local v_modes, c_modes = {}, {}
  for _, m in ipairs(nvim_side().maps) do
    if m.lhs == KN.canon('<C-v>') then v_modes[#v_modes + 1] = m.mode end
    if m.lhs == KN.canon('<C-c>') then c_modes[m.mode] = true end
  end
  table.sort(v_modes)
  T.eq(v_modes, {}, 'режимы с привязкой <C-v>')
  T.eq(c_modes.x, true, '<C-c> в визуальном режиме')
end)

T.check('WT-KEYS-7 сверка наборов: Ctrl+[ сравнивается как <C-[>, а не как <Esc>', function()
  T.ok(KN.canon('<C-[>') ~= KN.canon('<Esc>'), 'Ctrl+[ и Esc слились')
end)

T.check('WT-KEYS-7 из <C-S-…> nvim_forge использует только F, P, E, D, F5 (и подменную <C-S-F13>), из <D-…> — только <D-A-l>; WezTerm их не перехватывает, кроме подмены WT-KEYS-10 на Windows', function()
  -- <C-S-F13> — подменная клавиша Ctrl+Space (WT-KEYS-10): её шлёт WezTerm, физически её нет.
  local cs_allowed = with_ru_aliases({ '<C-S-f>', '<C-S-p>', '<C-S-e>', '<C-S-d>', '<C-S-F5>', '<C-S-F13>' })
  local d_allowed = with_ru_aliases({ '<D-A-l>' })
  local have = forge_keys()
  local cs, d, extra = {}, {}, {}
  for k, where in pairs(have) do
    local mods = k:match('^<([%u%-]+)%-.+>$') or ''
    local set = {}
    for letter in mods:gmatch('%u') do set[letter] = true end
    if set.C and set.S and not set.M and not set.D then
      cs[k] = true
      if not cs_allowed[k] then extra[#extra + 1] = k .. ' ← ' .. table.concat(where, '; ') end
    end
    if set.D then
      d[k] = true
      if not d_allowed[k] then extra[#extra + 1] = k .. ' ← ' .. table.concat(where, '; ') end
    end
  end
  table.sort(extra)
  T.eq(extra, {}, 'лишние <C-S-…>/<D-…> в nvim_forge')
  local missing = {}
  for _, lhs in ipairs({ '<C-S-f>', '<C-S-p>', '<C-S-e>', '<C-S-d>', '<C-S-F5>' }) do
    if not cs[KN.canon(lhs)] then missing[#missing + 1] = lhs end
  end
  if not d[KN.canon('<D-A-l>')] then missing[#missing + 1] = '<D-A-l>' end
  T.eq(missing, {}, 'нет в nvim_forge')
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    T.eq(intercepted_of(os_name, { '<C-S-f>', '<C-S-p>', '<C-S-e>', '<C-S-d>', '<C-S-F5>', '<D-A-l>' }), {},
      os_name .. ': перехвачены')
  end
  -- На Windows их перехватывает только подмена WT-KEYS-10 (колбэк).
  T.eq(intercepted_of('windows', { '<D-A-l>' }), {}, 'windows: <D-A-l> перехвачен')
  for _, k in ipairs(KEYS10) do
    if k[2] == 'CTRL|SHIFT' then
      T.eq(F.normalize_action(binding('windows', k[1], k[2]).action).name, 'Callback', 'windows: ' .. k[3])
    end
  end
end)

-- ===========================================================================
-- WT-KEYS-10 Windows — подмена сочетаний nvim_forge (сторона nvim)
-- add-nvim-chords-on-windows, design, решения 4, 5, 8. Источник правды о
-- «байты → клавиша nvim» — проба через conpty.dll (chords.fixture.json).
-- ===========================================================================
local CHORDS_FIXTURE = B.root .. '/tests/wezterm/conpty/chords.fixture.json'
local CHORD_MODES = { 'n', 'x', 's', 'o', 'i', 'c', 't' }

local function chords_fixture()
  local f = assert(io.open(CHORDS_FIXTURE, 'rb'), 'нет ' .. CHORDS_FIXTURE)
  local d = vim.json.decode(f:read('*a'))
  f:close()
  return d
end

--- Модуль nvim_forge с таблицей подмен (без setup: только данные).
local function chords_module()
  local path = B.root .. '/nvim_forge/lua/config/wezterm_chords.lua'
  local ok, mod = pcall(dofile, path)
  if not ok then error('нет модуля или он не грузится: ' .. tostring(mod), 0) end
  return mod
end

T.check('WT-KEYS-10 nvim_forge: версия и таблица подмен совпадают с итогом пробы (фикстура)', function()
  local fx, mod = chords_fixture(), chords_module()
  T.eq(mod.version, fx.version, 'версия таблицы: модуль против фикстуры')
  local rows = fx.layouts.ru.rows
  T.eq(#mod.chords, #rows, 'строк в таблице')
  for i, row in ipairs(rows) do
    local m = mod.chords[i] or {}
    T.eq({ m.chord, m.lhs, KN.canon(m.key or '') }, { row.chord, row.lhs, KN.canon(row.nvim_key[1]) },
      ('строка %d (%s)'):format(i, row.chord))
  end
end)

T.check('WT-KEYS-10 nvim_forge: модуль подключён в init.lua после config.keymaps', function()
  local f = assert(io.open(B.root .. '/nvim_forge/init.lua', 'rb'))
  local text = f:read('*a')
  f:close()
  local k = text:find('require("config.keymaps")', 1, true)
  local c = text:find('require("config.wezterm_chords").setup()', 1, true)
  T.ok(k and c and c > k, 'в init.lua нет require("config.wezterm_chords").setup() после config.keymaps')
end)

T.check('WT-KEYS-10 nvim_forge: подменная клавиша переназначена на исходное сочетание во всех режимах (remap)', function()
  local mod = chords_module()
  local by = {}
  for _, m in ipairs(nvim_side().maps) do by[m.mode .. ' ' .. m.lhs] = m end
  for _, row in ipairs(mod.chords) do
    local key = vim.fn.keytrans(vim.keycode(row.key))
    for _, mode in ipairs(CHORD_MODES) do
      local m = by[mode .. ' ' .. key]
      T.ok(m, ('%s: нет привязки %s в режиме %s'):format(row.chord, key, mode))
      T.eq({ KN.canon(m.rhs), m.noremap }, { KN.canon(row.lhs), 0 }, ('%s: %s в режиме %s'):format(row.chord, key, mode))
    end
  end
end)

-- Привязки из config-функций плагинов коллектор не видит (tests/lib/nvim_keymaps.lua,
-- «Ограничение»): для них — файл плагина, где сочетание задано.
local CHORDS_IN_PLUGIN_CONFIG = { ['<C-Space>'] = 'nvim_forge/lua/plugins/completion.lua' }

T.check('WT-KEYS-10 nvim_forge: у каждого исходного сочетания есть привязка nvim_forge, у подменных — нет русского псевдонима', function()
  local mod = chords_module()
  local have = forge_keys()
  for _, row in ipairs(mod.chords) do
    local lhs = KN.canon(row.lhs)
    local plugin_file = CHORDS_IN_PLUGIN_CONFIG[row.lhs]
    if plugin_file then
      local f = assert(io.open(B.root .. '/' .. plugin_file, 'rb'))
      local text = f:read('*a')
      f:close()
      T.ok(text:find('["' .. row.lhs .. '"]', 1, true), ('%s: %s не задан в %s'):format(row.chord, row.lhs, plugin_file))
    else
      T.ok(#(have[lhs] or {}) > 0, ('%s: у %s нет привязки nvim_forge'):format(row.chord, row.lhs))
    end
  end
  -- Русские псевдонимы (ru_keys) ставятся только для букв: подменных клавиш
  -- с desc «WezTerm: …» ровно по одной на режим и строку.
  local n = 0
  for _, m in ipairs(nvim_side().maps) do
    if (m.desc or ''):find('^WezTerm: ') then n = n + 1 end
  end
  T.eq(n, #mod.chords * #CHORD_MODES, 'привязок «WezTerm: …» (подменные клавиши × режимы)')
end)

-- ---------------------------------------------------------------------------
-- WT-KEYS-10 (сторона WezTerm): привязки и колбэк на поддельной панели
-- ---------------------------------------------------------------------------

--- Запись win32-input-mode исходного нажатия из фикстуры: нажатие + отпускание.
local function original_bytes(rec)
  local f = '\27[%d;%d;%d;%d;%d;1_'
  return f:format(rec[1], rec[2], rec[3], 1, rec[4]) .. f:format(rec[1], rec[2], rec[3], 0, rec[4])
end

--- Что колбэк сочетания отправил панели с user vars `vars` → байты SendString.
local function chord_sends(k, vars)
  local b = binding('windows', k[1], k[2])
  local win = F.window()
  F.run_callback(b.action, win, F.pane({ user_vars = vars }))
  T.eq(#win.performed, 1, k[3] .. ': действий колбэка')
  local a = F.normalize_action(win.performed[1])
  T.eq(a.name, 'SendString', k[3] .. ': действие')
  return a.args[1]
end

T.check('WT-KEYS-10 Windows: по одной привязке на сочетание таблицы, буквы и знаки — по физической позиции', function()
  for _, k in ipairs(KEYS10) do
    local b = binding('windows', k[1], k[2])
    T.eq(F.normalize_action(b.action).name, 'Callback', k[3])
    local named = k[1] == 'Enter' or k[1] == 'F5'
    T.ok(named or b.key:match('^phys:'), k[3] .. ': не по физической позиции: ' .. tostring(b.key))
  end
end)

T.check('WT-KEYS-10 объявленная панель (FORGE_NVIM = версия): уходит подменная клавиша из итога пробы', function()
  local fx = chords_fixture()
  for i, row in ipairs(fx.layouts.ru.rows) do
    T.eq(chord_sends(KEYS10[i], { FORGE_NVIM = fx.version }), row.bytes, row.chord)
  end
end)

T.check('WT-KEYS-10 программы без объявления, пустое значение и другая версия: исходное нажатие', function()
  local fx = chords_fixture()
  for i, row in ipairs(fx.layouts.ru.rows) do
    local want = original_bytes(row.original)
    for _, vars in ipairs({ {}, { FORGE_NVIM = '' }, { FORGE_NVIM = fx.version .. '0' }, { IS_NVIM = 'true' } }) do
      T.eq(chord_sends(KEYS10[i], vars), want, row.chord .. ' ' .. vim.inspect(vars))
    end
  end
end)

T.check('WT-KEYS-10 macOS и Linux: подмен нет — сочетания таблицы не перехвачены', function()
  for _, os_name in ipairs({ 'macos', 'linux' }) do
    for _, k in ipairs(KEYS10) do
      T.eq(F.find_binding(cfg(os_name).keys, k[1], k[2]), nil, os_name .. ': ' .. k[3])
    end
  end
end)

T.check('WT-KEYS-10 версия таблицы в wezterm.lua совпадает с nvim_forge и фикстурой', function()
  local f = assert(io.open(B.root .. '/wezterm.lua', 'rb'))
  local v = f:read('*a'):match('local NVIM_CHORDS_VERSION = "([^"]+)"')
  f:close()
  T.eq({ v, chords_module().version }, { chords_fixture().version, chords_fixture().version }, 'версии')
end)

T.finish()
