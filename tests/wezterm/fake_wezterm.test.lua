-- Самопроверки поддельного модуля wezterm (add-wezterm-spec-checks, задача 2.3).
-- Проверяют саму подделку, а не требования: требования — в <capability>.test.lua.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')
local F = require('fake_wezterm')

local ORDER = { 'windows', 'macos', 'linux' }

T.check('SELF: config.keys не пуст для трёх троек', function()
  for _, os_name in ipairs(ORDER) do
    local res = F.load_config({ triple = F.TRIPLES[os_name] })
    T.ok(type(res.config) == 'table', os_name .. ': конфиг не таблица')
    T.ok(type(res.config.keys) == 'table' and #res.config.keys > 0, os_name .. ': config.keys пуст')
  end
end)

T.check('SELF: настоящий io.open при загрузке не вызывается (шпион)', function()
  local real_open, real_lines, real_popen = io.open, io.lines, io.popen
  local spied = {}
  io.open = function(p, ...) spied[#spied + 1] = 'io.open ' .. tostring(p); return real_open(p, ...) end
  io.lines = function(p, ...) spied[#spied + 1] = 'io.lines ' .. tostring(p); return real_lines(p, ...) end
  io.popen = function(p, ...) spied[#spied + 1] = 'io.popen ' .. tostring(p); return real_popen(p, ...) end
  local ok, res = pcall(function()
    local out = {}
    for _, os_name in ipairs(ORDER) do
      out[os_name] = F.load_config({ triple = F.TRIPLES[os_name], env = { PATH = 'C:\\bin;D:\\tools' } })
    end
    return out
  end)
  io.open, io.lines, io.popen = real_open, real_lines, real_popen
  T.ok(ok, tostring(res))
  T.eq(spied, {}, 'вызовы настоящего io при загрузке')
  -- А через поддельный io конфиг ходил: файл состояния и поиск pwsh.exe по PATH.
  T.ok(#res.windows.opened > 0, 'конфиг не открыл ни одного файла через подделку')
end)

T.check('SELF: копия wezterm.lua с оператором // не загружается — синтаксическая ошибка', function()
  local text = table.concat(vim.fn.readfile(F.CONFIG_PATH), '\n')
  local mutated = 'local _forge_floor_div = 7 // 2\n' .. text
  local ok, err = pcall(F.load_config, {
    triple = F.TRIPLES.windows, source = mutated, chunkname = '.tests/mutant-floor-div/wezterm.lua',
  })
  T.ok(not ok, 'копия с // загрузилась под LuaJIT')
  T.ok(tostring(err):find('.tests/mutant-floor-div/wezterm.lua:1:', 1, true), 'нет файла и строки: ' .. tostring(err))
  T.ok(tostring(err):find("unexpected symbol near '/'", 1, true), 'не синтаксическая ошибка: ' .. tostring(err))
end)

T.check('SELF: встроенные таблицы режимов берутся из фикстуры и приводятся к { name, args }', function()
  local real = F.real_default_key_tables()
  T.ok(real.copy_mode and real.search_mode, 'в фикстуре нет copy_mode/search_mode')
  local res = F.load_config({ triple = F.TRIPLES.windows })
  T.ok(res.config.key_tables.copy_mode and res.config.key_tables.search_mode, 'конфиг не получил таблицы режимов')
  T.eq(#res.config.key_tables.search_mode, #real.search_mode, 'search_mode переносится целиком')
  T.eq(F.from_real_action({ Multiple = { { CopyTo = 'ClipboardAndPrimarySelection' }, 'PopKeyTable' } }), {
    name = 'Multiple',
    args = { { { name = 'CopyTo', args = { 'ClipboardAndPrimarySelection' } }, { name = 'PopKeyTable' } } },
  })
  T.eq(F.from_real_action({ CopyMode = { MoveByPage = -0.5 } }), { name = 'CopyMode', args = { { MoveByPage = -0.5 } } })
end)

T.check('SELF: act.* — данные, action_callback нумерует события с user-defined-0', function()
  local res = F.load_config({
    triple = F.TRIPLES.linux,
    source = table.concat({
      "local wezterm = require('wezterm')",
      'local act = wezterm.action',
      'local a = wezterm.action_callback(function() end)',
      'local b = wezterm.action_callback(function() end)',
      "return { copy = act.CopyTo('Clipboard'), pop = act.PopKeyTable,",
      "  multi = act.Multiple({ act.PopKeyTable, act.SendKey({ key = 'F13' }) }), a = a, b = b }",
    }, '\n'),
  })
  local c = res.config
  T.eq(c.copy, { name = 'CopyTo', args = { 'Clipboard' } })
  T.eq(c.pop, { name = 'PopKeyTable' })
  T.eq(c.multi, { name = 'Multiple', args = { { { name = 'PopKeyTable' }, { name = 'SendKey', args = { { key = 'F13' } } } } } })
  T.eq({ c.a.name, c.a.event, c.b.event }, { 'Callback', 'user-defined-0', 'user-defined-1' })
  T.ok(rawequal(res.callbacks[2], c.b), 'r.callbacks — те же объекты, по порядку создания')
  T.eq(F.normalize_action('PopKeyTable'), { name = 'PopKeyTable' })
end)

T.check('SELF: find_binding нормализует phys:-букву и модификаторы, отдаёт последнюю запись', function()
  local list = {
    { key = 'phys:c', mods = 'SHIFT|CTRL', action = 'first' },
    { key = 'phys:C', mods = 'CTRL | SHIFT', action = 'last' },
    { key = 'Enter', action = 'enter' },
    { key = 'phys:Q', mods = 'CMD', action = 'quit' },
  }
  local b, i, n = F.find_binding(list, 'phys:C', 'CTRL|SHIFT')
  T.eq({ b.action, i, n }, { 'last', 2, 2 })
  T.eq(F.find_binding(list, 'Enter', 'NONE').action, 'enter')
  T.eq(F.find_binding(list, 'Enter', '').action, 'enter')
  T.eq(F.find_binding(list, 'phys:Q', 'SUPER').action, 'quit')
  T.eq(F.find_binding(list, 'phys:Space', 'CTRL|SHIFT'), nil)
  T.eq(F.norm_mods('SHIFT|ALT|CTRL'), 'ALT|CTRL|SHIFT')
  T.eq(F.norm_key('phys:LeftBracket'), 'phys:LeftBracket')
  -- Одна клавиша WezTerm — одна запись (проба 20240203, show-keys).
  T.eq(F.find_binding(list, 'mapped:\r', 'NONE').action, 'enter', "'mapped:\\r' ≡ 'Enter'")
  T.eq(F.norm_key('Return'), 'Enter')
  T.eq(F.norm_key('mapped:\27'), 'Escape')
  T.eq({ F.norm_key('Space'), F.norm_key('mapped: ') }, { 'phys:Space', 'mapped: ' }, 'Space без префикса — физическая')
  T.eq(F.norm_key('a'), 'mapped:a')
  local _, _, id1 = F.norm_binding('mapped:g', 'SHIFT')
  local _, _, id2 = F.norm_binding('G', 'NONE')
  local _, _, id3 = F.norm_binding('phys:G', 'SHIFT')
  T.eq({ id1, id2, id3 }, { 'mapped:G NONE', 'mapped:G NONE', 'phys:G SHIFT' }, 'normalize_shift — только для символов')
end)

T.check('SELF: io в памяти — чтение, отсутствие, запрет записи; записи перехватываются; getenv из env', function()
  local res = F.load_config({
    triple = F.TRIPLES.windows,
    env = { P = 'из env' },
    files = { ['/x/in.txt'] = 'строка1\nстрока2' },
    unwritable = { ['/ro/out.txt'] = true },
    source = table.concat({
      "local f = io.open('/x/out.json', 'w'); f:write('{', 1, '}'); f:close()",
      "local g = io.open('/x/in.txt', 'r')",
      "local first = g:read('*l'); local rest = g:read('*a'); g:close()",
      "local ro, ro_err = io.open('/ro/out.txt', 'w')",
      "local miss, miss_err = io.open('/нет/файла')",
      "return { first = first, rest = rest, ro = ro, ro_err = ro_err, miss = miss, miss_err = miss_err,",
      "  p = os.getenv('P'), home = os.getenv('HOME') }",
    }, '\n'),
  })
  local c = res.config
  T.eq(res.writes, { ['/x/out.json'] = '{1}' })
  T.eq({ c.first, c.rest }, { 'строка1', 'строка2' })
  T.eq({ c.ro, c.ro_err }, { nil, '/ro/out.txt: Permission denied' })
  T.eq({ c.miss, c.miss_err }, { nil, '/нет/файла: No such file or directory' })
  T.eq({ c.p, c.home }, { 'из env', nil }, 'getenv видит только opts.env')
  T.eq(res.getenv, { 'P', 'HOME' })
end)

T.check('SELF: поддельные окно и панель записывают действия, уведомления, overrides и сплиты', function()
  local pane = F.pane({ text = 'вывод' })
  local log = pane.log
  local win = F.window({ selection = 'текст', active_key_table = 'windows', effective_config = { font_size = 12 } })
  T.eq(win:get_selection_text_for_pane(pane), 'текст')
  T.eq(F.window():get_selection_text_for_pane(pane), '', 'без выделения — пустая строка, как у WezTerm')
  win:perform_action({ name = 'ClearSelection' }, pane)
  win:toast_notification('WezTerm', 'сообщение', nil, 3000)
  win:set_config_overrides({ font_size = 13 })
  T.eq(win.performed, { { name = 'ClearSelection' } })
  T.eq(win.toasts, { { title = 'WezTerm', message = 'сообщение', timeout = 3000 } })
  T.eq(win:effective_config().font_size, 13, 'effective_config учитывает overrides')
  T.eq(win:active_key_table(), 'windows')
  local right = pane:split({ direction = 'Right', size = 0.35 })
  right:split({ direction = 'Bottom', size = 0.5 })
  pane:activate()
  T.eq(vim.tbl_map(function(e) return e.op .. ':' .. e.pane end, log), { 'split:1', 'split:2', 'activate:1' })
  T.eq(pane:get_lines_as_text(10), 'вывод')
end)

T.check('SELF: новое окно на поддельных screens (window-config-reloaded); без GUI конфиг грузится', function()
  local res = F.load_config({
    triple = F.TRIPLES.macos,
    screens = { active = { x = 100, y = 50, width = 2000, height = 1000 } },
  })
  local ev = res.events['window-config-reloaded']
  T.ok(type(ev) == 'function', 'нет обработчика window-config-reloaded')
  local gui = F.window()
  ev(gui, F.pane())
  T.ok(gui.inner_size and gui.position, 'размер и позиция окна не выставлены')
  T.eq(gui.override_calls, { {} }, 'окно не принято: overrides')
  T.eq(res.logs[#res.logs][1], 'info', 'журнал «принять окно»')
  local no_gui = F.load_config({ triple = F.TRIPLES.linux, gui = false })
  T.ok(no_gui.wezterm.gui == nil and no_gui.config.key_tables.copy_mode == nil,
    'gui = false: wezterm.gui отсутствует, встроенных таблиц нет')
end)

T.finish()
