-- One bounded original workflow, explicitly observed with prepared Windows LLDB.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
assert(vim.fn.has('win32')==1,'Windows CRT/Job diagnostic')
-- Bound the whole controller too: synchronous native socket RPC cannot run a
-- Lua timer deadline reliably if a backend stops responding.
if vim.env.FORGE_NATIVE_ASSERT_CHILD~='1' then
  local dir=root..'/.tests/native-assert-trials/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
  local scope=require('process_scope').new()
  local argv=scope:command({vim.v.progpath,'-l',root..'/tests/diagnostics/native-assert.lua'},{artifacts=dir})
  local process,result
  local ok,err=xpcall(function()
    process=vim.system(argv,vim.tbl_extend('force',scope.spawn_options,{cwd=root,text=true,timeout=90000,
      env={FORGE_NATIVE_ASSERT_CHILD='1',NVIM_LOG_FILE=dir..'/controller.log'}}))
    scope:attach(process.pid);result=process:wait()
    vim.wait(3000,function() return scope:active_count()==0 end,10)
  end,debug.traceback)
  local cleanup=scope:close()
  assert(vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and tostring(err) or nil,result=result,scope=cleanup})},dir..'/launcher.json')==0)
  io.stdout:write(result and result.stdout or '')
  io.stderr:write(result and result.stderr or '')
  io.stdout:write('launcher artifacts: '..dir..'\n')
  assert(ok,err);assert(result.code==0 and result.signal==0 and cleanup.ok and not cleanup.terminated,'Bounded native trial failed; '..dir)
  os.exit(0)
end
local tui,report
local observers={}
local ok,err=xpcall(function()
  tui=require('session_tui').start(root)
  local e=tui.host
  report={artifacts=e.dir,inputs={},phases={},original_reproduced=false,debugger_changes_timing=true}
  assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/native-assert.lua',e.dir..'/native-assert.lua'))
  report.backend=tui:launch()
  report.frontend_pid=e:lua('return vim.fn.jobpid(_G.forge_session_job)')
  assert(report.frontend_pid>0)
  for _,target in ipairs({{name='frontend',pid=report.frontend_pid},{name='backend',pid=report.backend.pid}}) do
    if target.name=='frontend' or target.pid~=report.frontend_pid then
      local observer=require('native_assert').start(root,e.rpc,e.runtime,e.dir..'/capture-'..target.name,target.pid,30)
      observers[#observers+1]=observer;observer:ready()
    end
  end
  local function save() assert(vim.fn.writefile({vim.json.encode(report)},e.dir..'/native-assert-trial.json')==0) end
  local function phase(label)
    report.phase=label;local row={label=label,ms=vim.uv.hrtime()/1e6}
    report.phases[#report.phases+1]=row
    for _,observer in ipairs(observers) do
      if vim.fn.filereadable(observer.dir..'/capture.json')==1 then error('Native stop captured; '..observer.dir) end
      if vim.fn.filereadable(observer.dir..'/done.json')==1 then error('Native observer ended before workflow; '..observer.dir) end
      observer:phase(row)
    end;save()
  end
  local send=tui.send
  function tui:send(keys)
    local accepted=send(self,keys)
    report.inputs[#report.inputs+1]={phase=report.phase,keys=keys,bytes=#keys,accepted=accepted};save()
    assert(accepted==#keys,'Native input was not fully accepted');return accepted
  end
  phase('edit first.txt');tui:command('edit first.txt')
  e:wait('first file',function() return tui:state().file==tui.a..'/first.txt' end)
  tui:send('23G07l')
  phase('vsplit second.txt');tui:command('vsplit second.txt')
  e:wait('second file',function() return tui:state().file==tui.a..'/second.txt' end)
  tui:send('37G05l')
  phase('Explorer');tui:send(' e')
  e:wait('Explorer open',function()
    for _,t in ipairs(tui:state().tabs) do for _,w in ipairs(t.windows) do if w.ft=='neo-tree' then return true end end end
  end)
  phase('tabedit third.txt');tui:command('tabedit third.txt')
  e:wait('third file in new tab',function() local s=tui:state();return s.file==tui.a..'/third.txt' and #s.tabs==2 end)
  tui:send('47G03l')
  phase('Quickfix');tui:command([=[cgetexpr ['third.txt:47:1:FORGE_SESSION_QUICKFIX']]=]);tui:command('copen')
  e:wait('Quickfix open',function()
    for _,t in ipairs(tui:state().tabs) do for _,w in ipairs(t.windows) do if w.ft=='qf' then return true end end end
  end)
  report.final=tui:state();phase('completed workflow');e:snapshot('native-assert-observed')
end,debug.traceback)
if tui then
  report=report or {artifacts=tui.host.dir}
  report.ok=ok;report.error=not ok and tostring(err) or nil;report.observers={}
  for _,observer in ipairs(observers) do
    local stopped,result=pcall(observer.stop,observer)
    local row={dir=observer.dir,pid=observer.pid,debugger_pid=observer.debugger_pid,done=stopped and result or nil,error=not stopped and tostring(result) or nil}
    if vim.fn.filereadable(observer.dir..'/capture.json')==1 then
      row.capture=vim.json.decode(table.concat(vim.fn.readfile(observer.dir..'/capture.json'),'\n'))
      local args=row.capture.assertion_args
      if row.capture.assertion and args and args.expression=='!stream->closed' then report.original_reproduced=true end
    end
    if not stopped or result.outcome~='stop-request' or not result.detached then
      ok=false;err=not stopped and tostring(result) or result.error or ('Observer ended: '..result.outcome);report.error=err
    end
    if stopped then
      local exited,exit=pcall(observer.wait,observer,'debugger-exit.json',5000)
      if not exited or exit.code~=0 then ok=false;err='Debugger did not exit normally: '..vim.inspect(exit);report.error=err end
    end
    report.observers[#report.observers+1]=row
  end
  report.ok=ok
  assert(vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/native-assert-trial.json')==0)
  local stopped,cleanup=pcall(tui.stop,tui,not ok and err or nil)
  io.stdout:write('artifacts: '..tui.host.dir..'\n')
  if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
  report.cleanup_ok=stopped;report.ok=ok;report.error=not ok and tostring(err) or nil
  assert(vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/native-assert-trial.json')==0)
end
assert(ok,err)
io.stdout:write('Observed original workflow completed; see report for capture status\n')
