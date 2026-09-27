-- Проверки загрузки конфига НАСТОЯЩИМ WezTerm: WT-LOAD-11 (add-wezterm-spec-checks,
-- задача 4.1, design, решение 7). Набор `wezterm`.
--
-- Почему не подделка: WezTerm 20240203 ошибку конфига кодом возврата не
-- показывает (ls-fonts и show-keys выходят с 0, show-keys ещё и молча печатает
-- встроенные привязки), а подделка под LuaJIT не видит ошибок Lua 5.4 и
-- config_builder. Поэтому здесь:
--   1. дословный контракт WT-LOAD-11 на файле репо для ОС хоста:
--      `wezterm --config-file <репо>/wezterm.lua ls-fonts` — stdout не пуст,
--      в stderr нет ERROR (на Windows ещё сценарий «рабочее дерево»: stderr пуст);
--   2. обёртка tests/wezterm/guard.lua для трёх троек: код 0 и маркер
--      `FORGE_CONFIG_OK <тройка>` (вид macOS и Linux на любом хосте);
--   3. сценарии WT-LOAD-11 о самом WezTerm, на которых держится способ проверки:
--      сломанный конфиг даёт код 0 и молчащий show-keys; ошибка синтаксиса,
--      выполнения или нет файла — пустой stdout ls-fonts и ERROR в stderr;
--      нет основного шрифта — предупреждение без ERROR.
-- Сценарии WT-LOAD-11 про сам установщик macOS проверяет
-- tests/install-macos.scenarios.sh (строка «Проверка:» спеки).
--
-- HOME, USERPROFILE и XDG — в песочнице <FORGE_SANDBOX>/wezterm (ограничение на
-- Windows — в tests/wezterm/real_wezterm.lua). Сломанные копии и обёртка
-- «нет шрифта» пишутся в <FORGE_SANDBOX>/wezterm/config-loading/ — производное.
-- Нет бинарника (FORGE_WEZTERM пуст / нет в PATH) — каждый случай SKIP с причиной.
--
-- Мутации (проверка самих проверок) — на копии wezterm.lua в .tests/: обёртка
-- ставит require('fake_wezterm').CONFIG_PATH на копию и делает dofile этого
-- файла. wezterm.lua репо не правится.
local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
dofile(r .. '/tests/lib/bootstrap.lua')
local B = require('bootstrap')
local T = require('check')
local F = require('fake_wezterm')
local RW = require('real_wezterm')

-- ---------------------------------------------------------------------------
-- Композиционный корень: бинарник, ОС хоста, проверяемый конфиг, песочница.
-- ---------------------------------------------------------------------------
local EXE = B.wezterm
local HOST_OS = os.getenv('FORGE_HOST_OS')
if HOST_OS == nil or HOST_OS == '' then
  local sys = vim.uv.os_uname().sysname
  HOST_OS = (sys == 'Windows_NT' and 'windows') or (sys == 'Darwin' and 'macos') or 'linux'
end
local CONFIG = F.CONFIG_PATH
local SANDBOX = B.sandbox .. '/wezterm'
local WORK = SANDBOX .. '/config-loading'
local ORDER = { 'windows', 'macos', 'linux' }
local MISSING_FONT = 'Forge Missing Font (WT-LOAD-11)'

if CONFIG ~= B.root .. '/wezterm.lua' then
  -- Не строка протокола: видна в логе прогона (мутации).
  io.stdout:write('конфиг под проверкой: ' .. CONFIG .. '\n')
end

-- ---------------------------------------------------------------------------
-- Помощники
-- ---------------------------------------------------------------------------
local ENV -- песочница создаётся только при наличии бинарника

local function write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local f = assert(io.open(path, 'wb'))
  f:write(content)
  f:close()
end

local function read(path)
  local f = assert(io.open(path, 'rb'))
  local s = f:read('*a')
  f:close()
  return s
end

local function ls_fonts(path)
  return RW.run(EXE, { '--config-file', path, 'ls-fonts' }, { env = ENV })
end

local function show_keys(path)
  return RW.run(EXE, { '--config-file', path, 'show-keys', '--lua' }, { env = ENV })
end

-- Регистр буквы после phys: в show-keys случаен от запуска к запуску
-- (design, решение 8) — для сравнения двух выводов приводится к верхнему.
local function norm_phys(s)
  return (s:gsub("'phys:(%a)'", function(c) return "'phys:" .. c:upper() .. "'" end))
end

-- Результат одного запуска ls-fonts на конфиге репо — общий для двух случаев.
local repo_ls_fonts
local function repo_run()
  repo_ls_fonts = repo_ls_fonts or ls_fonts(CONFIG)
  return repo_ls_fonts
end

-- Производные копии для сценариев о сломанном конфиге (только в песочнице).
local BROKEN -- { syntax, runtime, missing, empty, missing_font }
local function broken()
  if BROKEN then return BROKEN end
  local src = read(CONFIG)
  BROKEN = {
    -- Ошибка синтаксиса в первой строке: `<name> expected near '='`.
    syntax = WORK .. '/syntax.lua',
    -- Ошибка выполнения в первой строке.
    runtime = WORK .. '/runtime.lua',
    -- Файла нет (WT-LOAD-11: «ошибка синтаксиса, времени выполнения или нет файла»).
    missing = WORK .. '/missing.lua',
    -- Пустой конфиг: WezTerm на встроенных дефолтах — с ним сравнивается show-keys.
    empty = WORK .. '/empty.lua',
    -- Конфиг репо, у которого первое семейство font_with_fallback подменено на
    -- несуществующее: «шрифт из начала списка не установлен».
    missing_font = WORK .. '/missing-font.lua',
  }
  write(BROKEN.syntax, 'local = "WT-LOAD-11: сломанная копия"\n' .. src)
  write(BROKEN.runtime, 'error("WT-LOAD-11: ошибка выполнения в копии")\n' .. src)
  vim.uv.fs_unlink(BROKEN.missing)
  write(BROKEN.empty, 'return {}\n')
  write(BROKEN.missing_font, table.concat({
    '-- Производное config-loading.test.lua: конфиг из FORGE_CONFIG с несуществующим',
    '-- первым шрифтом. config.font — таблица { font = { { family = … }, … } }',
    '-- (проба 20240203: wezterm.font_with_fallback отдаёт изменяемую таблицу).',
    "local cfg = dofile(os.getenv('FORGE_CONFIG'))",
    "cfg.font.font[1].family = '" .. MISSING_FONT .. "'",
    'return cfg',
    '',
  }, '\n'))
  return BROKEN
end

-- ---------------------------------------------------------------------------
-- Случаи. Порядок: дословная проверка на файле репо, обёртка для трёх троек,
-- затем сценарии о самом WezTerm.
-- ---------------------------------------------------------------------------
local CASES = {}
local function case(name, fn, opts)
  CASES[#CASES + 1] = { name = name, fn = fn, host = opts and opts.host }
end

case('WT-LOAD-11 wezterm --config-file wezterm.lua ls-fonts: stdout не пуст, в stderr нет ERROR', function()
  local res = repo_run()
  T.ok(not res.timed_out, 'таймаут: ' .. RW.describe(res))
  T.ok(res.code == 0, 'ls-fonts: ' .. RW.describe(res))
  T.ok(vim.trim(res.stdout) ~= '', 'stdout пуст — WezTerm не загрузил конфиг: ' .. RW.describe(res))
  local errs = RW.error_lines(res.stderr)
  T.ok(#errs == 0, 'в stderr есть ERROR:\n' .. table.concat(errs, '\n'))
end)

case('WT-LOAD-11 рабочее дерево на Windows: ls-fonts перечисляет шрифты, stderr пуст', function()
  local res = repo_run()
  T.ok(res.code == 0 and res.stdout:find('font_with_fallback', 1, true) ~= nil,
    'stdout не перечисляет шрифты (нет font_with_fallback): ' .. RW.describe(res))
  T.eq(vim.trim(res.stderr), '', 'stderr ls-fonts')
end, { host = 'windows' })

for _, os_name in ipairs(ORDER) do
  local triple = F.TRIPLES[os_name]
  case(('WT-LOAD-11 обёртка guard.lua, %s: код 0 и маркер FORGE_CONFIG_OK %s'):format(os_name, triple), function()
    local res = RW.guard(EXE, CONFIG, triple, { 'ls-fonts' }, { env = ENV })
    T.ok(res.code == 0, 'конфиг не загрузился: ' .. RW.describe(res))
    T.eq(res.marker, triple, 'маркер FORGE_CONFIG_OK в stderr')
    T.ok(vim.trim(res.stdout) ~= '', 'stdout ls-fonts пуст: ' .. RW.describe(res))
    local errs = RW.error_lines(res.stderr)
    T.ok(#errs == 0, 'в stderr есть ERROR:\n' .. table.concat(errs, '\n'))
  end)
end

case('WT-LOAD-11 код возврата и show-keys ошибок не показывают: сломанный конфиг — код 0, show-keys молча печатает встроенные привязки', function()
  local b = broken()
  local lf = ls_fonts(b.syntax)
  T.ok(not lf.timed_out and lf.code == 0, 'ls-fonts на сломанной копии: ' .. RW.describe(lf))
  local sk = show_keys(b.syntax)
  T.ok(not sk.timed_out and sk.code == 0, 'show-keys на сломанной копии: ' .. RW.describe(sk))
  T.eq(vim.trim(sk.stderr), '', 'stderr show-keys на сломанной копии')
  local defaults = show_keys(b.empty)
  T.ok(defaults.code == 0 and vim.trim(defaults.stdout) ~= '', 'show-keys на пустом конфиге: ' .. RW.describe(defaults))
  T.ok(norm_phys(sk.stdout) == norm_phys(defaults.stdout),
    'show-keys на сломанной копии печатает не встроенные привязки (вывод ≠ выводу на `return {}`)')
end)

case('WT-LOAD-11 ошибка синтаксиса, выполнения или нет файла: ls-fonts — код 0, пустой stdout, строка с ERROR в stderr', function()
  local b = broken()
  local bad = {}
  for _, kind in ipairs({ 'syntax', 'runtime', 'missing' }) do
    local res = ls_fonts(b[kind])
    if res.timed_out or res.code ~= 0 or vim.trim(res.stdout) ~= '' or #RW.error_lines(res.stderr) == 0 then
      bad[#bad + 1] = kind .. ': ' .. RW.describe(res)
    end
  end
  T.ok(#bad == 0, table.concat(bad, '\n'))
end)

case('WT-LOAD-11 нет основного шрифта: в stderr только «Unable to load a font…», без ERROR, stdout не пуст', function()
  local b = broken()
  local env = vim.tbl_extend('force', ENV, { FORGE_CONFIG = CONFIG })
  local res = RW.run(EXE, { '--config-file', b.missing_font, 'ls-fonts' }, { env = env })
  T.ok(not res.timed_out and res.code == 0, 'ls-fonts: ' .. RW.describe(res))
  T.ok(vim.trim(res.stdout) ~= '', 'stdout пуст: ' .. RW.describe(res))
  local warned, other = 0, {}
  for line in res.stderr:gmatch('[^\n]+') do
    if line:find('^Unable to load a font specified by your font=')
      and line:find('Fallback(s) are being used instead', 1, true) then
      warned = warned + 1
    elseif vim.trim(line) ~= '' then
      other[#other + 1] = line
    end
  end
  T.ok(warned > 0, 'нет предупреждения «Unable to load a font…» — подмена шрифта не сработала: ' .. RW.describe(res))
  T.ok(#other == 0, 'в stderr есть другие строки:\n' .. table.concat(other, '\n'))
  T.ok(res.stderr:find(MISSING_FONT, 1, true) ~= nil, 'предупреждение не о подменённом шрифте ' .. MISSING_FONT)
end)

-- Самопроверка обёртки: без неё случаи «обёртка guard.lua» ничего не доказывают.
case('SELF: guard.lua на сломанной копии — код 3 и FORGE_CONFIG_ERROR с файлом и строкой', function()
  local b = broken()
  local res = RW.guard(EXE, b.syntax, F.TRIPLES.windows, { 'show-keys' }, { env = ENV })
  T.ok(res.code == 3, 'ожидался код 3: ' .. RW.describe(res))
  T.ok(res.marker == nil, 'маркер FORGE_CONFIG_OK при ошибке')
  -- Lua 5.4 укорачивает длинное имя файла в сообщении ('...' + хвост пути,
  -- LUA_IDSIZE), поэтому сверяется имя файла и строка, а не полный путь.
  local line = res.stderr:match('FORGE_CONFIG_ERROR: [^\n]*') or ''
  T.ok(line:find('syntax.lua:1:', 1, true) ~= nil,
    'нет `FORGE_CONFIG_ERROR: …syntax.lua:1: …` в stderr: ' .. RW.describe(res))
end)

-- ---------------------------------------------------------------------------
-- Прогон
-- ---------------------------------------------------------------------------
if EXE then ENV = RW.sandbox_env(SANDBOX) end

-- Сценарий другой ОС хоста (c.host) не выполняется и не пишется: это не SKIP,
-- он не про эту машину.
for _, c in ipairs(CASES) do
  if c.host == nil or c.host == HOST_OS then
    if EXE then
      T.check(c.name, c.fn)
    else
      T.skip(c.name, 'wezterm не найден (FORGE_WEZTERM пуст / нет в PATH) — проверка на настоящем бинарнике не выполнялась')
    end
  end
end

T.finish()
