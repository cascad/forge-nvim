-- Корень репо и package.path для файлов проверок (tests/README.md, «Как устроен файл проверок»).
--
-- Файл проверок подключает его двумя строками в начале:
--   local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
--   dofile(r .. '/tests/lib/bootstrap.lua')
-- после чего работают require('check'), require('fake_wezterm') и т.д.
--
-- Это композиционный корень процесса проверки: окружение читается здесь,
-- дальше модули получают значения параметрами. При запуске через
-- tests/run.lua все значения приходят переменными FORGE_*; при прямом
-- запуске `nvim -l tests/<файл>` — вычисляются здесь же.

local M = {}

local function norm(p)
  return (p:gsub('\\', '/'):gsub('/+$', ''))
end

local function is_dir(p)
  local st = vim.uv.fs_stat(p)
  return st ~= nil and st.type == 'directory'
end

local function env(name)
  local v = os.getenv(name)
  if v == nil or v == '' then return nil end
  return v
end

local function walk_up(start)
  local dir = norm(start)
  while dir and dir ~= '' do
    if is_dir(dir .. '/openspec') then return dir end
    local parent = dir:match('^(.*)/[^/]*$')
    if parent == nil or parent == dir then return nil end
    dir = parent
  end
  return nil
end

local function find_root()
  local from_env = env('FORGE_REPO')
  if from_env then return norm(from_env) end
  -- Вверх от файла проверок (arg[0] у `nvim -l`) до каталога с openspec/,
  -- затем — от самого bootstrap.lua (он всегда лежит в <корень>/tests/lib/).
  local starts = {}
  if arg and arg[0] then starts[#starts + 1] = vim.fn.fnamemodify(arg[0], ':p:h') end
  starts[#starts + 1] = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
  for _, s in ipairs(starts) do
    local root = walk_up(s)
    if root then return root end
  end
  error('bootstrap: не найден корень репо (каталог с openspec/) выше ' .. table.concat(starts, ', ') .. '; задай FORGE_REPO', 0)
end

M.root = find_root()
-- Песочница для всего, что проверкам нужно записать: только внутри .tests/.
M.sandbox = norm(env('FORGE_SANDBOX') or (M.root .. '/.tests/sandbox'))
-- `--update-golden` у раннера.
M.update_golden = os.getenv('FORGE_UPDATE_GOLDEN') == '1'
-- Путь к wezterm: раннер передаёт FORGE_WEZTERM (пустая строка = бинарника нет).
do
  local w = os.getenv('FORGE_WEZTERM')
  if w == nil then
    w = vim.fn.exepath('wezterm')
  end
  M.wezterm = (w ~= '') and w or nil
end

package.path = table.concat({
  M.root .. '/tests/lib/?.lua',
  M.root .. '/tests/wezterm/?.lua',
  package.path,
}, ';')

package.loaded.bootstrap = M
return M
