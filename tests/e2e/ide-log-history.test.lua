-- spec: IDE-LOG-4. Реальные разные TUI процессы с общим native state.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-LOG-4 native quit relaunch damaged history and inactive retention',function()
  local helper,report={},{sessions={}}
  local ok,err=xpcall(function()
    helper=require('session_tui').start(root)
    local e=helper.host
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/ide-log-history.test.lua',e.dir..'/ide-log-history.test.lua'))
    local host= e:lua([[local s=require('forge.log_store');return {pid=vim.uv.os_getpid(),session=s.session,path=s.path}]])
    report.host=host
    local function open()
      helper:normal();helper:command('ForgeLogs')
      e:wait('native console visible',function()
        return helper:lua('return vim.bo.filetype')=='forge-logs'
      end)
      return helper:lua([[local s=require('forge.log_store');return {pid=vim.uv.os_getpid(),
        path=s.path,session=s.session,entries=s.entries(),damaged=s.damaged,error=s.disk_error or false,
        text=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'),
        installs=_G.forge_session_installs,notices=_G.forge_session_notices}]])
    end
    helper:launch()
    helper:lua([[vim.notify('LOG_RESTART_FIRST',vim.log.levels.WARN,{title='Setup'})]])
    local first=open();report.sessions[#report.sessions+1]=first
    assert(first.text:find('LOG_RESTART_FIRST',1,true));T.eq(first.error,false)
    helper:quit()
    assert(first.path:find(e.runtime,1,true)==1,'History outside own profile')
    assert(vim.fn.writefile({'{BROKEN_HISTORY_LINE'},first.path,'a')==0)
    local damaged=assert(io.open(first.path,'rb'));report.damaged_file=damaged:read('*a');damaged:close()
    helper:launch()
    local second=open();report.sessions[#report.sessions+1]=second
    assert(second.pid~=first.pid and second.session~=first.session,'Native backend did not restart')
    assert(second.text:find('LOG_RESTART_FIRST',1,true),'Previous session message lost')
    assert(second.text:find('Повреждённые строки истории:',1,true) and second.damaged==1,'Corruption silently ignored')
    helper:quit()
    for i=1,9 do
      helper:launch()
      helper:lua([[vim.notify('LOG_RETENTION_SESSION_'..(...),vim.log.levels.WARN,{title='Setup'})]],{i})
      local current=open();report.sessions[#report.sessions+1]=current
      T.eq(current.installs,0);T.eq(current.error,false)
      if i<9 then helper:quit() end
    end
    local last=report.sessions[#report.sessions]
    assert(not vim.uv.fs_stat(first.path),'Old inactive session not pruned')
    assert(vim.uv.fs_stat(host.path),'Active parent history removed')
    assert(vim.uv.fs_stat(last.path),'Current writer removed')
    local directory=vim.fn.fnamemodify(last.path,':h')
    report.files={};local inactive={}
    vim.fn.mkdir(e.dir..'/forge-history','p')
    for name,kind in vim.fs.dir(directory) do
      if kind=='file' then
        local path=directory..'/'..name
        assert(vim.uv.fs_copyfile(path,e.dir..'/forge-history/'..name))
        local stat=assert(vim.uv.fs_stat(path));report.files[#report.files+1]={name=name,size=stat.size}
        local session=name:match('^(%d+%-%d+%-%d+)%.jsonl')
        if session and session~=host.session and session~=last.session then inactive[session]=true end
      end
    end
    local count=0;for _ in pairs(inactive) do count=count+1 end
    T.eq(count,8,'Inactive retention must keep eight sessions')
    helper:quit()
    e:snapshot('native-log-history')
  end,debug.traceback)
  if helper.host then
    local e=helper.host;report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/ide-log-history.json')
    io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,issue=pcall(helper.stop,helper,not ok and err or nil);assert(stopped,issue)
    assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'Native host/API failure')
  end
  assert(ok,err)
end)
T.finish()
