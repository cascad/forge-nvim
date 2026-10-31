local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local go_cache = vim.env.FORGE_E2E_GO_CACHE or (vim.fn.tempname() .. '-forge-go-cache')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local editor
local sep = vim.fn.has('win32') == 1 and ';' or ':'

local function start_editor()
  if editor then return end
  local toolroot = vim.env.FORGE_E2E_DAP_TOOLS or root .. '/.tests/dap-tools'
  local path = vim.env.PATH
  if vim.fn.isdirectory(toolroot .. '/go/bin') == 1 then
    path = toolroot .. '/bin' .. sep .. toolroot .. '/go/bin' .. sep .. path
  end
  editor = require('editor').start(root, { timeout = 240000,
    env = { PATH = path, GOTOOLCHAIN = 'local', GOPROXY = 'off', GOENV = 'off',
      GOCACHE = go_cache } })
  for _, name in ipairs({ 'main.go', 'go.mod' }) do
    assert(vim.uv.fs_copyfile(root .. '/tests/e2e/fixtures/dap-go/' .. name, editor.project .. '/' .. name))
  end
  vim.fn.mkdir(editor.project .. '/.vscode', 'p')
  -- Проверка заранее даёт понятный FAIL вместо hit-enter ошибки несовместимых SDK.
  local versions = editor:lua([[local versions={}; for _,cmd in ipairs({{'go','version'},{'dlv','version'}}) do local r=vim.system(cmd,{text=true}):wait(); assert(r.code==0,r.stderr); versions[#versions+1]=r.stdout end; return versions]])
  vim.fn.writefile(vim.split(table.concat(versions, '\n'), '\n'), editor.dir .. '/tool-versions.txt')
  local major, minor = versions[1]:match('go(%d+)%.(%d+)')
  assert(tonumber(major) == 1 and tonumber(minor) >= 24,
    'Для Delve 1.26 нужен Go >= 1.24; выполни python[3] -B tests/e2e/prepare_dap.py --download')
  editor:input(':edit main.go<CR>')
  -- Дать FileType/notify закончить отрисовку, прежде чем вызывать blocking API.
  editor:wait('экран Go-файла', function()
    local screen = table.concat(editor.rpc:screen_lines(), '\n')
    if screen:find('Press ENTER', 1, true) then
      vim.fn.writefile(editor.rpc:screen_lines(), editor.dir .. '/go-open-prompt.txt')
      editor:input('<CR>')
      return false
    end
    return screen:find('package main', 1, true) ~= nil
  end, 10000)
  editor:wait('Go-файл готов', function()
    if editor.rpc:request('nvim_get_mode', {}).blocking then
      -- Известное контекстное предупреждение отсутствующего gopls в минимальном
      -- образе: сохраняется в messages, не требует установки LSP для DAP-теста.
      vim.fn.writefile(editor.rpc:screen_lines(), editor.dir .. '/go-open-prompt.txt')
      editor:input('<CR>')
      return false
    end
    return editor:current_file():match('/main.go$') ~= nil and editor:current_ft() == 'go'
  end, 10000)
  editor:lua([[local d=require('dap'); d.set_log_level('TRACE'); _G.forge_dap_events={};
    for _,name in ipairs({'event_initialized','event_output','event_stopped','event_continued','event_exited','event_terminated'}) do
      d.listeners.after[name].forge_e2e=function(s,body) _G.forge_dap_events[#_G.forge_dap_events+1]={name=name,body=body} end
    end]])
  local line
  for i, text in ipairs(vim.fn.readfile(editor.project .. '/main.go')) do
    if text:find('E2E_BREAKPOINT', 1, true) then line = i end
  end
  assert(line, 'fixture breakpoint marker')
  editor:input(line .. 'G<F9>')
end

local function output()
  return editor:lua([[local lines={}; for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dap-repl' then vim.list_extend(lines,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end; return table.concat(lines,'\n')]])
end

local function contains(text)
  editor:wait('вывод: ' .. text, function() return output():find(text, 1, true) ~= nil end)
end

local function stops()
  return editor:lua([[local n=0; for _,v in ipairs(_G.forge_dap_events) do if v.name=='event_stopped' then n=n+1 end end; return n]])
end

local function wait_stop(previous, reason)
  editor:wait('остановка: ' .. (reason or 'breakpoint'), function()
    if editor:ack_warning("Debug adapter didn't respond.") then return false end
    return editor:lua([[local count,reason=...; local n,last=0; for _,v in ipairs(_G.forge_dap_events) do if v.name=='event_stopped' then n=n+1; last=v.body.reason end end; local s=require('dap').session(); return n>count and s~=nil and s.stopped_thread_id~=nil and (reason=='' or last==reason)]], { previous, reason or '' })
  end, 60000)
end

local function launch(marker, console)
  local config = { name = 'E2E Go ' .. marker, type = 'go', request = 'launch',
    mode = 'debug', program = editor.project, cwd = editor.project,
    outputMode = 'remote', args = { marker }, console = console }
  vim.fn.writefile({ vim.json.encode({ version = '0.2.0', configurations = { config } }) }, editor.project .. '/.vscode/launch.json')
  local before = stops()
  editor:input('<F7>')
  editor:wait('фокус в коде перед запуском', function() return editor:current_ft() == 'go' end)
  editor:input('<F5>')
  editor:wait('выбор конфигурации готов', function()
    return editor:current_ft() == 'TelescopePrompt' and editor:lua([[local marker=...; if vim.api.nvim_get_mode().mode~='i' then return false end; for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='TelescopeResults' then for _,s in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do if s:find('E2E Go '..marker,1,true) then return true end end end end; return false]], { marker })
  end)
  editor:wait('конфигурация выбрана в UI', function()
    return editor:lua("return require('telescope.actions.state').get_selected_entry() ~= nil")
  end)
  editor:input('<CR>')
  wait_stop(before, 'breakpoint')
end

local function finish()
  editor:input('<F5>')
  editor:wait('сессия завершена', function() return editor:lua("return require('dap').session() == nil") end, 15000)
end

local function check(name, fn)
  T.check(name, function()
    local ok, failure = pcall(function() start_editor(); fn() end)
    if editor then
      editor:snapshot(name)
      pcall(function()
        editor:lua([[if require('dap').session() then require('dap').terminate() end]])
        editor:wait('очистка завершила сессию', function() return editor:lua("return require('dap').session() == nil") end)
      end)
    end
    assert(ok, failure)
  end)
end

check('IDE-DAP-1 первый и повторный запуск: stdout/stderr и сохранение после выхода', function()
  for _, marker in ipairs({ 'first', 'second' }) do
    launch(marker)
    T.eq(editor:has_window('dap-repl'), true)
    contains('STDOUT_BEFORE_' .. marker)
    contains('STDERR_BEFORE_' .. marker)
    contains('Building ')
    if marker == 'second' then assert(not output():find('STDOUT_BEFORE_first', 1, true), 'Остался вывод предыдущей сессии') end
    finish()
    contains('STDOUT_AFTER_' .. marker)
    T.eq(editor:has_window('dap-repl'), true)
  end
end)

check('IDE-DAP-1 Go outputMode remote виден при console integratedTerminal в launch.json', function()
  launch('remote-console', 'integratedTerminal')
  contains('STDOUT_BEFORE_remote-console')
  T.eq(editor:has_window('dap-repl'), true)
  finish()
  contains('STDOUT_AFTER_remote-console')
end)

check('IDE-DAP-1 скрытая панель восстанавливается на следующем breakpoint без очистки', function()
  launch('hidden')
  local before = stops()
  editor:input('<F5>')
  contains('WAITING_FOR_GATE')
  editor:input(' mc')
  editor:wait('панели скрыты пользователем', function() return not editor:has_window('dap-repl') and not editor:has_window('dapui_scopes') end)
  vim.fn.writefile({ 'continue' }, editor.project .. '/continue.flag')
  wait_stop(before, 'breakpoint')
  editor:wait('область вывода восстановлена', function() return editor:has_window('dap-repl') end)
  T.eq(editor:has_window('dapui_scopes'), true)
  contains('STDOUT_BEFORE_hidden')
  T.eq(editor:current_ft(), 'go')
  finish()
end)

check('IDE-DAP-2 panic виден в Output во время паузы, stderr сохранён после continue', function()
  launch('panic')
  local before = stops()
  editor:input('<F5>')
  wait_stop(before, 'exception')
  contains('FORGE_PANIC_MESSAGE')
  T.eq(editor:lua("local s=require('dap').session(); return s ~= nil and s.stopped_thread_id ~= nil"), true)
  contains('STDOUT_BEFORE_panic')
  finish()
  contains('panic: FORGE_PANIC_MESSAGE')
  T.eq(editor:has_window('dap-repl'), true)
end)

if editor then
  pcall(function()
    vim.fn.writefile({ vim.json.encode(editor:lua('return _G.forge_dap_events')) }, editor.dir .. '/dap-events.json')
    local logpath = editor:lua("return require('dap.log').create_logger('dap.log'):get_path()")
    if vim.fn.filereadable(logpath) == 1 then vim.uv.fs_copyfile(logpath, editor.dir .. '/dap.log') end
  end)
  io.stdout:write('  artifacts: ' .. editor.dir .. '\n')
  editor:stop()
end
T.finish()
