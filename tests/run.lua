-- Единственный вход проверок (add-wezterm-spec-checks, design, решения 1, 2, 10, 12):
--
--   nvim -l tests/run.lua [набор…] [--id ID] [--update-golden] [--strict] [--registry ФАЙЛ]
--
-- Раннер только оркеструет: берёт файлы из tests/registry.lua, запускает каждый
-- отдельным процессом с таймаутом, разбирает строки `ok`/`FAIL`/`SKIP`,
-- выносит вердикт файла, сводит статусы по ID требований из openspec/specs,
-- пишет .tests/report.json и логи .tests/logs/<файл>.log. Всё в .tests/ —
-- производное: удаляется и пересобирается этой же командой.

-- ============================================================================
-- 0. Композиционный корень: вся энтропия раннера — здесь, ниже только данные.
--    ОС хоста, пути к инструментам, их версии, состояние git, время.
-- ============================================================================
local SELF_PATH = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):gsub('\\', '/')
local ROOT = assert(SELF_PATH:match('^(.*)/tests/run%.lua$'), 'run.lua должен лежать в <репо>/tests/')
package.path = ROOT .. '/tests/lib/?.lua;' .. package.path

local function exepath(name)
  local p = vim.fn.exepath(name)
  return p ~= '' and p or nil
end

-- Короткая команда для сбора сведений о хосте; nil, если запуск не удался.
local function probe(cmd)
  local ok, obj = pcall(vim.system, cmd, { text = true, timeout = 15000, cwd = ROOT })
  if not ok then return nil end
  local r = obj:wait()
  if r.code ~= 0 then return nil end
  return (r.stdout or ''):gsub('\r', '')
end

local UNAME = vim.uv.os_uname()
local HOST = {
  os = (UNAME.sysname == 'Windows_NT' and 'windows') or (UNAME.sysname == 'Darwin' and 'macos') or 'linux',
  uname = UNAME.sysname .. ' ' .. UNAME.release,
  nvim = vim.v.progpath,
  nvim_version = tostring(vim.version()),
  wezterm = exepath('wezterm'),
  wsl = UNAME.sysname == 'Windows_NT' and exepath('wsl') or nil,
  bash = exepath('bash'),
  git = exepath('git'),
  python = UNAME.sysname == 'Windows_NT' and exepath('python') or nil,
  bash32 = os.getenv('FORGE_BASH32'),
  started_at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
}
HOST.wezterm_version = HOST.wezterm and (probe({ HOST.wezterm, '--version' }) or ''):match('wezterm%s+(%S+)') or nil
if HOST.git then
  HOST.git_head = (probe({ HOST.git, 'rev-parse', 'HEAD' }) or ''):match('%x+')
  local st = probe({ HOST.git, 'status', '--porcelain' })
  if st ~= nil then HOST.git_dirty = st:match('%S') ~= nil end
end
local function now_ms() return vim.uv.hrtime() / 1e6 end
local T0 = now_ms()

-- Среда shell-наборов с shell = 'posix' (design, решение 9): bash + git +
-- python3 и путь репо внутри этой среды. На Windows это WSL (путь — через
-- wslpath), на macOS и Linux — сама система. Опрос ленивый и однократный:
-- WSL запускается, только когда выбран такой набор. Энтропия всё равно
-- определена здесь, в корне; LAUNCHERS ниже получают готовые данные.
-- $1 — корень репо, $2 = wsl — перевести путь через wslpath, $3 — ещё один
-- bash, у которого нужна версия (FORGE_BASH32 или bash из Homebrew). Пустых
-- аргументов нет: wsl.exe их отвергает (Wsl/Service/E_INVALIDARG), поэтому
-- «нет» — это '-'.
local POSIX_PROBE = [[
repo=$1
if [ "$2" = wsl ]; then
  repo=$(wslpath -a -u "$1" 2>/dev/null) || { echo "error=wslpath не перевёл путь $1"; exit 0; }
fi
echo "repo=$repo"
echo "bash=$BASH_VERSION"
[ -d "$repo/tests" ] || echo "error=каталог $repo/tests не виден"
for t in git python3; do command -v "$t" >/dev/null 2>&1 || echo "missing=$t"; done
if [ "$3" != - ]; then
  if [ -x "$3" ]; then echo "extra=$("$3" -c 'echo $BASH_VERSION' 2>/dev/null)"; else echo "extra_error=не исполняемый файл"; fi
fi
]]

local function run_posix_probe(cmd, where)
  local ok, obj = pcall(vim.system, cmd, { text = true, timeout = 30000, cwd = ROOT })
  if not ok then return { skip = where .. ': не запускается: ' .. tostring(obj) } end
  local r = obj:wait()
  if r.code == 124 and r.signal == 15 then return { skip = where .. ': не ответил за 30 с' } end
  if r.code ~= 0 then
    -- wsl.exe пишет свои ошибки в UTF-16LE: без NUL остаётся читаемый текст.
    local msg = ((r.stderr or '') .. (r.stdout or '')):gsub('%z', ''):gsub('\r', '')
    return { skip = ('%s: bash не запустился (код %d): %s'):format(where, r.code, vim.trim(msg):match('^[^\n]*') or '') }
  end
  local e = { missing = {} }
  for line in (r.stdout or ''):gsub('\r', ''):gmatch('[^\n]+') do
    local k, v = line:match('^([%w_]+)=(.*)$')
    if k == 'missing' then e.missing[#e.missing + 1] = v elseif k then e[k] = v end
  end
  if e.error then return { skip = where .. ': ' .. e.error } end
  if #e.missing > 0 then return { skip = where .. ': нет ' .. table.concat(e.missing, ', ') .. ' (нужны bash, git, python3)' } end
  e.bash_version = (e.bash or ''):match('^[%d.]+') or '?'
  e.extra = e.extra and (e.extra:match('^[%d.]+') or '?')
  e.where = where
  return e
end

local POSIX_ENV
local function posix_env()
  if POSIX_ENV then return POSIX_ENV end
  local e
  local bash32 = (HOST.bash32 ~= '' and HOST.bash32) or nil
  if HOST.os == 'windows' then
    if not HOST.wsl then
      e = { skip = 'wsl не найден в PATH: на Windows набор идёт в WSL (bash, git, python3)' }
    else
      e = run_posix_probe({ HOST.wsl, '-e', 'bash', '-c', POSIX_PROBE, 'forge-probe', ROOT, 'wsl', bash32 or '-' }, 'WSL')
      e.prefix, e.bash_path, e.extra_path = { HOST.wsl, '-e' }, 'bash', bash32
    end
  elseif HOST.os == 'macos' then
    -- /bin/bash — 3.2, целевой для установщика; bash из Homebrew — если есть.
    local brew = (HOST.bash and HOST.bash ~= '/bin/bash') and HOST.bash or nil
    e = run_posix_probe({ '/bin/bash', '-c', POSIX_PROBE, 'forge-probe', ROOT, '-', brew or '-' }, 'macOS')
    e.prefix, e.bash_path, e.extra_path = {}, '/bin/bash', brew
  elseif not HOST.bash then
    e = { skip = 'bash не найден в PATH' }
  else
    e = run_posix_probe({ HOST.bash, '-c', POSIX_PROBE, 'forge-probe', ROOT, '-', bash32 or '-' }, 'Linux')
    e.prefix, e.bash_path, e.extra_path = {}, HOST.bash, bash32
  end
  POSIX_ENV = e
  return e
end

local P = {
  registry = ROOT .. '/tests/registry.lua',
  out = ROOT .. '/.tests',
  logs = ROOT .. '/.tests/logs',
  sandbox = ROOT .. '/.tests/sandbox',
  report = ROOT .. '/.tests/report.json',
  guard = ROOT .. '/tests/wezterm/guard.lua',
  fixture = ROOT .. '/tests/wezterm/fixtures/default_key_tables.lua',
  version = ROOT .. '/tests/wezterm/VERSION',
}

local S = require('spec_index')
local matches = require('check').matches

-- ============================================================================
-- 1. Аргументы
-- ============================================================================
local SUITES = { 'unit', 'e2e', 'wezterm', 'install', 'trace', 'conpty' }
-- Без явных наборов идут все, кроме conpty: пробы через conpty.dll идут около
-- минуты, поэтому только по имени набора или вместе с --id.
local DEFAULT_SUITES = { 'unit', 'e2e', 'wezterm', 'install', 'trace' }
local USAGE = [[
Использование: nvim -l tests/run.lua [набор…] [--id ID] [--update-golden] [--strict] [--registry ФАЙЛ]
  набор            unit | e2e | wezterm | install | trace | conpty
                   (по умолчанию — все, кроме conpty; с --id — все)
  --id ID          только проверки требования: WT-CLIP — вся capability, WT-CLIP-1 — одно требование
  --update-golden  перезаписать эталоны и фикстуру (осознанное изменение, diff — в тот же коммит)
  --strict         UNCOVERED тоже валит прогон
  --registry ФАЙЛ  другой реестр вместо tests/registry.lua (самопроверка раннера)
  -h, --help       эта справка]]

local function usage_error(msg)
  io.stderr:write('run.lua: ' .. msg .. '\n' .. USAGE .. '\n')
  os.exit(2)
end

local ARGS = { suites = {}, id = nil, update_golden = false, strict = false, registry = P.registry }
do
  local argv, i = arg or {}, 1
  local is_suite = {}
  for _, s in ipairs(SUITES) do is_suite[s] = true end
  while i <= #argv do
    local a = argv[i]
    if a == '-h' or a == '--help' then
      io.stdout:write(USAGE .. '\n')
      os.exit(0)
    elseif a == '--id' or a:match('^%-%-id=') then
      local v = a:match('^%-%-id=(.*)$')
      if not v then i = i + 1; v = argv[i] end
      if not v or not (v:match('^%u+%-%u+$') or v:match('^%u+%-%u+%-%d+$')) then
        usage_error('--id ждёт ID требования или его префикс (WT-CLIP, WT-CLIP-1), получено ' .. tostring(v))
      end
      ARGS.id = v
    elseif a == '--update-golden' then
      ARGS.update_golden = true
    elseif a == '--strict' then
      ARGS.strict = true
    elseif a == '--registry' then
      i = i + 1
      if not argv[i] then usage_error('--registry ждёт путь к файлу') end
      ARGS.registry = vim.fn.fnamemodify(argv[i], ':p'):gsub('\\', '/')
    elseif is_suite[a] then
      ARGS.suites[#ARGS.suites + 1] = a
    else
      usage_error('неизвестный аргумент ' .. a)
    end
    i = i + 1
  end
  if #ARGS.suites == 0 then ARGS.suites = vim.deepcopy(ARGS.id and SUITES or DEFAULT_SUITES) end
end

-- ============================================================================
-- 2. Реестр
-- ============================================================================
local function load_registry(path)
  local ok, reg = pcall(dofile, path)
  if not ok then usage_error('реестр ' .. path .. ' не загружается: ' .. tostring(reg)) end
  if type(reg) ~= 'table' then usage_error('реестр ' .. path .. ' должен вернуть список') end
  local known = {}
  for _, s in ipairs(SUITES) do known[s] = true end
  for n, e in ipairs(reg) do
    if type(e.file) ~= 'string' or not known[e.suite] then
      usage_error(('запись %d реестра: нужны file и suite (%s)'):format(n, table.concat(SUITES, '|')))
    end
    e.kind = e.kind or 'lua'
    e.timeout = e.timeout or 60
    if e.kind ~= 'lua' and e.kind ~= 'sh' and e.kind ~= 'py' then
      usage_error(('запись %d: kind %s не поддержан'):format(n, e.kind))
    end
    if e.kind == 'sh' and e.shell ~= 'posix' then
      usage_error(('запись %d (%s): у shell-набора нужна среда shell = \'posix\', получено %s'):format(n, e.file, tostring(e.shell)))
    end
  end
  return reg
end

local REGISTRY = load_registry(ARGS.registry)

-- ============================================================================
-- 3. Файловые помощники (.tests/ — только производное)
-- ============================================================================
local function read(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

local function write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local f = assert(io.open(path, 'wb'))
  f:write(content)
  f:close()
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function clear_logs()
  vim.fn.mkdir(P.logs, 'p')
  local h = vim.uv.fs_scandir(P.logs)
  while h do
    local name = vim.uv.fs_scandir_next(h)
    if not name then break end
    if name:match('%.log$') then vim.uv.fs_unlink(P.logs .. '/' .. name) end
  end
end

local function out(line) io.stdout:write(line, '\n'); io.stdout:flush() end

-- Окружение для настоящего wezterm: HOME, USERPROFILE и XDG — в песочнице,
-- чтобы файлы владельца не влияли (design, решение 7).
local function wezterm_env()
  local sb = P.sandbox .. '/wezterm'
  local env = {
    HOME = sb .. '/home',
    USERPROFILE = sb .. '/home',
    XDG_CONFIG_HOME = sb .. '/xdg/config',
    XDG_DATA_HOME = sb .. '/xdg/data',
    XDG_CACHE_HOME = sb .. '/xdg/cache',
    XDG_STATE_HOME = sb .. '/xdg/state',
    XDG_RUNTIME_DIR = sb .. '/xdg/runtime',
  }
  for _, d in pairs(env) do vim.fn.mkdir(d, 'p') end
  return env
end

-- ============================================================================
-- 4. Запуск файла: процесс на файл, таймаут, разбор строк, вердикт
-- ============================================================================
local CHILD_ENV = {
  -- Общий compiler cache одного прогона на native FS, не на Docker bind mount.
  FORGE_E2E_GO_CACHE = vim.env.FORGE_E2E_GO_CACHE or (vim.fn.tempname() .. '-forge-go-cache'),
  FORGE_REPO = ROOT,
  FORGE_TEST_ID = ARGS.id or '',
  FORGE_UPDATE_GOLDEN = ARGS.update_golden and '1' or '',
  FORGE_SANDBOX = P.sandbox,
  FORGE_WEZTERM = HOST.wezterm or '',
  FORGE_HOST_OS = HOST.os,
}

-- Способ запуска по kind: { skip = причина } (весь файл) или
-- { runs = { прогон… }, cleanup = fn(каталог) → команда | nil }.
-- Прогон: { label?, slug?, cmd = {...}, env? } | { label, slug, skip = причина }
-- | { label, slug, fail = причина }. У каждого прогона — своя запись в
-- отчёте, свой лог и свой вердикт; ID из строк `Проверка:` получают их все.
local LAUNCHERS = {}

function LAUNCHERS.lua(_, abs)
  return { runs = { { cmd = { HOST.nvim, '-l', abs } } } }
end

-- Python-наборы — пробы через conpty.dll (add-nvim-chords-on-windows, design,
-- решение 6): `python <файл>`, протокол строк тот же, фильтр — FORGE_TEST_ID.
-- Не Windows или нет python в PATH — SKIP всего набора.
function LAUNCHERS.py(_, abs)
  if HOST.os ~= 'windows' then return { skip = 'набор только для Windows (conpty.dll)' } end
  if not HOST.python then return { skip = 'python не найден в PATH' } end
  return { runs = { { cmd = { HOST.python, abs }, env = { PYTHONIOENCODING = 'utf-8' } } } }
end

-- Shell-наборы, shell = 'posix' (design, решение 9). Контракт скрипта:
-- `<скрипт> <репо> [bash под проверкой]`, нужны bash, git, python3.
--   Windows — `wsl -e bash`, путь репо — через wslpath (bash из WSL) плюс
--             ветка bash 3.2: FORGE_BASH32=<путь в WSL>;
--   macOS   — /bin/bash (3.2) плюс bash из Homebrew, если он есть;
--   Linux   — bash плюс ветка FORGE_BASH32.
-- Нет среды — SKIP всего набора. bash 3.2 — целевой для установщика macOS
-- (openspec/config.yaml), поэтому незаданная ветка FORGE_BASH32 — SKIP этой
-- ветки, а не молчаливый пропуск: ID набора тогда SKIP, а не PASS. Заданный,
-- но неисполняемый FORGE_BASH32 — FAIL (ошибка настройки, а не нет среды).
function LAUNCHERS.sh(e)
  local pe = posix_env()
  if pe.skip then return { skip = pe.skip } end
  local script = pe.repo .. '/' .. e.file
  local function cmd(bash, ...)
    return vim.list_extend(vim.list_extend(vim.deepcopy(pe.prefix), { bash, script, pe.repo }), { ... })
  end
  local runs = {}
  if HOST.os == 'macos' then
    runs[1] = { slug = 'bin-bash', label = ('bash %s (/bin/bash)'):format(pe.bash_version), cmd = cmd('/bin/bash', '/bin/bash') }
    if pe.extra_path then
      local brew = { slug = 'homebrew', label = 'bash из Homebrew (' .. pe.extra_path .. ')' }
      if pe.extra_error then
        brew.fail = pe.extra_path .. ': ' .. pe.extra_error
      else
        brew.label = ('bash %s (%s)'):format(pe.extra, pe.extra_path)
        brew.cmd = cmd(pe.extra_path, pe.extra_path)
      end
      runs[2] = brew
    end
  else
    runs[1] = { slug = 'bash', label = ('bash %s (%s)'):format(pe.bash_version, pe.where), cmd = cmd(pe.bash_path) }
    local b32 = { slug = 'bash32', label = ('bash 3.2 (%s, FORGE_BASH32)'):format(pe.where) }
    if not pe.extra_path then
      b32.skip = ('ветка bash 3.2 не запускалась: FORGE_BASH32 не задан (путь к bash 3.2 в %s)'):format(pe.where)
    elseif pe.extra_error then
      b32.fail = ('FORGE_BASH32=%s: %s в %s'):format(pe.extra_path, pe.extra_error, pe.where)
      -- Git Bash (MSYS) переписывает значения переменных, начинающиеся с `/`,
      -- в пути Windows при запуске nvim.exe: /home/… → C:/Program Files/Git/home/…
      -- Путь Windows здесь всегда ошибка (нужен путь внутри WSL) — назвать причину.
      if HOST.os == 'windows' and pe.extra_path:match('^%a:[/\\]') then
        b32.fail = b32.fail .. ' — это путь Windows, а нужен путь внутри WSL; если его переписал Git Bash,'
          .. ' запускай с MSYS2_ENV_CONV_EXCL=FORGE_BASH32 (tests/README.md, «Shell-наборы»)'
      end
    else
      b32.label = ('bash %s (%s, FORGE_BASH32)'):format(pe.extra, pe.where)
      b32.cmd = cmd(pe.bash_path, pe.extra_path)
    end
    runs[2] = b32
  end
  return {
    runs = runs,
    -- Каталог вывода набора `(outputs in /tmp/…)`: после PASS удаляется (иначе
    -- каждый прогон и каждый коммит с хуком оставляет его в /tmp), после FAIL
    -- остаётся для разбора — путь в логе.
    cleanup = function(dir)
      return vim.list_extend(vim.deepcopy(pe.prefix), { 'rm', '-rf', '--', dir })
    end,
  }
end

local function parse_cases(stdout)
  local cases, last = {}, nil
  for line in (stdout .. '\n'):gmatch('([^\n]*)\n') do
    line = line:gsub('\r$', '')
    local name = line:match('^  ok   (.-)%s*$')
    if name then
      last = { status = 'ok', name = name }
      cases[#cases + 1] = last
    else
      local status, rest = line:match('^  (FAIL) (.*)$')
      if not status then status, rest = line:match('^  (SKIP) (.*)$') end
      if status then
        local n, d = rest:match('^(.-)  %-%- (.*)$')
        last = { status = status, name = vim.trim(n or rest), detail = d }
        cases[#cases + 1] = last
      else
        local cont = line:match('^      | (.*)$')
        if cont and last and last.detail then last.detail = last.detail .. '\n' .. cont else last = nil end
      end
    end
  end
  return cases
end

local function file_verdict(res, cases)
  local n = { ok = 0, FAIL = 0, SKIP = 0 }
  for _, c in ipairs(cases) do n[c.status] = n[c.status] + 1 end
  if res.timed_out then return 'FAIL', ('таймаут %d с'):format(res.timeout), true end
  if res.code ~= 0 then
    if n.FAIL > 0 then return 'FAIL', ('%d FAIL, код возврата %d'):format(n.FAIL, res.code) end
    return 'FAIL', ('код возврата %d без строк FAIL'):format(res.code), true
  end
  if n.FAIL > 0 then return 'FAIL', ('%d FAIL при коде возврата 0'):format(n.FAIL) end
  if #cases == 0 then
    if ARGS.id then return 'NONE', 'нет случаев под --id ' .. ARGS.id end
    return 'FAIL', 'проверки не выполнялись (код 0, ни одной строки)', true
  end
  if n.ok == 0 then return 'SKIP', 'все случаи SKIP' end
  return 'PASS'
end

local function log_name(file, slug)
  return (file:gsub('^%.', '_'):gsub('[/\\]', '__')) .. (slug and ('@' .. slug) or '') .. '.log'
end

-- Один прогон файла: процесс, таймаут, разбор строк, вердикт, лог.
local function run_process(e, run, launch, r)
  local env = vim.tbl_extend('force', CHILD_ENV, run.env or {})
  local t0 = now_ms()
  local ok, obj = pcall(vim.system, run.cmd, { cwd = ROOT, env = env, text = true, timeout = e.timeout * 1000 })
  local res
  if ok then
    res = obj:wait()
  else
    res = { code = -1, stdout = '', stderr = 'не удалось запустить: ' .. tostring(obj) }
  end
  r.duration_ms = math.floor(now_ms() - t0)
  r.exit_code, r.signal = res.code, res.signal
  local timed_out = res.code == 124 and res.signal == 15
  local stdout = (res.stdout or ''):gsub('\r\n', '\n')
  local stderr = (res.stderr or ''):gsub('\r\n', '\n')
  r.cases = parse_cases(stdout)
  r.verdict, r.reason, r.abnormal = file_verdict({ code = res.code, timed_out = timed_out, timeout = e.timeout }, r.cases)
  if r.abnormal then
    local tail = {}
    for line in stderr:gmatch('[^\n]+') do tail[#tail + 1] = line end
    r.stderr_tail = table.concat(tail, '\n', math.max(1, #tail - 5))
  end
  local outputs_line
  local outdir = launch.cleanup and stdout:match('%(outputs in (/tmp/[%w_][%w%._%-]*)%)')
  if outdir then
    r.outputs = outdir
    if r.verdict == 'PASS' then
      local cok, cobj = pcall(vim.system, launch.cleanup(outdir), { text = true, timeout = 30000, cwd = ROOT })
      r.outputs_removed = cok and cobj:wait().code == 0
      outputs_line = 'каталог вывода: ' .. outdir .. (r.outputs_removed and ' (удалён после PASS)' or ' (удалить не удалось)')
    else
      outputs_line = 'каталог вывода: ' .. outdir .. ' (оставлен для разбора)'
    end
  end
  r.log = '.tests/logs/' .. log_name(e.file, run.slug)
  local env_lines = {}
  for k, v in vim.spairs(env) do env_lines[#env_lines + 1] = ('%s=%s'):format(k, v) end
  local log = { 'файл: ' .. e.file .. '  (набор ' .. e.suite .. ', ' .. e.kind .. ', таймаут ' .. e.timeout .. ' с)' }
  if r.variant then log[#log + 1] = 'прогон: ' .. r.variant end
  vim.list_extend(log, {
    'команда: ' .. table.concat(run.cmd, ' '),
    'окружение: ' .. table.concat(env_lines, ' '),
    ('код возврата: %s, сигнал: %s, %d мс'):format(tostring(res.code), tostring(res.signal), r.duration_ms),
    'вердикт: ' .. r.verdict .. (r.reason and (' — ' .. r.reason) or ''),
  })
  if outputs_line then log[#log + 1] = outputs_line end
  vim.list_extend(log, { '--- stdout ---', stdout, '--- stderr ---', stderr })
  write(ROOT .. '/' .. r.log, table.concat(log, '\n'))
end

-- Запись реестра → список записей отчёта: по одной на прогон (у shell-набора
-- их может быть несколько — ветки bash), иначе одна.
local function run_entry(e, index)
  local abs = ROOT .. '/' .. e.file
  local function rec(fields)
    return vim.tbl_extend('force', { file = e.file, suite = e.suite, kind = e.kind, cases = {} }, fields)
  end
  if not exists(abs) then
    return { rec({ verdict = 'FAIL', reason = 'зарегистрирован, но файла нет', abnormal = true }) }
  end
  if ARGS.id and e.kind == 'sh' then
    -- shell-набор не знает фильтра: запускается, только если покрывает ID под --id.
    local hit = false
    for _, id in ipairs(index.path_refs[e.file] or {}) do
      if matches(id, ARGS.id) then hit = true end
    end
    if not hit then
      return { rec({ verdict = 'NONE', reason = 'нет ID под --id ' .. ARGS.id }) }
    end
  end
  local launch = LAUNCHERS[e.kind](e, abs)
  if launch.skip then
    return { rec({ verdict = 'SKIP', reason = launch.skip }) }
  end
  local records = {}
  for _, run in ipairs(launch.runs) do
    local r = rec({ variant = run.label })
    if run.skip then
      r.verdict, r.reason = 'SKIP', run.skip
    elseif run.fail then
      r.verdict, r.reason, r.abnormal = 'FAIL', run.fail, true
    else
      run_process(e, run, launch, r)
    end
    records[#records + 1] = r
  end
  return records
end

-- ============================================================================
-- 5. Фикстура встроенных таблиц (--update-golden, design, решение 3)
-- ============================================================================
local function update_fixture()
  if not HOST.wezterm then return { status = 'SKIP', reason = 'wezterm не найден в PATH' } end
  local want = vim.trim(read(P.version) or '')
  if HOST.wezterm_version ~= want then
    return { status = 'SKIP', reason = ('wezterm %s, а tests/wezterm/VERSION — %s'):format(tostring(HOST.wezterm_version), want) }
  end
  local before = read(P.fixture)
  vim.fn.mkdir(vim.fn.fnamemodify(P.fixture, ':h'), 'p')
  local env = wezterm_env()
  env.FORGE_DUMP_KEY_TABLES = P.fixture
  local cmd = { HOST.wezterm, '--config-file', P.guard, 'show-keys' }
  local ok, obj = pcall(vim.system, cmd, { cwd = ROOT, env = env, text = true, timeout = 60000 })
  if not ok then return { status = 'FAIL', reason = tostring(obj) } end
  local res = obj:wait()
  local after = read(P.fixture)
  if res.code ~= 0 or not after or not after:match('^%-%- ') then
    return { status = 'FAIL', reason = ('код %s: %s'):format(tostring(res.code), vim.trim(res.stderr or '')) }
  end
  return { status = 'ok', changed = before ~= after }
end

-- ============================================================================
-- 6. Прогон
-- ============================================================================
local INDEX = S.build(ROOT)
clear_logs()

local shown_head = HOST.git_head and HOST.git_head:sub(1, 7) or '?'
out(('nvim -l tests/run.lua — %s, %s, nvim %s, WezTerm %s, HEAD %s%s'):format(
  ROOT, HOST.os, HOST.nvim_version, HOST.wezterm_version or 'нет', shown_head,
  HOST.git_dirty and ' (грязное дерево)' or ''))
out('наборы: ' .. table.concat(ARGS.suites, ', ') .. (ARGS.id and ('; --id ' .. ARGS.id) or '')
  .. (ARGS.update_golden and '; --update-golden' or '') .. (ARGS.strict and '; --strict' or ''))

local FIXTURE
if ARGS.update_golden then
  FIXTURE = update_fixture()
  out(('== фикстура %s: %s'):format('tests/wezterm/fixtures/default_key_tables.lua',
    FIXTURE.status == 'ok' and (FIXTURE.changed and 'обновлена' or 'без изменений')
    or (FIXTURE.status .. ' — ' .. FIXTURE.reason)))
end

local selected_suite = {}
for _, s in ipairs(ARGS.suites) do selected_suite[s] = true end

local function print_record(r)
  if r.verdict == 'NONE' then
    out(('== %s: %s — %s'):format(r.suite, r.file, r.reason))
    return
  end
  out(('== %s: %s%s'):format(r.suite, r.file, r.variant and (' [' .. r.variant .. ']') or ''))
  for _, c in ipairs(r.cases) do
    if c.status == 'ok' then out('  ok   ' .. c.name)
    else
      local first = (c.detail or ''):match('^[^\n]*') or ''
      out(('  %s %s%s'):format(c.status, c.name, first ~= '' and ('  -- ' .. first) or ''))
    end
  end
  if r.stderr_tail and r.stderr_tail ~= '' then
    for line in r.stderr_tail:gmatch('[^\n]+') do out('      stderr| ' .. line) end
  end
  local n = { ok = 0, FAIL = 0, SKIP = 0 }
  for _, c in ipairs(r.cases) do n[c.status] = n[c.status] + 1 end
  out(('   → %s%s  (%d ok, %d FAIL, %d SKIP%s)'):format(r.verdict, r.reason and (' — ' .. r.reason) or '',
    n.ok, n.FAIL, n.SKIP, r.duration_ms and (('; %.1f с'):format(r.duration_ms / 1000)) or ''))
  if r.outputs and not r.outputs_removed then out('   каталог вывода: ' .. r.outputs) end
end

local FILES = {}
for _, e in ipairs(REGISTRY) do
  if selected_suite[e.suite] then
    for _, r in ipairs(run_entry(e, INDEX)) do
      FILES[#FILES + 1] = r
      print_record(r)
    end
  end
end

-- ============================================================================
-- 7. Сводка по ID
-- ============================================================================
local BY_ID, UNKNOWN = {}, {}
local function add_result(id, rec)
  BY_ID[id] = BY_ID[id] or {}
  table.insert(BY_ID[id], rec)
end
local CASE_STATUS = { ok = 'ok', FAIL = 'FAIL', SKIP = 'SKIP', PASS = 'ok' }

for _, r in ipairs(FILES) do
  local seen = {}
  for _, c in ipairs(r.cases) do
    c.ids = S.leading_ids(c.name)
    for _, id in ipairs(c.ids) do
      seen[id] = true
      add_result(id, { status = c.status, name = c.name, file = r.file, detail = c.detail })
      if not INDEX:known(id, 'tests') then
        UNKNOWN[#UNKNOWN + 1] = { id = id, file = r.file, name = c.name }
      end
    end
  end
  if r.abnormal then
    -- Файл упал целиком: его ok-строкам верить нельзя.
    for id in pairs(seen) do
      add_result(id, { status = 'FAIL', name = '(файл) ' .. r.reason, file = r.file })
    end
  end
  if r.kind == 'sh' and r.verdict ~= 'NONE' then
    -- ID shell-набора — из строк `Проверка:` спек; их статус — вердикт набора.
    for _, id in ipairs(INDEX.path_refs[r.file] or {}) do
      add_result(id, { status = CASE_STATUS[r.verdict] or r.verdict, name = r.file .. ' (набор целиком)',
        file = r.file, detail = r.reason, via_proverka = true })
    end
  end
end

local IDS, COUNTS = {}, { PASS = 0, FAIL = 0, SKIP = 0, MANUAL = 0, UNCOVERED = 0 }
local NO_PROVERKA = {}
for _, id in ipairs(INDEX.order) do
  if matches(id, ARGS.id) then
    local req = INDEX.ids[id]
    local res = BY_ID[id] or {}
    local n = { ok = 0, FAIL = 0, SKIP = 0 }
    for _, x in ipairs(res) do n[x.status] = (n[x.status] or 0) + 1 end
    local auto
    if #res > 0 then
      auto = (n.FAIL > 0 and 'FAIL') or (n.ok == #res and 'PASS') or 'SKIP'
    end
    local manual = INDEX.manual.by_id[id]
    local status = (auto == 'FAIL' and 'FAIL') or (manual and 'MANUAL') or auto or 'UNCOVERED'
    COUNTS[status] = COUNTS[status] + 1
    local proverka_paths = {}
    for _, p in ipairs(req.proverka) do
      for _, path in ipairs(p.paths) do proverka_paths[path] = true end
    end
    local missing = {}
    for _, x in ipairs(res) do
      if not x.via_proverka and not proverka_paths[x.file] and not vim.tbl_contains(missing, x.file) then
        missing[#missing + 1] = x.file
      end
    end
    if #missing > 0 then NO_PROVERKA[#NO_PROVERKA + 1] = { id = id, files = missing } end
    local proverka_text = {}
    for _, p in ipairs(req.proverka) do proverka_text[#proverka_text + 1] = p.text end
    IDS[id] = {
      status = status, auto = auto, counts = n, checks = res,
      manual = manual, capability = req.capability, title = req.title, proverka = proverka_text,
    }
  end
end

out('')
out(('== Сводка по ID (%s)'):format(ARGS.id and ('--id ' .. ARGS.id) or ('%d из openspec/specs'):format(#INDEX.order)))
local cap
for _, id in ipairs(INDEX.order) do
  local x = IDS[id]
  if x then
    if x.capability ~= cap then
      cap = x.capability
      out(cap)
    end
    local parts = {}
    if x.auto then
      local first_fail
      for _, c in ipairs(x.checks) do if c.status == 'FAIL' and not first_fail then first_fail = c.name end end
      parts[#parts + 1] = ('авто: %s (%d ok, %d FAIL, %d SKIP)%s'):format(x.auto, x.counts.ok, x.counts.FAIL,
        x.counts.SKIP, first_fail and (' — ' .. first_fail) or '')
    end
    if x.manual then
      local m = {}
      for _, e in ipairs(x.manual) do
        m[#m + 1] = ('%s %s — %s'):format(e.file, e.item or '?', e.last or 'не проверялось')
      end
      parts[#parts + 1] = 'вручную: ' .. table.concat(m, '; ')
    end
    out((('  %-12s %-9s %s'):format(id, x.status, table.concat(parts, '; ')):gsub('%s+$', '')))
  end
end

if not INDEX.manual.present then
  out('Ручных чек-листов нет (tests/manual/*.md): статусов MANUAL из чек-листов нет.')
end
if #NO_PROVERKA > 0 then
  out('Есть автоматическая проверка, нет строки «Проверка:» с этим файлом в спеке:')
  for _, x in ipairs(NO_PROVERKA) do out(('  %-12s %s'):format(x.id, table.concat(x.files, ', '))) end
end
if #UNKNOWN > 0 then
  out('Неизвестные ID в именах проверок (нет в openspec/specs и ADDED открытых changes):')
  for _, u in ipairs(UNKNOWN) do out(('  %-12s %s: %s'):format(u.id, u.file, u.name)) end
end

-- ============================================================================
-- 8. Итог, отчёт, код возврата
-- ============================================================================
local FC = { PASS = 0, FAIL = 0, SKIP = 0, NONE = 0 }
local executed, run_files = 0, {}
for _, r in ipairs(FILES) do
  FC[r.verdict] = FC[r.verdict] + 1
  executed = executed + #r.cases
  if r.verdict ~= 'NONE' then run_files[r.file] = true end
end
local n_runs = #FILES - FC.NONE
local n_run_files = vim.tbl_count(run_files)

local failures = {}
if FC.FAIL > 0 then failures[#failures + 1] = ('файлов с FAIL: %d'):format(FC.FAIL) end
if FIXTURE and FIXTURE.status == 'FAIL' then failures[#failures + 1] = 'фикстура не выгрузилась' end
if ARGS.strict and COUNTS.UNCOVERED > 0 then
  failures[#failures + 1] = ('--strict: UNCOVERED %d'):format(COUNTS.UNCOVERED)
end
if ARGS.id and executed == 0 and FC.SKIP == 0 then
  failures[#failures + 1] = 'под --id ' .. ARGS.id .. ' не выполнено ни одной проверки'
end

local n_ids = 0
for _ in pairs(IDS) do n_ids = n_ids + 1 end
local duration_ms = math.floor(now_ms() - T0)

local report = {
  provenance = {
    command = 'nvim -l tests/run.lua ' .. table.concat(arg or {}, ' '),
    root = ROOT,
    head = HOST.git_head,
    dirty = HOST.git_dirty,
    os = HOST.os,
    uname = HOST.uname,
    nvim = HOST.nvim_version,
    wezterm = HOST.wezterm_version,
    wezterm_path = HOST.wezterm,
    started_at = HOST.started_at,
    duration_ms = duration_ms,
    suites = ARGS.suites,
    id = ARGS.id,
    strict = ARGS.strict,
    update_golden = ARGS.update_golden,
    registry = ARGS.registry,
    -- Среда shell-наборов, если опрашивалась: где (WSL/macOS/Linux), путь
    -- репо в ней, версии bash, либо причина SKIP.
    posix_env = POSIX_ENV and {
      where = POSIX_ENV.where, repo = POSIX_ENV.repo, bash = POSIX_ENV.bash_version,
      extra_bash = POSIX_ENV.extra_path, extra_bash_version = POSIX_ENV.extra, skip = POSIX_ENV.skip,
    } or nil,
  },
  files = FILES,
  ids = IDS,
  summary = {
    ids_total = n_ids,
    ids = COUNTS,
    files = FC,
    cases = executed,
    ok = #failures == 0,
    failures = failures,
  },
  checks_without_proverka = NO_PROVERKA,
  unknown_ids = UNKNOWN,
  manual_checklists = { present = INDEX.manual.present, files = vim.fn.sort(vim.tbl_keys(INDEX.manual.files)) },
  fixture = FIXTURE,
}
write(P.report, vim.json.encode(report, { indent = '  ', sort_keys = true }) .. '\n')

out('')
out(('== Итог: файлов %d%s — PASS %d, FAIL %d, SKIP %d%s | ID %d — PASS %d, FAIL %d, SKIP %d, MANUAL %d, UNCOVERED %d | %.1f с'):format(
  n_run_files, n_runs ~= n_run_files and (' (прогонов ' .. n_runs .. ')') or '',
  FC.PASS, FC.FAIL, FC.SKIP, FC.NONE > 0 and (', без случаев под --id ' .. FC.NONE) or '',
  n_ids, COUNTS.PASS, COUNTS.FAIL, COUNTS.SKIP, COUNTS.MANUAL, COUNTS.UNCOVERED, duration_ms / 1000))
for _, f in ipairs(failures) do out('   FAIL: ' .. f) end
out('Отчёт: .tests/report.json, логи: .tests/logs/')
os.exit(#failures == 0 and 0 or 1)
