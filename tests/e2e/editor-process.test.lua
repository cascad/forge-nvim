local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local legacy=vim.env.FORGE_EDITOR_STOP_LEGACY_SOURCE
local function stopper()
  if not legacy then return require('editor_process') end
  local text=table.concat(vim.fn.readfile(legacy),'\n')..'\n'
  T.eq(vim.fn.sha256(text),'d7f923b739ed873bd4a6e85d6e1633c523cedcedb9c9aa418383874faecff1b2')
  -- Экспорт исходной функции без изменения её тела, только для baseline RED.
  local body,n=text:gsub('\nreturn M%s*$','\nreturn {stop=stop_process}\n')
  T.eq(n,1)
  return assert(loadstring(body,'@'..legacy))()
end
local function check(name,fn)
  if vim.env.FORGE_EDITOR_PROCESS_CASE and not name:find(vim.env.FORGE_EDITOR_PROCESS_CASE,1,true) then return end
  T.check('SELF: EDITOR-PROCESS '..name,function()
    local dir=root..'/.tests/editor-process-e2e/'..tostring(vim.uv.hrtime())
    vim.fn.mkdir(dir,'p')
    local rpc,result
    local ok,err=xpcall(function()
      rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE'},
        {cwd=root,timeout=30000,artifacts=dir,env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/nvim.log'})})
      T.eq(rpc:request('nvim_eval',{'1+1'}),2)
      result=fn(rpc,dir,stopper())
    end,debug.traceback)
    -- Старый helper после RED оставляет остановленный child: убираем только свой handle.
    local cleaned=true
    if rpc and not rpc.exited then
      pcall(function() rpc.process:kill('sigkill') end)
      cleaned=vim.wait(2000,function() return rpc.exited end,10)
    end
    vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and tostring(err) or nil,result=result,
      pid=rpc and rpc.process.pid,child_exit=rpc and rpc.exit_code,child_signal=rpc and rpc.exit_signal,cleaned=cleaned,legacy_source=legacy})},dir..'/test.json')
    if rpc then vim.fn.writefile(vim.split(table.concat(rpc.stderr),'\n'),dir..'/stderr.log') end
    io.stdout:write('  artifacts: '..dir..'\n')
    assert(cleaned,'Не завершён собственный child; '..dir)
    assert(ok,err)
  end)
end
check('normal RPC child завершается через qa без сигнала',function(rpc,dir,helper)
  local result=helper.stop(rpc,dir)
  T.eq(result.ok,true);T.eq(result.exited,true);T.eq(result.hard_kill,false)
  T.eq(rpc.exit_code,0)
  T.eq(rpc.exit_signal,0)
  local data=vim.json.decode(table.concat(vim.fn.readfile(dir..'/shutdown.json'),'\n'))
  T.eq(data.pid,rpc.process.pid);T.eq(data.stages[1].stage,'quit');T.eq(data.stages[#data.stages].stage,'exited')
  for _,stage in ipairs(data.stages) do assert(stage.stage~='sigterm' and stage.stage~='sigkill') end
  T.eq(helper.stop(rpc,dir),result,'повторный stop сохраняет verdict')
  return result
end)
if vim.fn.has('win32')==1 then
  if not vim.env.FORGE_EDITOR_PROCESS_CASE or ('forced'):find(vim.env.FORGE_EDITOR_PROCESS_CASE,1,true) then
    T.skip('SELF: EDITOR-PROCESS forced SIGSTOP child','POSIX SIGSTOP отсутствует на Windows')
  end
else
  check('forced SIGSTOP child сохраняет RPC timeout и завершается SIGKILL с FAIL',function(rpc,dir,helper)
    rpc.process:kill('sigstop')
    assert(vim.wait(2000,function()
      local state=vim.system({'ps','-o','stat=','-p',tostring(rpc.process.pid)},{text=true,timeout=1000}):wait()
      return state.code==0 and state.stdout:match('^%s*T')~=nil
    end,25),'Child не остановлен SIGSTOP')
    local ok,err=pcall(rpc.request,rpc,'nvim_get_mode',{})
    assert(not ok and tostring(err):find('RPC timeout: nvim_get_mode',1,true),tostring(err))
    local result=helper.stop(rpc,dir,tostring(err))
    T.eq(result.ok,false);T.eq(result.exited,true);T.eq(result.hard_kill,true)
    assert(result.error:find('RPC timeout: nvim_get_mode',1,true),result.error)
    local data=vim.json.decode(table.concat(vim.fn.readfile(dir..'/shutdown.json'),'\n'))
    T.eq(data.rpc_failure.method,'nvim_get_mode');T.eq(data.rpc_failure.timeout_ms,10000)
    T.eq(data.primary_error,tostring(err));T.eq(data.exited,true)
    T.eq(data.exit_signal,9)
    local failure=vim.json.decode(table.concat(vim.fn.readfile(dir..'/rpc-error.json'),'\n'))
    T.eq(failure.method,'nvim_get_mode');T.eq(failure.pid,rpc.process.pid)
    T.eq(data.stages[#data.stages].stage,'exited')
    assert(vim.iter(data.stages):any(function(s) return s.stage=='sigkill' end),'Нет этапа SIGKILL')
    T.eq(helper.stop(rpc,dir).error,result.error,'повторный stop не теряет первичную ошибку')
    return result
  end)
end
T.finish()
