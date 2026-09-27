-- Запуск НАСТОЯЩЕГО wezterm из проверок набора `wezterm` (add-wezterm-spec-checks,
-- design, решения 7 и 8). Общий для config-loading.test.lua и snapshot.test.lua:
-- песочница HOME/USERPROFILE/XDG, процесс с таймаутом, вызов через обёртку
-- tests/wezterm/guard.lua. Это граница с внешней системой (бинарник, ОС) —
-- проверки получают отсюда только данные { code, stdout, stderr, … }.
--
--   local RW = require('real_wezterm')
--   local env = RW.sandbox_env(B.sandbox .. '/wezterm')
--   local r = RW.run(B.wezterm, { '--config-file', path, 'ls-fonts' }, { env = env })
--   local g = RW.guard(B.wezterm, config_path, triple, { 'show-keys', '--lua' }, { env = env })
--
-- Путь к бинарнику, песочница и таймаут приходят параметрами: энтропию читает
-- файл проверок (его композиционный корень), не этот модуль.
--
-- Ограничение песочницы (проба 20240203, Windows, 2026-09-27): на Windows
-- wezterm.home_dir берётся из профиля пользователя (C:\Users\<имя>), а не из
-- USERPROFILE/HOME, поэтому wezterm.lua там читает настоящий
-- ~/.wezterm_forge_window.json владельца. Он только читается (разбор под pcall),
-- записи бывают лишь в колбэках, которые show-keys/ls-fonts не вызывают, а
-- размер шрифта в вывод show-keys и ls-fonts не попадает — на вердикт это не
-- влияет. На macOS и Linux home_dir следует HOME.

local B = require('bootstrap')

local M = {}

M.GUARD = B.root .. '/tests/wezterm/guard.lua'
M.DEFAULT_TIMEOUT = 30 -- секунд на один вызов wezterm; обычно ~0,3 с

--- Окружение песочницы для настоящего wezterm: HOME, USERPROFILE и XDG — в dir
--- (каталоги создаются), чтобы файлы владельца (~/.wezterm.lua, ~/.config/wezterm)
--- не влияли. Те же переменные, что у run.lua (wezterm_env, выгрузка фикстуры).
function M.sandbox_env(dir)
  local env = {
    HOME = dir .. '/home',
    USERPROFILE = dir .. '/home',
    XDG_CONFIG_HOME = dir .. '/xdg/config',
    XDG_DATA_HOME = dir .. '/xdg/data',
    XDG_CACHE_HOME = dir .. '/xdg/cache',
    XDG_STATE_HOME = dir .. '/xdg/state',
    XDG_RUNTIME_DIR = dir .. '/xdg/runtime',
  }
  for _, d in pairs(env) do vim.fn.mkdir(d, 'p') end
  return env
end

local function lf(s)
  return ((s or ''):gsub('\r\n', '\n'))
end

--- Выполнить wezterm с аргументами args.
--- opts.env — переменные поверх унаследованного окружения; opts.timeout — секунды.
--- → { code, signal, stdout, stderr, timed_out, cmd }; stdout/stderr с '\n'.
function M.run(exe, args, opts)
  opts = opts or {}
  local cmd = { exe }
  vim.list_extend(cmd, args)
  local timeout = opts.timeout or M.DEFAULT_TIMEOUT
  local ok, obj = pcall(vim.system, cmd, { cwd = B.root, env = opts.env, text = true, timeout = timeout * 1000 })
  if not ok then
    return { code = -1, stdout = '', stderr = 'не удалось запустить: ' .. tostring(obj), cmd = cmd }
  end
  local r = obj:wait()
  return {
    code = r.code,
    signal = r.signal,
    stdout = lf(r.stdout),
    stderr = lf(r.stderr),
    -- vim.system по таймауту убивает процесс: код 124, сигнал 15 (как в run.lua).
    timed_out = r.code == 124 and r.signal == 15,
    cmd = cmd,
  }
end

--- Загрузить config_path через обёртку guard.lua с подменой тройки и выполнить
--- подкоманду subargs (например { 'show-keys', '--lua' }). Код 3 и
--- `FORGE_CONFIG_ERROR: …` в stderr — конфиг не загрузился (design, решение 7).
--- → то же, что run, плюс marker = тройка из строки `FORGE_CONFIG_OK <тройка>` или nil.
function M.guard(exe, config_path, triple, subargs, opts)
  opts = opts or {}
  local env = vim.tbl_extend('force', opts.env or {}, { FORGE_CONFIG = config_path, FORGE_TARGET = triple })
  local args = { '--config-file', M.GUARD }
  vim.list_extend(args, subargs)
  local r = M.run(exe, args, { env = env, timeout = opts.timeout })
  for line in r.stderr:gmatch('[^\n]+') do
    local t = line:match('^FORGE_CONFIG_OK (%S+)%s*$')
    if t then r.marker = t end
  end
  return r
end

--- Версия из `wezterm --version` («wezterm 20240203-110809-5046fc22» → вторая часть) или nil.
function M.version(exe)
  local r = M.run(exe, { '--version' }, { timeout = 15 })
  if r.code ~= 0 then return nil end
  return r.stdout:match('wezterm%s+(%S+)')
end

--- Строки stderr, в которых есть ERROR (признак ошибки загрузки у ls-fonts, WT-LOAD-11).
function M.error_lines(stderr)
  local out = {}
  for line in stderr:gmatch('[^\n]+') do
    if line:find('ERROR', 1, true) then out[#out + 1] = line end
  end
  return out
end

--- Краткое описание результата для текста FAIL: команда, код, начало stderr.
function M.describe(r, max_lines)
  local lines = {}
  for line in r.stderr:gmatch('[^\n]+') do
    lines[#lines + 1] = line
    if #lines >= (max_lines or 4) then break end
  end
  return ('код %s%s, stdout %d байт, stderr: %s'):format(tostring(r.code),
    r.timed_out and ' (таймаут)' or '', #r.stdout, #lines > 0 and table.concat(lines, ' | ') or '(пусто)')
end

return M
