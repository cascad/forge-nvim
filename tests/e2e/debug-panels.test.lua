local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local go_cache = require('go_cache').path(root)
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
  e = require('editor').start(root, { timeout = 240000, capture_ui = true,
    env = { PATH = path, GOTOOLCHAIN = 'local', GOENV = 'off', GOPROXY = 'off',
      GOCACHE = go_cache } })
  assert(vim.uv.fs_copyfile(root..'/tests/e2e/debug-panels.test.lua',e.dir..'/debug-panels.test.lua'))
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

check('IDE-PANEL-18 Locals zoom сохраняет floating при открытой помощи', function()
  pause()
  focus(' wd','dapui_scopes')
  local original=e:lua([[return {win=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf(),
    width=vim.api.nvim_win_get_width(0),height=vim.api.nvim_win_get_height(0)}]])
  e:input(' wz')
  e:wait('native floating Locals',function() return e:lua([[return vim.api.nvim_win_get_config(0).relative=='editor']]) end)
  local overlay=e:lua('return vim.api.nvim_get_current_win()')
  focus('?','forge-panel-help')
  local report={original=original,overlay=overlay,observations={}}
  local deadline=vim.uv.hrtime()+300000000
  repeat
    local observed=e:lua([[local w,source=...;return {config=vim.api.nvim_win_get_config(w),buf=vim.api.nvim_win_get_buf(w),
      source_disable=vim.w[source].edgy_disable or false,buffer_disable=vim.b[vim.api.nvim_win_get_buf(w)].edgy_disable or false}]],{overlay,original.win})
    report.observations[#report.observations+1]=observed
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/zoom-layout.json')
    T.eq(observed.config.relative,'editor','Edgy docked native zoom overlay')
    T.eq(observed.buf,original.buf);T.eq(observed.source_disable,false);T.eq(observed.buffer_disable,false)
    paused();vim.wait(25)
  until vim.uv.hrtime()>=deadline
  focus('q','dapui_scopes');T.eq(e:lua('return vim.api.nvim_get_current_win()'),overlay)
  e:input('<Esc>')
  e:wait('исходное окно и geometry',function() return e:lua([[local o=...;return vim.api.nvim_get_current_win()==o.win and
    vim.api.nvim_win_get_width(0)==o.width and vim.api.nvim_win_get_height(0)==o.height]],{original}) end)
  T.eq(e:lua('return vim.api.nvim_win_is_valid(...)',{overlay}),false)
  assert(text('dap-repl'):find('PANEL_BEFORE',1,true));paused()
end)

check('IDE-PANEL-24 native RGB рамки Locals/Output/Files/Logs и возврат', function()
  local capture = assert(e.rpc.ui_capture)
  e:lua([[_G.zoom_style_keys=0;vim.keymap.set('n','<F35>',function() _G.zoom_style_keys=_G.zoom_style_keys+1 end)]])
  local function keys(value)
    local before=e:lua('return _G.zoom_style_keys')
    e:input(value..'<F35>')
    e:wait('ввод обработан',function() return e:lua('return _G.zoom_style_keys')>before end)
  end
  local function checkpoint(label,win,name,active)
    e:wait('стиль рамки обновлён',function()
      return e:lua([[local w,active=...;return vim.wo[w].winbar=='' and
        vim.wo[w].winhl:find('FloatBorder:'..(active and 'DiagnosticInfo' or 'Comment'),1,true)~=nil]],{win,active})
    end)
    local previous=capture.flushes
    local metadata=e:lua([[local w,name,active=...;vim.cmd('redraw!');return {
      win=w,name=name,active=active,position=vim.api.nvim_win_get_position(w),
      width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w),
      accent=vim.api.nvim_get_hl(0,{name='DiagnosticInfo',link=false}).fg,
      dim=vim.api.nvim_get_hl(0,{name='Comment',link=false}).fg}]],{win,name,active})
    e:wait('native UI flush',function() return capture.flushes>previous end)
    capture:checkpoint(label,metadata)
    assert(not capture.error,capture.error)
    paused()
  end
  for _,panel in ipairs({
    {'locals',' wd','dapui_scopes','Locals'}, {'output',' wc','dap-repl','Output / REPL'},
    {'files',' we','neo-tree','Files'}, {'logs',' wi','forge-logs','IDE Logs'},
  }) do
    keys(' w0');keys(panel[2])
    e:wait('рабочая панель '..panel[1],function() return e:current_ft()==panel[3] end)
    local source=e:lua([[return {win=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf(),
      winbar=vim.wo.winbar,winhl=vim.wo.winhl,width=vim.api.nvim_win_get_width(0),height=vim.api.nvim_win_get_height(0)}]])
    keys(' wz')
    e:wait('native zoom '..panel[1],function() return e:lua([[return vim.api.nvim_win_get_config(0).relative=='editor']]) end)
    local overlay=e:lua('return vim.api.nvim_get_current_win()')
    T.eq(e:lua('return vim.api.nvim_get_current_buf()'),source.buf)
    checkpoint('zoom-'..panel[1]..'-active',overlay,panel[4],true)
    keys('?');T.eq(e:current_ft(),'forge-panel-help')
    checkpoint('zoom-'..panel[1]..'-help',overlay,panel[4],false)
    keys('q');T.eq(e:lua('return vim.api.nvim_get_current_win()'),overlay)
    checkpoint('zoom-'..panel[1]..'-refocused',overlay,panel[4],true)
    local cursor=e:lua('return vim.api.nvim_win_get_cursor(0)')
    keys(panel[1]=='output' and ' wz' or '<Esc>')
    e:wait('исходное окно '..panel[1],function() return e:lua('return vim.api.nvim_get_current_win()')==source.win end)
    T.eq(e:lua('return vim.api.nvim_win_is_valid(...)',{overlay}),false)
    T.eq(e:lua('return vim.api.nvim_get_current_buf()'),source.buf)
    T.eq(e:lua('return vim.wo.winbar'),source.winbar)
    T.eq(e:lua('return vim.wo.winhl'),source.winhl)
    T.eq(e:lua('return {vim.api.nvim_win_get_width(0),vim.api.nvim_win_get_height(0)}'),{source.width,source.height})
    T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)'),cursor)
    paused()
  end
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='')
  local result=vim.system({python,'-B',root..'/tests/diagnostics/render-ui.py',capture.path,'--output',e.dir..'/zoom-ui'},
    {text=true,timeout=20000}):wait()
  T.eq(result.code,0,(result.stdout or '')..(result.stderr or ''))
  local frames=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/zoom-ui/frames.json'),'\n'))
  T.eq(#frames,12)
  for _,picture in ipairs(frames) do
    local m=picture.metadata
    assert(m.accent and m.dim and m.accent~=m.dim)
    local expected=m.active and m.accent or m.dim
    local row,col=m.position[1],m.position[2]
    for _,point in ipairs({{row,col,'╭'},{row,col+m.width+1,'╮'},
      {row+m.height+1,col,'╰'},{row+m.height+1,col+m.width+1,'╯'},
      {row+math.floor(m.height/2),col,'│'},{row+math.floor(m.height/2),col+m.width+1,'│'},
      {row+m.height+1,col+math.floor(m.width/2),'─'}}) do
      local cell=picture.cells[point[1]+1][point[2]+1]
      T.eq(cell[1],point[3],picture.label..' native border')
      T.eq(picture.highlights[tostring(cell[2])].foreground,expected,picture.label..' native RGB')
    end
    local title={}
    for x=col,col+m.width+1 do
      local cell=picture.cells[row+1][x+1];title[#title+1]=cell[1]
      if cell[1]~=' ' and cell[1]~='' then T.eq(picture.highlights[tostring(cell[2])].foreground,expected,picture.label..' title RGB') end
    end
    title=table.concat(title)
    assert(title:find(m.name,1,true) and title:find('Space w z',1,true),picture.label..' visible title')
    T.eq(title:find('[focus]',1,true)~=nil,m.active,picture.label..' visible focus')
  end
  -- Следующий сценарий продолжает общую паузу и ожидает открытый Output.
  keys(' w0');keys(' wc')
  e:wait('Output возвращён после style-сценария',function() return e:current_ft()=='dap-repl' end)
  paused()
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
