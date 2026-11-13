-- Native TUI handles :restart; controller checks persisted state across real PIDs.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-PANEL-15 native session restore returns code focus and preserves project state',function()
  local dir=root..'/.tests/project-session/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
  assert(vim.uv.fs_copyfile(root..'/tests/e2e/project-session.test.lua',dir..'/project-session.test.lua'))
  local result=vim.system({vim.v.progpath,'-l',root..'/tests/diagnostics/project-session.lua'},
    {cwd=root,text=true,timeout=180000,env={NVIM_LOG_FILE=dir..'/controller.log'}}):wait()
  assert(vim.fn.writefile(vim.split((result.stdout or '')..(result.stderr or ''),'\n'),dir..'/child.log')==0)
  local artifact=assert((result.stdout or ''):match('artifacts: ([^\r\n]+)'),result.stderr)
  artifact=artifact:gsub('\\','/'):gsub('%s+$','')
  local prefix=root..'/.tests/editor-e2e/'
  assert(artifact:sub(1,#prefix)==prefix and artifact:sub(#prefix+1):match('^%d+$'),'Unexpected artifact path')
  io.stdout:write('  artifacts: '..artifact..'; controller: '..dir..'\n')
  local function read(name) return vim.json.decode(table.concat(vim.fn.readfile(artifact..'/'..name),'\n')) end
  local report=read('project-session.json')
  assert(vim.fn.writefile({vim.json.encode({artifact=artifact,child_exit=result.code,child_signal=result.signal})},dir..'/result.json')==0)
  assert(result.code==0 and result.signal==0 and report.ok,report.error or 'Native baseline failed; see child.log')
  local seen={}
  for _,key in ipairs({'initial','relaunch','switched','returned'}) do
    local pid=report[key].pid;assert(not seen[pid],'Backend PID did not change');seen[pid]=true
  end
  local states={}
  for _,row in ipairs(report.states) do
    local s=row.state;states[row.label]=s
    assert(#s.ui>0 and not s.mode.blocking,'Real UI/readiness missing')
    T.eq(s.installs,0,'Unexpected tool install')
    assert(not s.messages:match('E%d%d%d+:'),s.messages)
    for _,notice in ipairs(s.notices) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
  end
  local a,b=states.initial.cwd,states['project-b'].cwd
  assert(a~=b and a:match('Project A ü$') and b:match('Project B ü$'))
  T.eq(#states.relaunched.buffers,0,'Fresh launch must not inherit previous process buffers')
  local function layout(s)
    local out={}
    for _,tab in ipairs(s.tabs) do
      local files={}
      for _,w in ipairs(tab.windows) do
        if not w.floating and w.bt=='' and w.file~='' then
          assert(not w.fixed and not w.marker,'Restored file trapped in panel')
          files[#files+1]={file=w.file,cursor=w.cursor}
        end
      end
      out[#out+1]=files
    end
    return out
  end
  local expected={{{file=a..'/first.txt',cursor={23,7}},{file=a..'/second.txt',cursor={37,5}}},
    {{file=a..'/third.txt',cursor={47,3}}}}
  T.eq(layout(states['before-quit']),expected)
  local function count(s,ft)
    local n=0;for _,tab in ipairs(s.tabs) do for _,w in ipairs(tab.windows) do if w.ft==ft then n=n+1 end end end;return n
  end
  T.eq(count(states['before-quit'],'qf'),1);assert(count(states['before-quit'],'neo-tree')>0)
  for _,label in ipairs({'restored','project-a-returned'}) do
    local s=states[label];T.eq(layout(s),expected,label);T.eq(s.cwd,a)
    T.eq(count(s,'qf'),0,'Quickfix must not survive session restore');assert(count(s,'neo-tree')>0,'Explorer missing')
    for _,tab in ipairs(s.tabs) do for _,w in ipairs(tab.windows) do
      if not w.floating then assert(w.bt=='' or w.ft=='neo-tree','Unexpected restored tool window: '..w.ft) end
    end end
    T.eq(#s.buffers,3)
    for _,buf in ipairs(s.buffers) do assert(buf.file:sub(1,#a+1)==a..'/' and buf.loaded and not buf.modified) end
  end
  T.eq(#states['project-b'].buffers,0,'Previous project buffers leaked into B')
  T.eq(#states['project-b-edit'].buffers,1);T.eq(states['project-b-edit'].buffers[1].file,b..'/first.txt')
  local modified=false
  for _,buf in ipairs(states['before-switch'].buffers) do if buf.file==a..'/third.txt' then modified=buf.modified end end
  T.eq(modified,true,'Fixture did not exercise unsaved change')
  T.eq(report.written_on_switch,'third.txt line 47 | Project A ü_FORGE_MODIFIED','Switch must write modified file')
  T.eq(report.loaded_after_return,report.written_on_switch,'Returned buffer must contain saved change')
  local events={}
  for _,line in ipairs(vim.fn.readfile(artifact..'/lifecycle.jsonl')) do
    local row=vim.json.decode(line);events[row.pid]=events[row.pid] or {};events[row.pid][row.event]=true
  end
  for pid in pairs(seen) do
    local e=assert(events[pid]);assert(e.VimEnter and e.ready and e.VimLeavePre and e.VimLeave and e.PersistenceSavePost)
  end
  assert(events[report.relaunch.pid].PersistenceLoadPost and events[report.returned.pid].PersistenceLoadPost)
  local copies=0
  for _,label in ipairs({'first-quit','switch-b','returned-a'}) do
    for name in vim.fs.dir(artifact..'/sessions-'..label) do
      local text=table.concat(vim.fn.readfile(artifact..'/sessions-'..label..'/'..name),'\n')
      assert(text:find('third.txt',1,true) or name:find('Project B',1,true),'Session source missing files')
      -- mksession also saves window-local statusline text, including old panel
      -- titles. Actual restored windows above establish panel safety.
      assert(text:find('SessionLoad',1,true),'Native session source missing')
      copies=copies+1
    end
  end
  assert(copies>=4,'Session source copies missing')
  T.eq(read('tui-final.json').exit,0)
  local native_exit=read('native-host-exit.json')
  T.eq(native_exit.exit_code,0);T.eq(native_exit.exit_signal,0)
  if native_exit.active_after~=nil then T.eq(native_exit.active_after,0) end
  local shutdown=read('shutdown.json')
  assert(shutdown.ok and shutdown.exit_code==0 and shutdown.exit_signal==0 and not shutdown.hard_kill)
  T.eq(shutdown.api_errors,{})
  assert(shutdown.scope.ok and (shutdown.scope.active_after==0 or shutdown.scope.active_after==false) and not shutdown.scope.terminated)
  T.eq(shutdown.scope.stages or {},{},'Scope cleanup must not need signals')
  for _,stage in ipairs(shutdown.stages) do assert(stage.stage~='sigterm' and stage.stage~='sigkill') end
  for _,label in ipairs({'restored','project-a-returned'}) do
    local s=states[label];local focused
    for _,tab in ipairs(s.tabs) do for _,w in ipairs(tab.windows) do if w.win==s.current then focused=w end end end
    assert(focused and focused.bt=='' and focused.ft=='text' and not focused.floating and not focused.marker,
      'Restore focus '..label..': '..vim.inspect(focused))
  end
  local fresh=states['project-b'];local fresh_ft
  for _,tab in ipairs(fresh.tabs) do for _,w in ipairs(tab.windows) do if w.win==fresh.current then fresh_ft=w.ft end end end
  T.eq(fresh_ft,'neo-tree','A fresh project without a session keeps Explorer focus')
end)
T.check('IDE-PANEL-29 filesystem root survives project switch and native session restore',function()
  local tui,report
  local ok,err=xpcall(function()
    tui=require('session_tui').start(root)
    report={states={}}
    local e=tui.host
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/project-session.test.lua',e.dir..'/project-session.test.lua'))
    local function capture(label)
      local state=tui:state();report.states[#report.states+1]={label=label,state=state}
      e:snapshot(label);return state
    end
    report.initial=tui:launch();capture('initial')
    local fsroot=vim.fn.has('win32')==1 and assert(tui.a:match('^%a:'))..'/' or '/'
    report.root=fsroot
    tui:command('lua require("config.start").open_project('..vim.inspect(fsroot)..', {open_files=false})')
    report.selected=tui:connect(report.initial.pid)
    T.eq(capture('root-selected').cwd,fsroot)
    local file=tui.a..'/first.txt';report.file=file
    tui:command('edit '..vim.fn.fnameescape(file))
    e:wait('private file opened under filesystem root',function() return tui:state().file==file end)
    tui:send('A_ROOT_SESSION_EDIT')
    e:wait('root file edit reached native TUI',function()
      return tui:mode().mode=='i' and tui:lua('return vim.bo.modified and vim.api.nvim_get_current_line():find("_ROOT_SESSION_EDIT",1,true)~=nil')
    end)
    tui:normal()
    local before=capture('root-edited')
    T.eq(before.cwd,fsroot)
    assert(before.buffers[1] and before.buffers[1].modified,'Fixture did not modify a file')
    report.session=tui:lua("return require('persistence').current()")
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')')
    report.switched=tui:connect(report.selected.pid)
    T.eq(capture('project-b').cwd,tui.b)
    T.eq(vim.fn.filereadable(report.session),1,'Filesystem root session was not saved')
    report.written=vim.fn.readfile(file)[1]
    T.eq(report.written,'first.txt line 1 | Project A ü_ROOT_SESSION_EDIT')
    tui:save_sessions('filesystem-root-left')
    tui:command('lua require("config.start").open_project('..vim.inspect(fsroot)..', {open_files=false})')
    report.returned=tui:connect(report.switched.pid)
    e:wait('filesystem root file restored',function()
      local state=tui:state();return state.cwd==fsroot and state.file==file
    end,10000)
    local restored=capture('root-restored')
    T.eq(#restored.buffers,1)
    report.loaded=tui:lua('return vim.api.nvim_buf_get_lines(0,0,1,false)[1]')
    T.eq(report.loaded,report.written)
    local pids={}
    for _,key in ipairs({'initial','selected','switched','returned'}) do
      local pid=report[key].pid;assert(not pids[pid],'Backend PID did not change');pids[pid]=true
    end
    for _,row in ipairs(report.states) do
      local state=row.state;T.eq(state.installs,0);assert(#state.ui>0 and not state.mode.blocking)
      for _,notice in ipairs(state.notices) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
    end
  end,debug.traceback)
  if tui then
    report=report or {states={}}
    local got,state=pcall(tui.state,tui);if got then report.final_state=state end
    report.ok=ok;report.error=not ok and tostring(err) or nil
    assert(vim.fn.writefile({vim.json.encode(report)},tui.host.dir..'/project-root.json')==0)
    local stopped,cleanup=pcall(tui.stop,tui,not ok and err or nil)
    io.stdout:write('  artifacts: '..tui.host.dir..'\n')
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
    if stopped then
      local function read(name) return vim.json.decode(table.concat(vim.fn.readfile(tui.host.dir..'/'..name),'\n')) end
      local shutdown=read('shutdown.json')
      assert(shutdown.ok and shutdown.exit_code==0 and shutdown.exit_signal==0 and not shutdown.hard_kill)
      T.eq(shutdown.api_errors,{})
      assert(shutdown.scope.ok and (shutdown.scope.active_after==0 or shutdown.scope.active_after==false))
      T.eq(read('tui-final.json').exit,0)
      local host=read('native-host-exit.json');T.eq(host.exit_code,0);T.eq(host.exit_signal,0)
    end
  end
  assert(ok,err)
end)
T.finish()
