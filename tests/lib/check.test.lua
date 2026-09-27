-- Самопроверки протокола tests/lib/check.lua (add-wezterm-spec-checks, задача 1.3).
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
local B = dofile(r .. '/tests/lib/bootstrap.lua')
local T = require('check')

-- Экземпляр с подставными стоками: строки протокола и код выхода — в таблицы.
local function capture(filter)
  local sink = { lines = {}, exits = {} }
  sink.T = T.new({
    filter = filter,
    out = function(line) sink.lines[#sink.lines + 1] = line end,
    err = function() end,
    exit = function(code) sink.exits[#sink.exits + 1] = code end,
  })
  return sink
end

T.check('SELF: случай с ошибкой даёт FAIL с текстом ошибки, следующий случай выполняется', function()
  local s = capture()
  local ran_next = false
  s.T.check('A падает', function() error('boom-42') end)
  s.T.check('B после падения', function() ran_next = true end)
  T.ok(s.lines[1]:match('^  FAIL A падает  %-%- .*boom%-42') ~= nil, 'строка FAIL: ' .. tostring(s.lines[1]))
  T.eq(s.lines[2], '  ok   B после падения')
  T.ok(ran_next, 'следующий случай не выполнился')
  T.eq(s.T.counts, { ok = 1, fail = 1, skip = 0 })
end)

T.check('SELF: файл с упавшим случаем завершается кодом 1, без падений — кодом 0', function()
  local bad = capture()
  bad.T.check('x', function() error('нет') end)
  bad.T.finish()
  T.eq(bad.exits, { 1 })
  local good = capture()
  good.T.check('y', function() end)
  good.T.skip('z', 'пропуск не валит файл')
  good.T.finish()
  T.eq(good.exits, { 0 })
end)

T.check('SELF: FORGE_TEST_ID=WT-CLIP-1 не выполняет «WT-CLIP-10 …»', function()
  local s = capture('WT-CLIP-1')
  local ran = {}
  for _, name in ipairs({ 'WT-CLIP-10 чужой', 'WT-CLIP-1 свой', 'WT-CLIP-1-b вариант', 'WT-CLIP-1', 'SELF: служебный' }) do
    s.T.check(name, function() ran[#ran + 1] = name end)
  end
  T.eq(ran, { 'WT-CLIP-1 свой', 'WT-CLIP-1-b вариант', 'WT-CLIP-1' })
  local cap = capture('WT-CLIP')
  local n = 0
  cap.T.check('WT-CLIP-10 x', function() n = n + 1 end)
  cap.T.check('WT-CLIPX-1 не та область', function() n = n + 100 end)
  T.eq(n, 1, '--id WT-CLIP берёт всю capability и только её')
end)

T.check('SELF: SKIP печатается с причиной и не считается ok', function()
  local s = capture()
  s.T.skip('WT-KBD-2 nvim получает <C-.>', 'MANUAL:\nкодировщик')
  T.eq(s.lines, { '  SKIP WT-KBD-2 nvim получает <C-.>  -- MANUAL: | кодировщик' })
  T.eq(s.T.counts, { ok = 0, fail = 0, skip = 1 })
end)

T.check('SELF: формат строк совпадает с tests/install-macos.scenarios.sh', function()
  local sh = table.concat(vim.fn.readfile(B.root .. '/tests/install-macos.scenarios.sh'), '\n')
  T.ok(sh:find("printf '  ok   %s\\n'", 1, true), 'в скрипте нет printf "  ok   %s"')
  T.ok(sh:find("printf '  FAIL %s\\n'", 1, true), 'в скрипте нет printf "  FAIL %s"')
  local s = capture()
  s.T.check('n1', function() end)
  s.T.check('n2', function() error('d', 0) end)
  T.eq(s.lines, { '  ok   n1', '  FAIL n2  -- d' })
end)

T.check('SELF: eq сравнивает таблицы глубоко и показывает путь расхождения', function()
  T.eq({ a = { 1, 2 }, b = 'x' }, { b = 'x', a = { 1, 2 } })
  local ok, e = pcall(T.eq, { keys = { { mods = 'CTRL' } } }, { keys = { { mods = 'SHIFT' } } }, 'клавиши')
  T.ok(not ok, 'eq не упал на разных таблицах')
  T.ok(e:find('клавиши: не равно', 1, true), e)
  T.ok(e:find('.keys[1].mods: получено "CTRL", ожидалось "SHIFT"', 1, true), e)
  local f = function() end
  T.ok(T.equal({ cb = f }, { cb = f }), 'функции сравниваются по идентичности')
  T.ok(not T.equal({ cb = f }, { cb = function() end }), 'разные функции равны')
end)

T.check('SELF: многострочная ошибка — первая строка в FAIL, остальные продолжением', function()
  local s = capture()
  s.T.check('m', function() error('первая\nвторая', 0) end)
  T.eq(s.lines, { '  FAIL m  -- первая', '      | вторая' })
end)

T.check('SELF: имя проверки с переводом строки — ошибка использования', function()
  local s = capture()
  T.ok(not pcall(s.T.check, 'a\nb', function() end), 'имя с \\n принято')
end)

T.check('SELF: настоящий процесс nvim: FAIL даёт код 1, FORGE_TEST_ID фильтрует', function()
  local code = table.concat({
    ("package.path = %q .. '/tests/lib/?.lua;' .. package.path"):format(B.root),
    "local T = require('check')",
    "T.check('WT-CLIP-10 чужой', function() end)",
    "T.check('WT-CLIP-1 свой', function() error('boom', 0) end)",
    'T.finish()',
  }, '; ')
  local res = vim.system({ vim.v.progpath, '--clean', '--headless', '-c', 'lua ' .. code }, {
    text = true,
    timeout = 30000,
    env = { FORGE_TEST_ID = 'WT-CLIP-1' },
  }):wait()
  local out = (res.stdout or ''):gsub('\r', '')
  T.eq(res.code, 1, 'код возврата; stdout=' .. out .. ' stderr=' .. (res.stderr or ''))
  T.ok(out:find('  FAIL WT-CLIP-1 свой  -- boom', 1, true), 'нет строки FAIL: ' .. out)
  T.ok(not out:find('WT-CLIP-10', 1, true), 'WT-CLIP-10 выполнился под фильтром WT-CLIP-1')
end)

T.finish()
