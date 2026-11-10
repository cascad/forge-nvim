-- Production SDK jobstop/normal quit, real root + child and a separate owned worker.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
if vim.fn.has('win32')~=1 then
  T.skip('IDE-BOOT-6 native Windows SDK process lifecycle','Windows SDK only; POSIX uses official Neovim')
  return T.finish()
end
local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
local fixture=root..'/tests/e2e/process_lifecycle_worker.py'
local function alive(pid) return vim.uv.kill(pid,0)~=nil end
local function wait(label,fn) assert(vim.wait(5000,fn,10),label) end
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
for _,mode in ipairs({'jobstop','quit'}) do
  T.check('IDE-BOOT-6 native '..mode..' stops job descendants and preserves independent worker',function()
    assert(python~='','Host Python required')
    local dir=root..'/.tests/process-lifecycle/'..tostring(vim.uv.hrtime())
    vim.fn.mkdir(dir..'/own','p');vim.fn.mkdir(dir..'/independent','p')
    local primary,independent,result,shutdown,other_shutdown
    local function start(name)
      return require('editor_rpc').start({vim.v.progpath,'--clean','--headless','--embed','-i','NONE'},
        {cwd=dir,artifacts=dir..'/'..name,timeout=25000,
          env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/'..name..'/nvim.log'})})
    end
    local function lua(rpc,code,args) return rpc:request('nvim_exec_lua',{code,args or {}}) end
    local function quit(rpc,name)
      rpc.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}}))
      wait('native exit',function() return rpc.exited end)
      local started=vim.uv.hrtime()
      local accounting_before=rpc.scope.active_count and rpc.scope:active_count() or nil
      if rpc.scope.active_count then wait('native job accounting drained',function() return rpc.scope:active_count()==0 end) end
      result.native_quit_observations=result.native_quit_observations or {}
      result.native_quit_observations[name]={active_at_exit_callback=accounting_before,drain_ms=(vim.uv.hrtime()-started)/1e6}
      return require('editor_process').stop(rpc,dir..'/'..name)
    end
    local ok,err=xpcall(function()
      independent=start('independent');primary=start('own')
      local launch=[[local python,fixture,mode,folder=...;return vim.fn.jobstart({python,'-B',fixture,mode,folder})]]
      local other_job=lua(independent,launch,{python,fixture,'independent',dir..'/independent'})
      local job=lua(primary,launch,{python,fixture,'root',dir..'/own'})
      assert(job>0 and other_job>0,'jobstart failed')
      wait('workers ready',function()
        return vim.fn.filereadable(dir..'/own/root.json')==1 and vim.fn.filereadable(dir..'/independent/independent.json')==1
      end)
      local parent,child,other=read(dir..'/own/root.json'),read(dir..'/own/child.json'),read(dir..'/independent/independent.json')
      T.eq(child.ppid,parent.pid,'real child ancestry')
      assert(alive(parent.pid) and alive(child.pid) and alive(other.pid),'workers must start alive')
      result={mode=mode,executable=vim.v.progpath,root=parent,child=child,independent=other}
      if mode=='jobstop' then
        T.eq(lua(primary,'return vim.fn.jobstop(...)',{job}),1)
        wait('job root and child exited',function() return not alive(parent.pid) and not alive(child.pid) end)
        wait('jobwait exit',function() return lua(primary,'return vim.fn.jobwait({...},0)[1]',{job})~=-1 end)
        T.eq(lua(primary,'return vim.fn.jobstop(...)',{job}),0)
      else
        shutdown=quit(primary,'own')
        wait('quit stopped root and child',function() return not alive(parent.pid) and not alive(child.pid) end)
      end
      result.independent_alive=alive(other.pid)
      assert(result.independent_alive,'independent worker was terminated')
      result.descendants_exited=not alive(parent.pid) and not alive(child.pid)
      vim.fn.writefile({'release'},dir..'/independent/release')
      wait('independent worker released',function() return not alive(other.pid) end)
      shutdown=shutdown or quit(primary,'own')
      other_shutdown=quit(independent,'independent')
      for _,closing in ipairs({shutdown,other_shutdown}) do
        assert(closing.ok and closing.exited and closing.exit_code==0 and closing.exit_signal==0,vim.inspect(closing))
        T.eq(closing.api_errors,{})
        if vim.fn.has('win32')==1 then T.eq(closing.scope.active_before,0,'no scope termination should be needed') end
      end
    end,debug.traceback)
    shutdown=shutdown or require('editor_process').stop(primary,dir..'/own',not ok and tostring(err) or nil)
    other_shutdown=other_shutdown or require('editor_process').stop(independent,dir..'/independent',not ok and tostring(err) or nil)
    result=result or {mode=mode,executable=vim.v.progpath}
    result.ok=ok;result.error=not ok and tostring(err) or nil
    result.shutdown=shutdown;result.independent_shutdown=other_shutdown
    vim.fn.writefile({vim.json.encode(result)},dir..'/result.json')
    assert(ok,tostring(err)..'\nartifacts: '..dir)
  end)
end
T.finish()
