local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local windows=vim.fn.has('win32')==1
local suffix=windows and '.exe' or ''
local sdk=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
local go_bin=vim.fn.filereadable(sdk..'/go/bin/go'..suffix)==1 and sdk..'/go/bin' or vim.fs.dirname(vim.fn.exepath('go'))
local paths={go_bin}
for _,exe in ipairs({'git','rg'}) do
  local found=vim.fn.exepath(exe);assert(found~='',exe..' отсутствует')
  paths[#paths+1]=vim.fs.dirname(found)
end
if windows then paths[#paths+1]=vim.env.SystemRoot..'/System32';paths[#paths+1]=vim.env.SystemRoot
else paths[#paths+1]='/usr/bin';paths[#paths+1]='/bin' end
local path=table.concat(paths,windows and ';' or ':')
local cache=require('go_cache').path(root)

local function observe(e)
  e:lua([[
    local log=...
    _G.forge_go_calls={};_G.forge_go_held={};_G.forge_hold_go_version=false;_G.forge_hold_go_env=false
    local function record(cmd,api,opts)
      local name=type(cmd)=='table' and cmd[1] or cmd
      if type(name)~='string' then return end
      local base=vim.fs.basename(name):lower()
      local delve=type(cmd)=='table' and cmd[2]=='version' and
        (base=='dlv' or base=='dlv.exe' or base=='dlv.cmd' or base=='dlv.bat')
      if not (name=='go' or name:match('^go%s') or delve) then return end
      local row={command=cmd,api=api,cwd=vim.fn.getcwd(),toolchain=vim.env.GOTOOLCHAIN,
        env=vim.deepcopy((opts or {}).env or {}),stack=debug.traceback('',3)}
      table.insert(_G.forge_go_calls,row)
      vim.fn.writefile({vim.json.encode(row)},log,'a')
      return row
    end
    local system=vim.system
    vim.system=function(cmd,opts,callback)
      local row=record(cmd,'vim.system',opts)
      if row and type(callback)=='function' then
        return system(cmd,opts,function(result)
          row.result={code=result.code,signal=result.signal,stdout=result.stdout,stderr=result.stderr};row.done=true
          if (_G.forge_hold_go_version and type(cmd)=='table' and cmd[2]=='version') or
            (_G.forge_hold_go_env and type(cmd)=='table' and cmd[2]=='env' and row.stack:find('plugins/dap.lua',1,true)) then
            -- Удерживаем только доставку настоящего завершённого CLI результата.
            table.insert(_G.forge_go_held,function() callback(result) end)
          else callback(result) end
        end)
      end
      return system(cmd,opts,callback)
    end
    for _,key in ipairs({'system','systemlist'}) do
      local original=vim.fn[key];local api='vim.fn.'..key
      vim.fn[key]=function(cmd,...)
        local row=record(cmd,api);local result=original(cmd,...)
        if row then row.result={code=vim.v.shell_error,stdout=result};row.done=true end
        return result
      end
    end
  ]],{e.dir..'/go-calls.jsonl'})
end
local function calls(e)
  return e:lua('return _G.forge_go_calls')
end
local function versions(e)
  local n=0
  for _,row in ipairs(calls(e)) do if type(row.command)=='table' and row.command[2]=='version' then n=n+1 end end
  return n
end
local function wait_notice(e,prefix,expected_restart)
  -- Только push notifications/fast mode: blocking RPC нельзя начинать, пока
  -- native notify явной команды ждёт Enter в profile без fidget/gopls.
  e:wait('явное уведомление '..prefix,function()
    local found=false
    for _,n in ipairs(e.rpc.notifications) do
      if n.level==vim.log.levels.INFO and n.message:find(prefix,1,true)==1 then found=true end
    end
    if e.rpc:request('nvim_get_mode',{}).blocking then
      local n=e.rpc.notifications[#e.rpc.notifications]
      -- Windows native force-stop: прежний GoToolchain вызывает stop(true).
      -- Разрешён только известный tuple запрошенного здесь gopls restart.
      local stopped=expected_restart and windows and n and n.level==vim.log.levels.WARN
        and n.message:find('Client gopls quit with exit code 1 and signal 15.',1,true)==1
      assert(n and ((n.level==vim.log.levels.INFO and n.message:find(prefix,1,true)==1) or stopped),
        'Неожиданный prompt вместо явного Go ответа')
      e.info_prompts=(e.info_prompts or 0)+1
      vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/explicit-info-'..e.info_prompts..'.txt')
      e:input('<CR>');return false
    end
    return found
  end)
end
local function settle(e)
  e:lua([[_G.forge_go_settled=false;vim.defer_fn(function() _G.forge_go_settled=true end,400)]])
  e:wait('Go callbacks завершены',function() return e:lua('return _G.forge_go_settled') end)
end
local function open(e)
  e:input(':edit main.go<CR>')
  e:wait('Go файл и prompts наблюдались',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then
      e.prompts=e.prompts or {};e.prompts[#e.prompts+1]=table.concat(e.rpc:screen_lines(),'\n')
      vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/prompt-'..#e.prompts..'.txt')
      e:input('<CR>');return false
    end
    return e:current_ft()=='go'
  end,10000)
  settle(e)
end
local function check(name,toolchain,fn)
  if vim.env.FORGE_GO_PASSIVE_CASE and not name:find(vim.env.FORGE_GO_PASSIVE_CASE,1,true) then return end
  T.check((name:match('^IDE%-') and '' or 'IDE-BOOT-4 ')..name,function()
    local e
    local ok,err=pcall(function()
      e=require('editor').start(root,{timeout=180000,env={PATH=path,
        GOTOOLCHAIN=toolchain,GOENV='off',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
        GOMAXPROCS='2',GOFLAGS='-p=2',CGO_ENABLED='0',FORGE_DLV_PATH='',DLV_PATH=''},
        prepare=function(project,env,runtime)
          env.GOPATH=runtime..'/go';env.GOMODCACHE=runtime..'/go/pkg/mod';env.GOCACHE=cache
          vim.fn.writefile({'module example.invalid/passive','go 1.99.0'},project..'/go.mod')
          vim.fn.writefile({'package main','func main() {}'},project..'/main.go')
        end})
      T.eq(e:lua([[return vim.fn.executable('gopls')]]),0,'metadata case без backend Go запросов')
      T.eq(e:lua([[return vim.fn.executable('dlv')]]),0,'Delve изначально отсутствует')
      observe(e);open(e);fn(e)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end)
    if e then
      local captured,data=pcall(function() return e:lua([[return {calls=_G.forge_go_calls,held=#_G.forge_go_held,
        label=package.loaded['forge.go'] and require('forge.go').label(),
        version=package.loaded['forge.go'] and require('forge.go').version(),
        toolchain=vim.env.GOTOOLCHAIN,cwd=vim.fn.getcwd(),lsp_restart=_G.forge_go_lsp_restart,
        notifications=vim.g.forge_e2e_notifications} ]]) end)
      if captured then vim.fn.writefile({vim.json.encode(data)},e.dir..'/go-state.json') end
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/go-passive.test.lua',e.dir..'/go-passive.test.lua'))
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end

check('IDE-DAP-10 native Delve discovery keeps input and local metadata','auto',function(e)
  local dlv=sdk..'/bin/dlv'..suffix
  if vim.fn.filereadable(dlv)==0 then dlv=vim.fn.exepath('dlv') end
  assert(vim.fn.filereadable(dlv)==1,'Нужен уже подготовленный Delve SDK')
  local bin=e.runtime..'/discovery tools ü';vim.fn.mkdir(bin,'p')
  local executable=bin..'/dlv'..suffix;assert(vim.uv.fs_copyfile(dlv,executable))
  if not windows then assert(vim.uv.fs_chmod(executable,493)) end
  T.eq(#calls(e),0,'FileType не должен запускать probes')
  e:lua([[vim.env.GOBIN=...;_G.forge_hold_go_env=true]],{bin})
  e:input(':DapGoDlvInfo<CR>')
  local first
  e:wait('native DAP Go env recorded',function()
    if vim.fn.filereadable(e.dir..'/go-calls.jsonl')==0 then return false end
    for _,line in ipairs(vim.fn.readfile(e.dir..'/go-calls.jsonl')) do
      local row=vim.json.decode(line)
      if row.command[2]=='env' and row.stack:find('plugins/dap.lua',1,true) then first=row;return true end
    end
  end)
  vim.fn.writefile({vim.json.encode({first_probe=first})},e.dir..'/go-discovery.json')
  T.eq(first.api,'vim.system','Delve discovery used synchronous Go env')
  e:wait('real local Go env result held',function() return e:lua('return #_G.forge_go_held==1') end)
  local env_call=calls(e)[1]
  T.eq(env_call.result.code,0,'локальный Go env должен работать без project SDK1.99')
  T.eq(env_call.env.GOTOOLCHAIN,'local')
  T.eq(vim.json.decode(env_call.result.stdout).GOBIN:gsub('\\','/'),bin:gsub('\\','/'))
  e:input(' we');e:wait('Files while Go metadata pending',function() return e:current_ft()=='neo-tree' end)
  e:input(' w0');e:wait('Go code while metadata pending',function() return e:current_ft()=='go' end)
  local started=vim.uv.hrtime();e:input('ggO// DISCOVERY_INPUT<Esc>')
  e:wait('real input before Go metadata delivery',function()
    return e:lua('return vim.api.nvim_get_current_line()'):find('DISCOVERY_INPUT',1,true)~=nil
  end)
  local elapsed=(vim.uv.hrtime()-started)/1e6
  assert(elapsed<300,'Reference input exceeded300ms: '..elapsed)
  T.eq(e:lua('return #_G.forge_go_held'),1)
  e:lua([[local held=_G.forge_go_held;_G.forge_go_held={};_G.forge_hold_go_env=false;for _,send in ipairs(held) do send() end]])
  wait_notice(e,'Delve candidates:')
  local observed=calls(e);T.eq(#observed,2,'one Go env and one Delve version, no repeated discovery')
  T.eq(observed[1].command,{'go','env','-json','GOBIN','GOPATH'})
  T.eq(observed[2].result.code,0);assert(observed[2].result.stdout:find('Version: 1.26.3',1,true))
  local message
  for _,n in ipairs(e.rpc.notifications) do if n.message:find('Delve candidates:',1,true)==1 then message=n.message end end
  assert(message and message:find('v1.26.3',1,true) and
    message:gsub('\\','/'):find('Selected: '..executable:gsub('\\','/'),1,true),message)
  T.eq(e:lua('return vim.env.GOTOOLCHAIN'),'auto','global toolchain unchanged')
  T.eq(e:lua('return require("dap").session()==nil'),true)
  vim.fn.writefile({vim.json.encode({ok=true,input_ms=elapsed,calls=observed,selected=executable,message=message,
    toolchain='auto'})},e.dir..'/go-discovery.json')
end)

check('edit/label не запускают Go или Delve для отсутствующего SDK','auto',function(e)
  local observed=calls(e)
  T.eq(#observed,0,'native metadata commands: '..vim.inspect(observed))
  T.eq(e:lua([[return require('forge.go').label()]]),'Go auto')
  for _,screen in ipairs(e.prompts or {}) do assert(not screen:find('downloading go',1,true),screen) end
  e:input('i// passive edit<Esc>:redrawstatus<CR>');settle(e)
  T.eq(#calls(e),0,'edit/redraw не создают запрос')
  T.eq(e:lua('return vim.env.GOTOOLCHAIN'),'auto','окружение backend не менялось')
  e:input(':let $GOTOOLCHAIN=""<CR>:redrawstatus<CR>');settle(e)
  T.eq(e:lua([[return require('forge.go').label()]]),'Go default','не заданный env не выдаётся за установленную версию')
  T.eq(#calls(e),0,'default label также не запускает CLI')
end)

check('GoVersion один раз запрашивает настоящую версию и кеширует label','local',function(e)
  e:lua('_G.forge_go_calls={};_G.forge_hold_go_version=true')
  e:input(':GoVersion<CR>')
  e:wait('реальный Go version завершился до доставки',function() return e:lua('return #_G.forge_go_held>0') end)
  settle(e)
  T.eq(versions(e),1,'повторное чтение не запускает второй CLI')
  e:lua([[local held=_G.forge_go_held;_G.forge_go_held={};_G.forge_hold_go_version=false;for _,send in ipairs(held) do send() end]])
  wait_notice(e,'Go: 1.26.0')
  e:wait('версия и notification готовы',function()
    return e:lua([[if require('forge.go').version()~='1.26.0' then return false end
      for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message:find('Go: 1.26.0',1,true) then return true end end;return false]])
  end)
  T.eq(e:lua([[return require('forge.go').label()]]),'Go 1.26.0')
  e:input(':redrawstatus<CR>');settle(e);T.eq(versions(e),1)
end)

check('старый реальный ответ не заменяет metadata нового cwd/toolchain','local',function(e)
  e:lua('_G.forge_go_calls={};_G.forge_hold_go_version=true')
  local old=e:lua('return vim.fn.getcwd()'):gsub('\\','/')
  e:input(':GoVersion<CR>')
  e:wait('Go CLI completed/held',function() return e:lua('return #_G.forge_go_held>0') end)
  e:input(':cd nested<CR>:let $GOTOOLCHAIN="auto"<CR>')
  e:wait('новый context',function() return e:lua([[return vim.fn.getcwd():gsub('\\','/'):sub(-7)=='/nested' and vim.env.GOTOOLCHAIN=='auto']]) end)
  e:lua([[local held=_G.forge_go_held;_G.forge_go_held={};_G.forge_hold_go_version=false;for _,send in ipairs(held) do send() end]])
  wait_notice(e,'Go: 1.26.0')
  settle(e)
  T.eq(e:lua([[return require('forge.go').version()]]),'','старый cache не применён')
  T.eq(e:lua([[return require('forge.go').label()]]),'Go auto')
  assert(e:lua([[local cwd=...;for _,n in ipairs(vim.g.forge_e2e_notifications) do
    local text=n.message:gsub('\\','/');if text:find('Go: 1.26.0',1,true) and text:find('CWD: '..cwd..'\n',1,true)
      and text:find('GOTOOLCHAIN: local',1,true) then return true end end;return false]],{old}),'явный ответ содержит исходный context')
  T.eq(versions(e),1,'смена context не запускает metadata CLI')
end)

check('GoToolchain остаётся явным действием без дублей от label','auto',function(e)
  local lsp=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
  assert(vim.fn.filereadable(lsp..'/manifest.json')==1,'Явно подготовь настоящий gopls SDK')
  vim.fn.writefile({'module example.invalid/passive','go 1.22'},e.project..'/go.mod')
  e:lua([[local bin=...;vim.env.PATH=bin..(vim.fn.has('win32')==1 and ';' or ':')..vim.env.PATH;
    vim.lsp.enable('gopls');vim.api.nvim_exec_autocmds('FileType',{buffer=0})]],{lsp..'/bin'})
  e:wait('настоящий gopls до GoToolchain',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({name='gopls',bufnr=0})) do
    if c.initialized and not c:is_stopped() then _G.forge_go_lsp_restart={before=c.id};return true end end;return false]]) end,30000)
  e:lua('_G.forge_go_calls={}')
  e:input(':GoToolchain local<CR>')
  wait_notice(e,'GOTOOLCHAIN = local',true)
  e:wait('новый настоящий gopls и версия подтверждены',function() return e:lua([[if vim.env.GOTOOLCHAIN~='local'
    or require('forge.go').version()~='1.26.0' or vim.g.forge_lsp_restarting~=nil then return false end
    for _,c in ipairs(vim.lsp.get_clients({name='gopls',bufnr=0})) do
      if c.initialized and not c:is_stopped() and c.id~=_G.forge_go_lsp_restart.before then
        _G.forge_go_lsp_restart.after=c.id;return true end end;return false]]) end,30000)
  settle(e);T.eq(versions(e),1)
  T.eq(e:lua([[return require('forge.go').label()]]),'Go 1.26.0')
end)

check('поздний Delve override используется настоящим F5/breakpoint/output','local',function(e)
  local dlv=sdk..'/bin/dlv'..suffix
  if vim.fn.filereadable(dlv)==0 then dlv=vim.fn.exepath('dlv') end
  assert(dlv~='' and vim.fn.filereadable(dlv)==1,'Явно подготовь настоящий Delve SDK')
  local dir=e.runtime..'/late tools ü';vim.fn.mkdir(dir,'p')
  local late=dir..'/dlv'..suffix;assert(vim.uv.fs_copyfile(dlv,late))
  if not windows then assert(vim.uv.fs_chmod(late,493)) end
  for _,file in ipairs({'go.mod','main.go'}) do assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/debug-panels/'..file,e.project..'/'..file)) end
  e:input(':edit! main.go<CR>')
  e:wait('обновлён настоящий Go debug fixture',function() return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('E2E_BREAKPOINT',1,true)~=nil]]) end)
  e:lua([[vim.env.FORGE_DLV_PATH=...;require('dap').set_log_level('TRACE')]],{late})
  local line
  for i,text in ipairs(vim.fn.readfile(e.project..'/main.go')) do if text:find('E2E_BREAKPOINT',1,true) then line=i end end
  vim.fn.mkdir(e.project..'/.vscode','p')
  vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={{name='Late Delve',type='go',request='launch',
    mode='debug',program=e.project,cwd=e.project,outputMode='remote',args={}}}})},e.project..'/.vscode/launch.json')
  local notifications=#e.rpc.notifications
  e:input(line..'G<F9><F5>')
  e:wait('launch.json picker',function() return e:current_ft()=='TelescopePrompt' and e:lua([[return require('telescope.actions.state').get_selected_entry()~=nil]]) end)
  e:input('<CR>')
  e:wait('настоящая сессия на breakpoint либо native launch error',function()
    for i=notifications+1,#e.rpc.notifications do if e.rpc.notifications[i].level>=vim.log.levels.ERROR then return true end end
    return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil]])
  end,120000)
  for i=notifications+1,#e.rpc.notifications do assert(e.rpc.notifications[i].level<vim.log.levels.ERROR,e.rpc.notifications[i].message) end
  T.eq(e:lua([[return require('dap').session().adapter.executable.command]]):gsub('\\','/'),late:gsub('\\','/'))
  local function output()
    return e:lua([[local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dap-repl' then
      vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]])
  end
  e:wait('stdout до breakpoint',function() return output():find('PANEL_BEFORE',1,true)~=nil end)
  e:input('<F5>')
  e:wait('настоящая программа завершилась',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
  assert(output():find('PANEL_AFTER',1,true),output())
end)
T.finish()
