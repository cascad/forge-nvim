local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')

local function isolated_path()
  local sep = vim.fn.has('win32') == 1 and ';' or ':'
  local paths, excluded = {}, {}
  local tools = vim.env.FORGE_E2E_DAP_TOOLS or root .. '/.tests/dap-tools'
  if vim.fn.isdirectory(tools .. '/go/bin') == 1 then
    paths = { tools .. '/go/bin', tools .. '/bin' }
  end
  for _, path in ipairs(vim.split(vim.env.PATH or '', sep, { plain = true, trimempty = true })) do
    local dir = path:gsub('^"', ''):gsub('"$', '')
    local found = false
    for _, suffix in ipairs({ '', '.exe', '.cmd', '.bat' }) do
      if vim.fn.filereadable(dir .. '/codelldb' .. suffix) == 1 then found = true end
    end
    if found then excluded[#excluded + 1] = path else paths[#paths + 1] = path end
  end
  return table.concat(paths, sep), excluded
end

local function notifications(e)
  -- Push от настоящего vim.notify: работает и за hit-enter/error prompt,
  -- когда blocking nvim_exec_lua ещё не может обслужить запрос наблюдателя.
  return e.rpc.notifications
end

local function codelldb_messages(e)
  local out = {}
  for _, n in ipairs(notifications(e)) do
    if n.message:find('codelldb', 1, true) then out[#out + 1] = n end
  end
  return out
end

local function settle(e)
  -- Барьер после уже запланированных callbacks, включая старый setup WARN.
  e:lua([[vim.g.forge_discovery_settled=false; vim.schedule(function() vim.g.forge_discovery_settled=true end)]])
  e:wait('scheduled callbacks обработаны', function() return e:lua('return vim.g.forge_discovery_settled') end)
end

local function open_file(e, name, ft)
  e:input(':edit ' .. name .. '<CR>')
  e:wait('filetype ' .. ft, function()
    if e.rpc:request('nvim_get_mode', {}).blocking then
      vim.fn.writefile(e.rpc:screen_lines(), e.dir .. '/open-prompt.txt')
      e:input('<CR>')
      return false
    end
    return e:current_ft() == ft
  end, 10000)
  settle(e)
end

local function check(name, fn)
  T.check('IDE-DAP-4 ' .. name, function()
    local e
    local ok, failure = pcall(function()
      local path, excluded = isolated_path()
      e = require('editor').start(root, { env = {
        PATH = path, GOTOOLCHAIN = 'local', GOENV = 'off', GOPROXY = 'off',
      } })
      vim.fn.writefile({ vim.json.encode({ excluded_path_entries = excluded }) }, e.dir .. '/environment.json')
      T.eq(e:lua([[return vim.fn.executable('codelldb')]]), 0, 'реальное отсутствие codelldb, без mock')
      T.eq(e:lua([[return vim.fn.executable('git')]]), 1, 'подготовь PATH без codelldb, сохранив Git')
      vim.fn.writefile({ 'module forge-discovery', '', 'go 1.22' }, e.project .. '/go.mod')
      vim.fn.writefile({ 'package main', '', 'func main() {}' }, e.project .. '/main.go')
      vim.fn.writefile({ 'int main(void) { return 0; }' }, e.project .. '/main.cpp')
      fn(e)
    end)
    if e then
      e:snapshot(name)
      io.stdout:write('  artifacts: ' .. e.dir .. '\n')
      e:stop()
    end
    assert(ok, failure)
  end)
end

check('Go и breakpoint не предупреждают о чужом codelldb', function(e)
  open_file(e, 'main.go', 'go')
  T.eq(e:lua([[return package.loaded.dap~=nil]]), true)
  T.eq(#codelldb_messages(e), 0)
  e:input('<F9>')
  settle(e)
  T.eq(e:lua([[return next(require('dap.breakpoints').get())~=nil]]), true)
  T.eq(#codelldb_messages(e), 0)
  T.eq(e:lua([[return require('dap').session()==nil]]), true)
  for _, ft in ipairs({ 'c', 'cpp', 'rust' }) do
    T.eq(e:lua([[local ft=...;for _,c in ipairs(require('dap').configurations[ft] or {}) do
      if c.type=='codelldb' then return true end end;return false]], { ft }), true)
  end
  T.eq(e:lua('return vim.g.forge_e2e_installs'), 0)
end)

check('F9 в обычном файле загружает DAP без предупреждения codelldb', function(e)
  open_file(e, 'file_one.txt', 'text')
  e:input('<F9>')
  e:wait('настоящий breakpoint', function()
    return e:lua([[local d=package.loaded.dap;return d~=nil and next(require('dap.breakpoints').get())~=nil]])
  end)
  settle(e)
  T.eq(#codelldb_messages(e), 0)
  T.eq(e:lua([[return require('dap').session()==nil]]), true)
end)

check('F5 без codelldb сообщает один раз на попытку и сохраняет редактор', function(e)
  -- Настоящий launch.json; program существует, но отсутствие адаптера
  -- должно остановить запуск до его исполнения. Никакой подмены dap.run.
  vim.fn.mkdir(e.project .. '/.vscode', 'p')
  vim.fn.writefile({ vim.json.encode({ version = '0.2.0', configurations = {
    { name = 'Missing codelldb', type = 'codelldb', request = 'launch',
      program = vim.v.progpath, cwd = '${workspaceFolder}' },
  } }) }, e.project .. '/.vscode/launch.json')
  open_file(e, 'main.cpp', 'cpp')
  for attempt = 1, 2 do
    local before = #notifications(e)
    e:input('<F5>')
    e:wait('запуск сообщил о проблеме', function() return #notifications(e) > before end, 10000)
    e:wait('сообщение отрисовано, hit-enter снят', function()
      local screen = table.concat(e.rpc:screen_lines(), '\n')
      if screen:find('Press ENTER', 1, true) then e:input('<CR>'); return false end
      return not e.rpc:request('nvim_get_mode', {}).blocking
    end)
    settle(e)
    local added = {}
    for i, n in ipairs(notifications(e)) do if i > before then added[#added + 1] = n end end
    T.eq(#added, 1)
    assert(added[1].message:find('codelldb not found', 1, true), added[1].message)
    assert(added[1].message:find('Mason', 1, true), added[1].message)
    assert(not added[1].message:find('missing adapter', 1, true), added[1].message)
    T.eq(added[1].level, vim.log.levels.WARN)
    T.eq(e:lua([[return require('dap').session()==nil]]), true)
    e:input('<F7>')
    e:wait('возврат в код', function() return e:current_ft() == 'cpp' end)
  end
  e:input('Go// STILL_EDITABLE<Esc><C-s>')
  e:wait('файл сохранён', function()
    return table.concat(vim.fn.readfile(e.project .. '/main.cpp'), '\n'):find('STILL_EDITABLE', 1, true) ~= nil
  end)
  T.eq(e:lua('return vim.g.forge_e2e_installs'), 0)
end)

T.finish()
