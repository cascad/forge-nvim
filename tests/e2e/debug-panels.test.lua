local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local go_cache = vim.env.FORGE_E2E_GO_CACHE or (vim.fn.tempname() .. '-forge-go-cache')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local e, started, identity
local sidebar = { 'dapui_scopes', 'dapui_watches', 'dapui_stacks', 'dapui_breakpoints' }

local function text(ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].filetype==ft then vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;
    return table.concat(out,'\n')]], { ft })
end

local function start()
  if e then return end
  local sep = vim.fn.has('win32') == 1 and ';' or ':'
  local tools = vim.env.FORGE_E2E_DAP_TOOLS or root .. '/.tests/dap-tools'
  local path = vim.env.PATH
  if vim.fn.isdirectory(tools .. '/go/bin') == 1 then path = tools .. '/bin' .. sep .. tools .. '/go/bin' .. sep .. path end
  e = require('editor').start(root, { timeout = 240000,
    env = { PATH = path, GOTOOLCHAIN = 'local', GOENV = 'off', GOPROXY = 'off',
      GOCACHE = go_cache } })
  for _, name in ipairs({ 'main.go', 'go.mod' }) do
    assert(vim.uv.fs_copyfile(root .. '/tests/e2e/fixtures/debug-panels/' .. name, e.project .. '/' .. name))
  end
  e:wait('IDE готова после VeryLazy', function() return e:lua('return _G.forge_e2e_observed') end, 10000)
  e:input(':edit main.go<CR>')
  e:wait('Go-файл готов', function()
    if e.rpc:request('nvim_get_mode', {}).blocking then e:input('<CR>'); return false end
    return e:current_ft() == 'go'
  end, 10000)
end

local function session()
  return e:lua([[local s=require('dap').session();if not s then return false end;
    return {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id}]])
end

local function paused()
  T.eq(session(), identity, 'UI не меняет session/thread/frame паузы')
end

local function pause()
  if started then return end
  e:input('<F7>')
  e:wait('код перед запуском', function() return e:current_ft() == 'go' end)
  local line
  for i, value in ipairs(vim.fn.readfile(e.project .. '/main.go')) do if value:find('E2E_BREAKPOINT', 1, true) then line = i end end
  vim.fn.mkdir(e.project .. '/.vscode', 'p')
  vim.fn.writefile({ vim.json.encode({ version = '0.2.0', configurations = {
    { name = 'Panel E2E', type = 'go', request = 'launch', mode = 'debug',
      program = e.project, cwd = e.project, outputMode = 'remote', args = {} },
  } }) }, e.project .. '/.vscode/launch.json')
  e:input(line .. 'G<F9><F5>')
  e:wait('выбор launch.json конфигурации', function()
    return e:current_ft() == 'TelescopePrompt' and e:lua([[return require('telescope.actions.state').get_selected_entry()~=nil]])
  end, 10000)
  e:input('<CR>')
  e:wait('Delve на настоящем breakpoint', function()
    if e:ack_warning("Debug adapter didn't respond.") then return false end
    local s = session()
    return type(s) == 'table' and type(s.thread) == 'number' and type(s.frame) == 'number'
  end, 120000)
  identity, started = session(), true
  e:wait('stdout до паузы', function() return text('dap-repl'):find('PANEL_BEFORE', 1, true) ~= nil end)
end

local function focus(keys, ft)
  e:input(keys)
  e:wait('фокус: ' .. ft, function() return e:current_ft() == ft end)
end

local function check(name, fn)
  T.check(name, function()
    local ok, failure = pcall(function()
      start()
      if name:match('^IDE%-PANEL%-2') then pause() end
      fn()
      for _, n in ipairs(e.rpc.notifications) do assert(n.level < vim.log.levels.ERROR, n.message) end
    end)
    if e then
      e:snapshot(name)
      if not ok then e:input('<Esc><Esc><F7>') end
    end
    assert(ok, failure)
  end)
end

check('IDE-PANEL-1 старый alias и q скрывают всю группу, новые keys/help без сессии', function()
  focus(' Dv', 'dapui_scopes')
  e:input('q')
  e:wait('вся debug-группа скрыта', function()
    for _, ft in ipairs(sidebar) do if e:has_window(ft) then return false end end
    return e:current_ft() == 'go'
  end)
  focus(' wd', 'dapui_scopes')
  e:wait('индикатор фокуса виден', function()
    return table.concat(e.rpc:screen_lines(), '\n'):find('[focus]', 1, true) ~= nil
  end)
  focus(' wj', 'dapui_watches')
  focus(' wk', 'dapui_scopes')
  focus(' wl', 'go')
  e:input(' wh')
  e:wait('левое debug-окно', function() return e:current_ft():match('^dapui_') ~= nil end)
  focus(' wd', 'dapui_scopes')
  focus('?', 'forge-panel-help')
  assert(text('forge-panel-help'):find('Space w', 1, true))
  focus('<Esc>', 'dapui_scopes')
  focus(' w0', 'go')
  T.eq(session(), false)
  -- Код не стал tool-буфером и не получил локальный q.
  T.eq(e:lua([[return vim.fn.maparg('q','n',false,true).buffer or 0]]), 0)
end)

check('IDE-PANEL-2 Locals/Enter, ru alias, помощь, Esc и направления сохраняют паузу', function()
  focus(' цв', 'dapui_scopes') -- физические wd на русской раскладке
  local row
  e:wait('реальная переменная item', function()
    row = e:lua([[for i,s in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if s:find('item',1,true) then return i end end;return 0]])
    return row > 0
  end)
  e:input(row .. 'G<CR>')
  e:wait('реальный child Value 42 раскрыт', function()
    local s = text('dapui_scopes')
    return s:find('Value', 1, true) ~= nil and s:find('42', 1, true) ~= nil
  end)
  focus('?', 'forge-panel-help')
  focus('q', 'dapui_scopes')
  paused()
  focus('<Esc>', 'go')
  T.eq(e:has_window('dapui_scopes'), true)
  e:input(' wh')
  e:wait('соседняя debug-панель', function() return e:current_ft():match('^dapui_') ~= nil end)
  focus(' w0', 'go')
  paused()
end)

check('IDE-PANEL-2 Output zoom/restore, REPL текст, q и восстановление вывода', function()
  focus(' wc', 'dap-repl')
  local original = e:lua('return {win=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf(),width=vim.api.nvim_win_get_width(0),height=vim.api.nvim_win_get_height(0)}')
  e:input(' wz')
  e:wait('развёрнут тот же buffer', function()
    return e:lua([[local b=...;return vim.api.nvim_get_current_buf()==b and vim.api.nvim_win_get_config(0).relative~='']], { original.buf })
  end)
  paused()
  e:input(' wz')
  e:wait('исходное окно восстановлено', function() return e:lua('return vim.api.nvim_get_current_win()') == original.win end)
  T.eq(e:lua('return {width=vim.api.nvim_win_get_width(0),height=vim.api.nvim_win_get_height(0)}'), { width = original.width, height = original.height })
  e:input('G$aquery_q?')
  e:wait('печатные q/? остаются вводом', function() return text('dap-repl'):find('query_q?', 1, true) ~= nil end)
  e:input('<Esc>q')
  e:wait('Output скрыт и фокус в коде', function() return not e:has_window('dap-repl') and e:current_ft() == 'go' end)
  paused()
  focus(' wc', 'dap-repl')
  assert(text('dap-repl'):find('PANEL_BEFORE', 1, true))
  assert(text('dap-repl'):find('query_q?', 1, true))
  paused()
  e:input(' wz')
  e:wait('zoom перед внешним закрытием', function() return e:lua([[return vim.api.nvim_win_get_config(0).relative~='']]) end)
  -- Настоящий backend закрывает source независимо от controls.
  e:input([[:lua require('dapui').close({layout=3})<CR>]])
  e:wait('закрытый source не оставил overlay', function() return not e:has_window('dap-repl') and e:current_ft() == 'go' end)
  paused()
  focus(' wc', 'dap-repl')
  assert(text('dap-repl'):find('PANEL_BEFORE', 1, true))
end)

check('IDE-PANEL-2 Esc возвращает zoom, q скрывает группу без сиротских окон', function()
  focus(' w0', 'go')
  focus(' wd', 'dapui_scopes')
  local original = e:lua('return vim.api.nvim_get_current_win()')
  e:input(' wz<Esc>')
  e:wait('Esc вернул исходную панель', function() return e:lua('return vim.api.nvim_get_current_win()') == original end)
  e:input(' wzq')
  e:wait('группа и zoom скрыты', function()
    if e:current_ft() ~= 'go' then return false end
    for _, ft in ipairs(sidebar) do if e:has_window(ft) then return false end end
    return true
  end)
  paused()
  T.eq(e:has_window('dap-repl'), true)
  -- При отсутствии левого соседа — no-op.
  local win = e:lua('return vim.api.nvim_get_current_win()')
  e:input(' wh')
  T.eq(e:lua('return vim.api.nvim_get_current_win()'), win)
  e:input('<F5>')
  e:wait('явный F5 завершил процесс', function() return session() == false end, 20000)
  e:wait('вывод после продолжения сохранён', function() return text('dap-repl'):find('PANEL_AFTER', 1, true) ~= nil end)
end)

if e then
  pcall(function() e:lua([[if require('dap').session() then require('dap').terminate() end]]) end)
  io.stdout:write('  artifacts: ' .. e.dir .. '\n')
  e:stop()
end
T.finish()
