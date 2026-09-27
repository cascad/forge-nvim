-- Поддельный модуль `wezterm` для проверок под `nvim -l` (add-wezterm-spec-checks,
-- design, решение 3). Загружает wezterm.lua без GUI, диска и сети: тройка,
-- окружение, файлы и встроенные таблицы режимов подставляются параметрами.
--
--   local F = require('fake_wezterm')
--   local r = F.load_config{
--     triple = F.TRIPLES.windows,       -- обязательна
--     env    = { PATH = 'C:\\pwsh' },   -- os.getenv; чего нет — nil
--     files  = { ['C:\\pwsh\\pwsh.exe'] = '' },  -- io.open читает отсюда
--     listed = { 'C:\\WinApps\\pwsh.exe' },  -- видны wezterm.glob, но не io.open
--                                             -- (псевдоним Microsoft Store)
--     workspace = 'work',                     -- wezterm.mux.get_active_workspace()
--   }
--   r.config, r.events['update-right-status'], r.writes[path], r.callbacks, r.wezterm
--
-- Каждое поддельное поведение ниже помечено: что из WezTerm 20240203 оно
-- имитирует и где это проверено. «Проба 20240203» = конфиг-проба в настоящем
-- `wezterm --config-file <проба> show-keys`, WezTerm 20240203-110809-5046fc22,
-- Windows, 2026-09-27 (при подготовке этого change). Чего подделка НЕ
-- имитирует — в tests/README.md, «Подделка wezterm: ограничения».
--
-- Действия — данные: act.CopyTo('X') → { name = 'CopyTo', args = { 'X' } },
-- act.PopKeyTable → { name = 'PopKeyTable' }. Настоящий WezTerm отдаёт
-- { CopyTo = 'X' } и строку 'PopKeyTable' (проба 20240203); форма { name, args }
-- одна для конфига и для фикстуры (from_real_action), её и сравнивают проверки.

local B = require('bootstrap')

local M = {}

M.TRIPLES = {
  windows = 'x86_64-pc-windows-msvc',
  macos = 'aarch64-apple-darwin',
  linux = 'x86_64-unknown-linux-gnu',
}
M.CONFIG_PATH = B.root .. '/wezterm.lua'
M.FIXTURE_PATH = B.root .. '/tests/wezterm/fixtures/default_key_tables.lua'
-- Заведомо несуществующий домашний каталог: если что-то пройдёт мимо
-- поддельного io, на диске оно ничего не найдёт.
M.HOME = '/nonexistent/forge-fake-home'
M.VERSION = vim.trim(table.concat(vim.fn.readfile(B.root .. '/tests/wezterm/VERSION'), '\n'))

local deepcopy = vim.deepcopy

-- ---------------------------------------------------------------------------
-- Действия
-- ---------------------------------------------------------------------------

--- act.* как данные. Имитирует wezterm.action: любое имя — конструктор
--- (act.X(arg)) и одновременно значение без аргумента (act.X).
--- Не имитирует: настоящий act.PopKeyTable — строка, её нельзя вызвать
--- (act.PopKeyTable() упадёт только в настоящем WezTerm, решение 7).
local function make_act()
  return setmetatable({}, {
    __index = function(_, name)
      return setmetatable({ name = name }, {
        __call = function(_, ...) return { name = name, args = { ... } } end,
      })
    end,
  })
end

--- Действие из формы WezTerm (фикстура, default_key_tables) в форму подделки:
--- 'PopKeyTable' → { name = 'PopKeyTable' }; { CopyMode = 'Close' } →
--- { name = 'CopyMode', args = { 'Close' } }; Multiple — поэлементно.
--- Форма WezTerm проверена пробой 20240203 (wezterm.to_string(act.Multiple{…})).
function M.from_real_action(v)
  if type(v) == 'string' then return { name = v } end
  if type(v) ~= 'table' then error('from_real_action: не действие: ' .. vim.inspect(v)) end
  local name, payload = next(v)
  if name == nil or next(v, name) ~= nil then
    error('from_real_action: ожидалась таблица с одним ключом { Имя = аргумент }: ' .. vim.inspect(v))
  end
  if name == 'Multiple' then
    local list = {}
    for i, a in ipairs(payload) do list[i] = M.from_real_action(a) end
    payload = list
  end
  return { name = name, args = { deepcopy(payload) } }
end

--- Приведение к форме { name, args } того, что лежит в конфиге: строка
--- 'PopKeyTable' (так пишет wezterm.lua в resize_pane) → { name = 'PopKeyTable' }.
function M.normalize_action(a)
  if type(a) == 'string' then return { name = a } end
  return a
end

-- ---------------------------------------------------------------------------
-- Клавиши: нормализация как у WezTerm 20240203
-- ---------------------------------------------------------------------------

-- Символы, у которых в WezTerm есть имя: KeyCode::try_from (wezterm-input-types/
-- src/lib.rs, 20240203): Backspace, Tab, Return|Enter, Escape, Delete → Char.
local CHAR_NAME = { ['\8'] = 'Backspace', ['\t'] = 'Tab', ['\r'] = 'Enter', ['\27'] = 'Escape', ['\127'] = 'Delete' }
local NAME_ALIAS = { Return = 'Enter' }

--- Каноническое имя клавиши — одна запись на одну клавишу WezTerm 20240203:
---   * 'phys:c' и 'phys:C' — одна клавиша: PhysKeyCode принимает однобуквенные
---     имена в обоих регистрах (wezterm-input-types/src/lib.rs, make_map:
---     `if key.len() == 1 { map.insert(key.to_ascii_lowercase(), …) }`) → 'phys:C';
---   * 'mapped:\r', 'mapped:Enter', 'Enter', 'Return' — одна клавиша Char('\r')
---     → 'Enter' (так же Tab, Escape, Backspace, Delete); без префикса ключ
---     разбирается как mapped (config/src/keys.rs DeferredKeyCode, key_map_preference
---     по умолчанию Mapped). Проба 20240203: 'Return' и 'mapped:\r' в show-keys — 'Enter';
---   * одиночный символ без префикса ≡ 'mapped:<символ>' → 'mapped:<символ>';
---   * 'Space' без префикса — ФИЗИЧЕСКАЯ клавиша (проба 20240203: show-keys
---     печатает 'phys:Space'), а 'mapped: ' — символ пробела; это разные клавиши;
---   * остальные имена (PageUp, F13, LeftArrow, phys:LeftBracket) — как есть.
function M.norm_key(k)
  if type(k) ~= 'string' then return tostring(k) end
  local phys = k:match('^phys:(.+)$')
  if phys then
    return 'phys:' .. (#phys == 1 and phys:upper() or phys)
  end
  if k:match('^raw:') then return k end
  local mapped = k:match('^mapped:(.+)$')
  if not mapped then
    if k == 'Space' then return 'phys:Space' end
    mapped = k
  end
  mapped = NAME_ALIAS[mapped] or mapped
  if CHAR_NAME[mapped] then return CHAR_NAME[mapped] end
  if #mapped == 1 then return 'mapped:' .. mapped end
  return mapped
end

-- Синонимы модификаторов: Modifiers::try_from (wezterm-input-types/src/lib.rs,
-- 20240203): OPT, META → ALT; CMD, WIN → SUPER; NONE и '' — пусто.
local MOD_ALIAS = { OPT = 'ALT', META = 'ALT', CMD = 'SUPER', WIN = 'SUPER' }

--- Модификаторы как отсортированное множество: 'SHIFT|CTRL' == 'CTRL|SHIFT',
--- nil == '' == 'NONE'. Регистр не меняется: 'ctrl' WezTerm не принимает.
function M.norm_mods(m)
  if m == nil then return 'NONE' end
  local set, list = {}, {}
  for part in tostring(m):gmatch('[^|]+') do
    part = vim.trim(part)
    part = MOD_ALIAS[part] or part
    if part ~= '' and part ~= 'NONE' and not set[part] then
      set[part] = true
      list[#list + 1] = part
    end
  end
  if #list == 0 then return 'NONE' end
  table.sort(list)
  return table.concat(list, '|')
end

--- Каноническая пара (клавиша, модификаторы). Сверх norm_key/norm_mods —
--- normalize_shift WezTerm (wezterm-input-types/src/lib.rs, 20240203; применяется
--- при разборе config.keys и key_tables): символ-буква с SHIFT → заглавная без
--- SHIFT. Проба 20240203: 'mapped:G'+SHIFT и 'G'+NONE — одна запись в show-keys.
--- → key, mods, 'key mods' (строка-идентификатор пары, для поиска повторов).
function M.norm_binding(key, mods)
  local k, m = M.norm_key(key), M.norm_mods(mods)
  local c = k:match('^mapped:(%a)$')
  if c and ('|' .. m .. '|'):find('|SHIFT|', 1, true) then
    k = 'mapped:' .. c:upper()
    local rest = {}
    for part in m:gmatch('[^|]+') do if part ~= 'SHIFT' then rest[#rest + 1] = part end end
    m = #rest == 0 and 'NONE' or table.concat(rest, '|')
  end
  return k, m, k .. ' ' .. m
end

--- Привязка (key, mods) в списке. WezTerm при повторе пары молча оставляет
--- ПОСЛЕДНЮЮ запись (WT-KEYS-8), поэтому и здесь — последняя совпавшая.
--- → binding, index, count (сколько записей с этой парой).
function M.find_binding(list, key, mods)
  local _, _, want = M.norm_binding(key, mods)
  local found, index, count = nil, nil, 0
  for i, b in ipairs(list or {}) do
    local _, _, id = M.norm_binding(b.key, b.mods)
    if id == want then
      found, index, count = b, i, count + 1
    end
  end
  return found, index, count
end

--- Выполнить колбэк действия action_callback на поддельных окне и панели.
function M.run_callback(action, win, pane, ...)
  if type(action) ~= 'table' or action.name ~= 'Callback' or type(action.fn) ~= 'function' then
    error('run_callback: не колбэк: ' .. vim.inspect(M.normalize_action(action)), 2)
  end
  return action.fn(win, pane, ...)
end

-- ---------------------------------------------------------------------------
-- Фикстура встроенных таблиц
-- ---------------------------------------------------------------------------
local fixture_cache

--- Встроенные таблицы режимов в форме WezTerm, как их отдаёт
--- wezterm.gui.default_key_tables() 20240203 (фикстура снята с бинарника,
--- tests/wezterm/guard.lua). Порядок записей — отсортированный: настоящий
--- порядок случаен от запуска к запуску.
function M.real_default_key_tables()
  if not fixture_cache then
    local ok, t = pcall(dofile, M.FIXTURE_PATH)
    if not ok then
      error('fake_wezterm: нет фикстуры ' .. M.FIXTURE_PATH
        .. ' — выгрузи: nvim -l tests/run.lua --update-golden (' .. tostring(t) .. ')', 0)
    end
    fixture_cache = t
  end
  return deepcopy(fixture_cache)
end

local function convert_tables(real)
  local out = {}
  for name, binds in pairs(real) do
    local list = {}
    for i, b in ipairs(binds) do
      list[i] = { key = b.key, mods = b.mods, action = M.from_real_action(b.action) }
    end
    out[name] = list
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Поддельные окно, вкладка, панель
-- ---------------------------------------------------------------------------

--- Вкладка: set_title записывается (MuxTab:set_title).
function M.tab(o)
  o = o or {}
  local t = { title = o.title, titles = {} }
  function t:set_title(s)
    self.title = s
    self.titles[#self.titles + 1] = s
  end
  function t:get_title() return self.title end
  return t
end

--- Окно для колбэков (GuiWindow). Всё, что делает колбэк, записывается:
---   performed — действия perform_action по порядку;
---   toasts    — { title, message, url, timeout } из toast_notification;
---   overrides — текущие config overrides; override_calls — каждый set_config_overrides;
---   right_status / left_status; inner_size {w,h} / position {x,y}; calls — журнал.
--- o: selection (текст выделения, по умолчанию '' — как у WezTerm без выделения),
--- active_key_table, dimensions, config_overrides, effective_config (без overrides),
--- workspace, tab, pane.
function M.window(o)
  o = o or {}
  local w = {
    performed = {}, toasts = {}, override_calls = {}, calls = {},
    overrides = o.config_overrides and deepcopy(o.config_overrides) or nil,
    tab = o.tab or M.tab(),
    pane = o.pane,
  }
  local function log(what, ...) w.calls[#w.calls + 1] = { what, ... } end

  function w:get_selection_text_for_pane(pane)
    log('get_selection_text_for_pane', pane)
    return o.selection or ''
  end
  function w:perform_action(action, pane)
    log('perform_action', action, pane)
    self.performed[#self.performed + 1] = action
  end
  function w:toast_notification(title, message, url, timeout)
    self.toasts[#self.toasts + 1] = { title = title, message = message, url = url, timeout = timeout }
  end
  function w:get_dimensions()
    return deepcopy(o.dimensions or { pixel_width = 1500, pixel_height = 950, dpi = 96, is_full_screen = false })
  end
  -- effective_config() отражает set_config_overrides (так работает Ctrl+= в
  -- wezterm.lua: шрифт берётся из effective_config после overrides).
  function w:effective_config()
    local eff = deepcopy(o.effective_config or {})
    for k, v in pairs(self.overrides or {}) do eff[k] = deepcopy(v) end
    return eff
  end
  function w:get_config_overrides()
    return self.overrides and deepcopy(self.overrides) or nil
  end
  -- set_config_overrides(nil) пишется в override_calls как vim.NIL: иначе
  -- вызов с nil в журнале не виден.
  function w:set_config_overrides(t)
    self.overrides = deepcopy(t)
    self.override_calls[#self.override_calls + 1] = t == nil and vim.NIL or deepcopy(t)
  end
  function w:window_id() return o.window_id or 1 end
  function w:active_tab() return self.tab end
  function w:active_pane() return self.pane end
  function w:active_key_table() return o.active_key_table end
  function w:active_workspace() return o.workspace or 'default' end
  function w:set_right_status(s) self.right_status = s end
  function w:set_left_status(s) self.left_status = s end
  function w:set_inner_size(width, height)
    log('set_inner_size', width, height)
    self.inner_size = { width, height }
  end
  function w:set_position(x, y)
    log('set_position', x, y)
    self.position = { x, y }
  end
  function w:gui_window() return self end
  return w
end

--- Панель. split() возвращает новую поддельную панель; все операции
--- семейства панелей (исходная и порождённые split) пишутся в общий список
--- pane.log по порядку: { op = 'split'|'activate'|'get_lines_as_text', pane = id, … }.
--- o: id, text (что отдаёт get_lines_as_text), dimensions, user_vars
--- (get_user_vars(): то, что программа объявила через OSC 1337 SetUserVar).
function M.pane(o)
  o = o or {}
  local family = o._family or { log = {}, next_id = 1 }
  local id = o.id or family.next_id
  family.next_id = math.max(family.next_id, id) + 1
  local log = family.log
  local p = {
    id = id, splits = {}, activated = 0, log = log, text = o.text or '',
    dimensions = o.dimensions or { cols = 120, viewport_rows = 40, scrollback_rows = 1000, physical_top = 0 },
  }
  function p:split(args)
    local child = M.pane({ _family = family })
    self.splits[#self.splits + 1] = { args = deepcopy(args), pane = child }
    log[#log + 1] = { op = 'split', pane = self.id, args = deepcopy(args), new = child.id }
    return child
  end
  function p:activate()
    self.activated = self.activated + 1
    log[#log + 1] = { op = 'activate', pane = self.id }
  end
  function p:get_lines_as_text(n)
    log[#log + 1] = { op = 'get_lines_as_text', pane = self.id, n = n }
    return self.text
  end
  function p:get_dimensions() return deepcopy(self.dimensions) end
  function p:pane_id() return self.id end
  function p:get_user_vars() return deepcopy(o.user_vars or {}) end
  return p
end

-- ---------------------------------------------------------------------------
-- Поддельные io и os для чанка конфига
-- ---------------------------------------------------------------------------

local function read_handle(content)
  local pos, closed = 1, false
  local h = {}
  local function read_one(fmt)
    if fmt == nil then fmt = '*l' end
    if type(fmt) == 'number' then
      if pos > #content then return nil end
      local s = content:sub(pos, pos + fmt - 1)
      pos = pos + #s
      return s
    end
    fmt = fmt:gsub('^%*', '')
    if fmt == 'a' then
      local s = content:sub(pos)
      pos = #content + 1
      return s
    end
    if fmt == 'l' or fmt == 'L' then
      if pos > #content then return nil end
      local e = content:find('\n', pos, true)
      local line = content:sub(pos, (e or #content + 1) - 1)
      pos = (e or #content) + 1
      return fmt == 'L' and (line .. (e and '\n' or '')) or line
    end
    if fmt == 'n' then
      local s, e = content:find('^%s*[-+]?%d+%.?%d*[eE]?[-+]?%d*', pos)
      if not s then return nil end
      pos = e + 1
      return tonumber(vim.trim(content:sub(s, e)))
    end
    error('fake io: формат read ' .. tostring(fmt) .. ' не поддержан')
  end
  function h:read(...)
    if closed then error('attempt to use a closed file') end
    local n = select('#', ...)
    if n == 0 then return read_one() end
    local res = {}
    for i = 1, n do res[i] = read_one((select(i, ...))) end
    return unpack(res, 1, n)
  end
  function h:lines(fmt)
    return function() return read_one(fmt) end
  end
  function h:close() closed = true; return true end
  function h:seek() error('fake io: seek не поддержан') end
  return h
end

local function write_handle(state, path, initial)
  local buf, closed = { initial }, false
  local h = {}
  local function flush()
    state.files[path] = table.concat(buf)
    state.writes[path] = state.files[path]
  end
  function h:write(...)
    if closed then error('attempt to use a closed file') end
    for i = 1, select('#', ...) do
      local v = select(i, ...)
      buf[#buf + 1] = type(v) == 'number' and tostring(v) or v
    end
    flush()
    return self
  end
  function h:flush() flush(); return self end
  function h:close() flush(); closed = true; return true end
  function h:setvbuf() return true end
  h.closed = function() return closed end
  return h
end

--- io для чанка: open/lines поверх state.files (таблица в памяти), запись
--- перехватывается в state.writes. Неизвестный путь — (nil, сообщение, 2),
--- как у Lua io.open для отсутствующего файла; путь из opts.unwritable при
--- записи — (nil, 'Permission denied', 13). Остальное (stdout, stderr, write)
--- — настоящий io.
local function make_io(state)
  local fio = {}
  function fio.open(path, mode)
    mode = mode or 'r'
    state.opened[#state.opened + 1] = { path = path, mode = mode }
    local m = mode:sub(1, 1)
    if m == 'r' then
      local content = state.files[path]
      if content == nil or content == false then
        return nil, path .. ': No such file or directory', 2
      end
      return read_handle(content)
    elseif m == 'w' or m == 'a' then
      if state.unwritable[path] then return nil, path .. ': Permission denied', 13 end
      return write_handle(state, path, m == 'a' and (state.files[path] or '') or '')
    end
    error('fake io.open: режим ' .. mode .. ' не поддержан', 2)
  end
  function fio.lines(path, fmt)
    local h, err = fio.open(path, 'r')
    if not h then error(err, 2) end
    return h:lines(fmt)
  end
  return setmetatable(fio, { __index = io })
end

--- os для чанка: getenv берёт значения только из opts.env (чего нет — nil);
--- остальное — настоящий os (design, решение 3).
local function make_os(state, env_vars)
  return setmetatable({
    getenv = function(name)
      state.getenv[#state.getenv + 1] = name
      return env_vars[name]
    end,
  }, { __index = os })
end

-- ---------------------------------------------------------------------------
-- Сам модуль wezterm
-- ---------------------------------------------------------------------------

local function dirname(path)
  return (path:gsub('\\', '/'):match('^(.*)/[^/]*$')) or '.'
end

local function make_wezterm(state, opts, path)
  local W = {}
  W.target_triple = opts.triple
  W.version = opts.version or M.VERSION
  -- Настоящий wezterm.home_dir — строка (проба 20240203: 'C:\Users\…').
  W.home_dir = opts.home or M.HOME
  W.config_file = path
  W.config_dir = dirname(path)
  W.action = make_act()

  -- config_builder() → обычная таблица. НЕ имитирует: настоящий builder
  -- бросает ошибку на неизвестное поле (проба 20240203: «`x` is not a valid
  -- Config field»); это ловит только загрузка настоящим бинарником (решение 7).
  function W.config_builder() return {} end

  -- action_callback(fn): настоящий регистрирует обработчик события
  -- 'user-defined-N' (N с 0 по порядку создания) и отдаёт EmitEvent
  -- (проба 20240203: первый колбэк — user-defined-0, второй — user-defined-1).
  function W.action_callback(fn)
    local cb = { name = 'Callback', fn = fn, event = 'user-defined-' .. #state.callbacks }
    state.callbacks[#state.callbacks + 1] = cb
    return cb
  end

  -- on(name, fn): настоящий копит обработчики события по порядку. Здесь
  -- events[name] — обработчик; при повторной регистрации — функция, которая
  -- вызывает их все по порядку (event_handlers[name] — список).
  function W.on(name, fn)
    state.calls[#state.calls + 1] = { 'on', name }
    local list = state.event_handlers[name] or {}
    list[#list + 1] = fn
    state.event_handlers[name] = list
    if #list == 1 then
      state.events[name] = fn
    else
      state.events[name] = function(...)
        local res
        for _, h in ipairs(list) do res = h(...) end
        return res
      end
    end
  end

  -- font_with_fallback: форма настоящего TextStyle (проба 20240203,
  -- wezterm.to_string): { font = { { family, is_fallback, is_synthetic,
  -- stretch, style, weight }, … } }, is_fallback = false только у первого.
  function W.font_with_fallback(list)
    local fonts = {}
    for i, f in ipairs(list) do
      local e = type(f) == 'string' and { family = f } or deepcopy(f)
      e.is_fallback = i > 1
      e.is_synthetic = e.is_synthetic or false
      e.stretch = e.stretch or 'Normal'
      e.style = e.style or 'Normal'
      e.weight = e.weight or 'Regular'
      fonts[i] = e
    end
    return { font = fonts }
  end

  -- json_parse: null → nil, как у настоящего; битый JSON — ошибка (проба
  -- 20240203: «key must be a string at line 1 column 2»).
  function W.json_parse(s)
    return vim.json.decode(s, { luanil = { object = true, array = true } })
  end
  -- json_encode: ключи отсортированы, как у настоящего (serde_json, проба
  -- 20240203). НЕ имитирует: целые float настоящий пишет «12.0», здесь «12».
  function W.json_encode(v)
    return vim.json.encode(v, { sort_keys = true })
  end

  -- format(elems): настоящий отдаёт строку с escape-последовательностями;
  -- здесь — сами элементы, чтобы проверки видели структуру статус-бара.
  function W.format(elems) return elems end

  -- glob(pattern): только литеральный путь (так его зовёт wezterm.lua).
  -- Видит файлы из opts.files и записи opts.listed (псевдоним Microsoft Store:
  -- в каталоге есть, а io.open на нём падает — проба 20240203, 2026-09-27).
  -- Разделители и регистр не важны, как на Windows. Результат — с '/'.
  function W.glob(pattern)
    local function norm(x) return (x:gsub('\\', '/')):lower() end
    local want = norm(pattern)
    if want:find('[%*%?%[{]') then error('fake glob: только литеральные пути: ' .. pattern, 2) end
    for path in pairs(state.files) do
      if norm(path) == want then return { (path:gsub('\\', '/')) } end
    end
    for _, path in ipairs(opts.listed or {}) do
      if norm(path) == want then return { (path:gsub('\\', '/')) } end
    end
    return {}
  end

  -- column_width / truncate_right: ширина в знакоместах, как у WezTerm при
  -- выключенном treat_east_asian_ambiguous_width_as_wide (▶ и · — по одному).
  function W.column_width(str) return vim.fn.strdisplaywidth(str) end
  function W.truncate_right(str, max_cells)
    local out, w = {}, 0
    for _, ch in ipairs(vim.fn.split(str, '\\zs')) do
      local cw = vim.fn.strdisplaywidth(ch)
      if w + cw > max_cells then break end
      out[#out + 1] = ch
      w = w + cw
    end
    return table.concat(out)
  end

  -- Журнал: res.logs = { { уровень, текст }, … }.
  function W.log_info(...) state.logs[#state.logs + 1] = { 'info', table.concat(vim.tbl_map(tostring, { ... }), ' ') } end
  function W.log_warn(...) state.logs[#state.logs + 1] = { 'warn', table.concat(vim.tbl_map(tostring, { ... }), ' ') } end
  function W.log_error(...) state.logs[#state.logs + 1] = { 'error', table.concat(vim.tbl_map(tostring, { ... }), ' ') } end

  if opts.gui ~= false then
    -- Нет GUI (mux-сервер) — opts.gui = false: wezterm.gui = nil.
    W.gui = {
      default_key_tables = function()
        state.calls[#state.calls + 1] = { 'gui.default_key_tables' }
        return convert_tables(opts.default_key_tables or M.real_default_key_tables())
      end,
      -- screens(): форма настоящего (active/main/by_name/virtual_screen,
      -- x/y/width/height/name/scale). opts.screens — таблица или функция
      -- (функция, бросающая ошибку, имитирует недоступный API экрана).
      screens = function()
        state.calls[#state.calls + 1] = { 'gui.screens' }
        local s = opts.screens
        if type(s) == 'function' then return s() end
        if s then return deepcopy(s) end
        local scr = { name = 'FAKE-1', x = 0, y = 0, width = 1920, height = 1080, scale = 1.0 }
        return { active = deepcopy(scr), main = deepcopy(scr), by_name = { ['FAKE-1'] = deepcopy(scr) },
          virtual_screen = deepcopy(scr) }
      end,
    }
  end

  -- mux: spawn_window(cmd) → tab, pane, window (MuxWindow); window:gui_window()
  -- — поддельное окно (set_inner_size/set_position пишутся). Все вызовы — в
  -- state.spawned.
  W.mux = {
    get_active_workspace = function() return opts.workspace or 'default' end,
    spawn_window = function(cmd)
      state.calls[#state.calls + 1] = { 'mux.spawn_window', cmd }
      local pane = M.pane()
      local tab = M.tab()
      local gui = M.window({ pane = pane, tab = tab })
      local mux_window = { gui = gui }
      function mux_window:gui_window() return self.gui end
      state.spawned[#state.spawned + 1] = { cmd = cmd, tab = tab, pane = pane, window = mux_window, gui = gui }
      return tab, pane, mux_window
    end,
  }
  return W
end

-- Стандартные библиотеки, которые конфиг может взять через require.
local STDLIB = { string = true, table = true, math = true, coroutine = true, bit = true, utf8 = true, debug = true }

local function make_env(state, W, opts, path)
  local env = setmetatable({}, { __index = _G })
  env.os = make_os(state, opts.env or {})
  env.io = make_io(state)
  env.package = setmetatable({ loaded = state.modules }, { __index = package })
  env._G = env
  local dir = dirname(path)
  -- require: 'wezterm' → подделка; модули рядом с конфигом — как package.path
  -- WezTerm (<каталог конфига>/?.lua и ?/init.lua) и в том же окружении.
  env.require = function(name)
    if name == 'wezterm' then return W end
    if name == 'os' then return env.os end
    if name == 'io' then return env.io end
    if state.modules[name] ~= nil then return state.modules[name] end
    if STDLIB[name] and _G[name] then return _G[name] end
    local rel = name:gsub('%.', '/')
    for _, cand in ipairs({ dir .. '/' .. rel .. '.lua', dir .. '/' .. rel .. '/init.lua' }) do
      if vim.uv.fs_stat(cand) then
        local chunk = assert(loadfile(cand))
        setfenv(chunk, env)
        local mod = chunk(name)
        if mod == nil then mod = true end
        state.modules[name] = mod
        return mod
      end
    end
    error(("fake_wezterm: модуль '%s' не найден рядом с конфигом (%s)"):format(name, dir), 2)
  end
  return env
end

--- Загрузить конфиг через подделку.
--- opts: triple (обязательно), env, files, path | source (+ chunkname), home,
---       unwritable = { [путь] = true }, gui = false, screens, default_key_tables
---       (в форме WezTerm), version.
--- → { config, events, event_handlers, writes, files, opened, getenv, callbacks,
---     calls, spawned, logs, wezterm }
--- Ошибка загрузки (синтаксис, выполнение) пробрасывается с текстом Lua.
function M.load_config(opts)
  opts = opts or {}
  if type(opts.triple) ~= 'string' then
    error('load_config: нужна тройка, например F.TRIPLES.windows', 2)
  end
  local path = opts.path or M.CONFIG_PATH
  local unwritable = {}
  for k, v in pairs(opts.unwritable or {}) do
    if type(k) == 'number' then unwritable[v] = true else unwritable[k] = v end
  end
  local state = {
    files = deepcopy(opts.files or {}),
    unwritable = unwritable,
    writes = {}, opened = {}, getenv = {}, calls = {},
    events = {}, event_handlers = {}, callbacks = {}, spawned = {}, modules = {}, logs = {},
  }
  local W = make_wezterm(state, opts, path)
  local env = make_env(state, W, opts, path)

  local chunk, err
  if opts.source then
    chunk, err = loadstring(opts.source, '@' .. (opts.chunkname or path))
  else
    chunk, err = loadfile(path)
  end
  if not chunk then error(err, 0) end
  setfenv(chunk, env)
  local config = chunk()

  return {
    config = config,
    events = state.events,
    event_handlers = state.event_handlers,
    writes = state.writes,
    files = state.files,
    opened = state.opened,
    getenv = state.getenv,
    callbacks = state.callbacks,
    calls = state.calls,
    spawned = state.spawned,
    logs = state.logs,
    wezterm = W,
    env = env,
  }
end

return M
