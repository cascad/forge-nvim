-- Native TUI inside an owned private editor terminal. No restart UI emulation.
local M={}
local function start(root,holder)
  local self={root=root,connections={}}
  holder.self=self
  self.host=require('editor').start(root,{timeout=210000,prepare=function(project,env,runtime)
    env.FORGE_SESSION_PROBE=runtime..'/session-probe'
    vim.fn.mkdir(env.FORGE_SESSION_PROBE,'p')
    assert(vim.uv.fs_copyfile(root..'/tests/lib/session_tui_native.lua',env.FORGE_SESSION_PROBE..'/observer.lua'))
    for _,name in ipairs({'Project A ü','Project B ü'}) do
      local path=project..'/'..name;vim.fn.mkdir(path,'p')
      local r=vim.system({'git','init','--initial-branch=main',path},{text=true}):wait();assert(r.code==0,r.stderr)
      for _,file in ipairs({'first.txt','second.txt','third.txt'}) do
        local lines={};for i=1,80 do lines[i]=file..' line '..i..' | '..name end
        assert(vim.fn.writefile(lines,path..'/'..file)==0)
      end
    end
  end})
  local e=self.host
  self.base=e.runtime..'/session-probe'
  self.a=(e.project..'/Project A ü'):gsub('\\','/')
  self.b=(e.project..'/Project B ü'):gsub('\\','/')
  for _,name in ipairs({'session_tui.lua','session_tui_native.lua'}) do
    assert(vim.uv.fs_copyfile(root..'/tests/lib/'..name,e.dir..'/'..name))
  end
  e:wait('host ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
  -- Host is a fixture terminal, its quit must not overwrite the TUI's session.
  e:lua([[require('persistence').stop()]])
  self.sessions=e:lua([[return require('persistence.config').options.dir]])
  function self:save_sessions(label)
    local target=e.dir..'/sessions-'..label;vim.fn.mkdir(target,'p')
    for name,kind in vim.fs.dir(self.sessions) do
      assert(kind=='file','Unexpected session entry: '..name)
      assert(vim.uv.fs_copyfile(self.sessions..'/'..name,target..'/'..name))
    end
  end
  function self:send(keys)
    return e:lua([[return vim.fn.chansend(_G.forge_session_job,...)]],{keys})
  end
  function self:mode() return vim.rpcrequest(self.channel,'nvim_get_mode') end
  function self:normal()
    self:send('\27')
    e:wait('native Escape reaches Normal mode',function()
      local mode=self:mode();return mode.mode=='n' and not mode.blocking
    end)
  end
  function self:command(command)
    local mode=self:mode();assert(mode.mode=='n' and not mode.blocking,'TUI command requires Normal mode')
    self:send(':'..command..'\r')
  end
  function self:launch()
    assert(not self.job or self:job_state().exit~=false,'TUI still running')
    vim.fn.delete(self.base..'/ready.json')
    self.job=e:lua([[local cwd,observer=...;vim.cmd('enew')
      _G.forge_session_exit=nil
      _G.forge_session_job=vim.fn.jobstart({vim.v.progpath,'-i','NONE','--cmd','lua dofile('..vim.inspect(observer)..')',
        '-u',vim.fn.stdpath('config')..'/init.lua'},
        {term=true,cwd=cwd,on_exit=function(_,code) _G.forge_session_exit=code end})
      assert(_G.forge_session_job>0,'Native TUI failed to start')
      _G.forge_session_terminal=vim.api.nvim_get_current_buf()
      return _G.forge_session_job]],{self.a,self.base..'/observer.lua'})
    return self:connect()
  end
  function self:connect(previous_pid)
    local ready
    e:wait('new native TUI backend ready',function()
      if vim.fn.filereadable(self.base..'/ready.json')~=1 then return false end
      ready=vim.json.decode(table.concat(vim.fn.readfile(self.base..'/ready.json'),'\n'))
      return ready.pid~=previous_pid and ready.server~=''
    end,20000)
    local channel=vim.fn.sockconnect('pipe',ready.server,{rpc=true})
    assert(channel>0,'Cannot connect to native TUI backend: '..ready.server)
    self.connections[#self.connections+1]=channel;self.channel=channel
    local actual=self:lua('return vim.uv.os_getpid()');assert(actual==ready.pid,'Stale ready PID')
    return ready
  end
  function self:lua(code,args)
    assert(not self:mode().blocking,'Native TUI is waiting for input; inspect host screen')
    return vim.rpcrequest(self.channel,'nvim_exec_lua',code,args or {})
  end
  function self:state()
    return self:lua([[local tabs={};for _,t in ipairs(vim.api.nvim_list_tabpages()) do
      local wins={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(t)) do
        local b=vim.api.nvim_win_get_buf(w);local c=vim.api.nvim_win_get_config(w)
        wins[#wins+1]={win=w,file=vim.api.nvim_buf_get_name(b):gsub('\\','/'),ft=vim.bo[b].filetype,
          bt=vim.bo[b].buftype,cursor=vim.api.nvim_win_get_cursor(w),floating=c.relative~='',
          fixed=vim.wo[w].winfixwidth or vim.wo[w].winfixheight,marker=not not vim.w[w].forge_panel}
      end;tabs[#tabs+1]={id=t,windows=wins} end
      local buffers={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buftype=='' and vim.api.nvim_buf_get_name(b)~='' then
          buffers[#buffers+1]={file=vim.api.nvim_buf_get_name(b):gsub('\\','/'),loaded=vim.api.nvim_buf_is_loaded(b),modified=vim.bo[b].modified}
        end
      end
      return {pid=vim.uv.os_getpid(),cwd=vim.fn.getcwd():gsub('\\','/'),tabs=tabs,buffers=buffers,
        current=vim.api.nvim_get_current_win(),file=vim.api.nvim_buf_get_name(0):gsub('\\','/'),
        cursor=vim.api.nvim_win_get_cursor(0),mode=vim.api.nvim_get_mode(),
        messages=vim.fn.execute('messages'),notices=_G.forge_session_notices,installs=_G.forge_session_installs,
        ui=vim.api.nvim_list_uis()}]])
  end
  function self:job_state()
    return e:lua([[return {job=_G.forge_session_job,exit=_G.forge_session_exit or false,
      text=vim.api.nvim_buf_get_lines(_G.forge_session_terminal,0,-1,false)}]])
  end
  function self:quit()
    self:normal()
    self:command('qa!')
    e:wait('native TUI exited',function() return self:job_state().exit~=false end,10000)
    assert(self:job_state().exit==0,'Native TUI exit nonzero')
  end
  function self:stop(primary)
    if self.stopped then return end
    local failures={}
    local function attempt(fn) local ok,err=pcall(fn);if not ok then failures[#failures+1]=tostring(err) end end
    attempt(function()
      if self.job and self:job_state().exit==false then self:quit() end
    end)
    for _,c in ipairs(self.connections) do pcall(vim.fn.chanclose,c) end
    attempt(function()
      if self.job then assert(vim.fn.writefile({vim.json.encode(self:job_state())},e.dir..'/tui-final.json')==0) end
      for _,name in ipairs({'lifecycle.jsonl','ready.json'}) do
        if vim.fn.filereadable(self.base..'/'..name)==1 then assert(vim.uv.fs_copyfile(self.base..'/'..name,e.dir..'/'..name)) end
      end
    end)
    attempt(function()
      e:snapshot('host-before-native-quit')
      e.rpc.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}}))
      e:wait('host native exit',function() return e.rpc.exited end,10000)
      local observed={exit_code=e.rpc.exit_code,exit_signal=e.rpc.exit_signal}
      local started=vim.uv.hrtime()
      -- Native exit callback can precede the Windows Job accounting update.
      -- Match the existing lifecycle E2E: observe the drain before closing Job.
      if e.rpc.scope.active_count then
        observed.active_at_exit_callback=e.rpc.scope:active_count()
        e:wait('host job accounting drained',function() return e.rpc.scope:active_count()==0 end)
        observed.active_after=e.rpc.scope:active_count()
      end
      observed.drain_ms=(vim.uv.hrtime()-started)/1e6
      assert(vim.fn.writefile({vim.json.encode(observed)},e.dir..'/native-host-exit.json')==0)
    end)
    attempt(function() e:stop(primary) end)
    self.stopped=e.stopped
    assert(#failures==0,table.concat(failures,'\n'))
  end
  return self
end
function M.start(root)
  local holder={}
  local ok,result=xpcall(function() return start(root,holder) end,debug.traceback)
  if ok then return result end
  local self=holder.self
  if self and self.host then
    local closed,cleanup=pcall(function()
      if self.stop then self:stop(result) else self.host:stop(result) end
    end)
    if not closed then result=result..'\nCleanup: '..tostring(cleanup) end
  end
  error(result)
end
return M
