-- IDE-117: actual OS command outcome, собственный clean native editor/PGID.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
if vim.env.FORGE_E2E_DRIVER_SOURCE then package.path=vim.env.FORGE_E2E_DRIVER_SOURCE..'/?.lua;'..package.path end
local T=require('check')
local cases={
  {name='nonzero code сохраняет native stdout и пустой stderr',kind='code'},
  {name='native signal не считается пустой таблицей групп',kind='signal'},
  {name='ошибка spawn сохраняется без выдуманного exit code',kind='spawn'},
  {name='реальный ps сохраняет успешный cleanup',kind='real'},
}
if vim.fn.has('win32')==1 then
  for _,case in ipairs(cases) do T.skip('SELF: POSIX-SCOPE-PROBE '..case.name,'POSIX boundary; нужен native Ubuntu/macOS') end
  T.finish();return
end
local real_ps=vim.fn.exepath('ps');assert(real_ps~='','Нужен настоящий ps')
local scope_source=debug.getinfo(require('process_scope_posix').new,'S').source:sub(2)
local fixture=root..'/tests/e2e/fixtures/process-scope-probe/ps.sh'
for _,case in ipairs(cases) do
  T.check('SELF: POSIX-SCOPE-PROBE '..case.name,function()
    local dir=root..'/.tests/posix-scope-probe/'..tostring(vim.uv.hrtime())
    vim.fn.mkdir(dir..'/bin','p')
    local env_keys={'PATH','FORGE_PS_PROBE_CASE','FORGE_PS_PROBE_CALLS','FORGE_PS_PROBE_REAL'}
    local saved={};for _,key in ipairs(env_keys) do saved[key]=vim.env[key] or false end
    local function restore()
      for _,key in ipairs(env_keys) do vim.env[key]=saved[key]~=false and saved[key] or nil end
    end
    local rpc,receipt
    local ok,err=xpcall(function()
      assert(vim.uv.fs_copyfile(scope_source,dir..'/scope-source.lua'))
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/posix-scope-probe.test.lua',dir..'/posix-scope-probe.test.lua'))
      assert(vim.uv.fs_copyfile(fixture,dir..'/ps.sh'))
      if case.kind=='spawn' then
        local missing='/__forge_missing_ps_interpreter_'..vim.uv.os_getpid()..'__'
        assert(not vim.uv.fs_stat(missing),'Missing interpreter должен отсутствовать')
        vim.fn.writefile({'#!'..missing},dir..'/bin/ps')
      else assert(vim.uv.fs_copyfile(fixture,dir..'/bin/ps')) end
      assert(vim.uv.fs_chmod(dir..'/bin/ps',493))
      rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE'},
        {cwd=root,timeout=30000,artifacts=dir,env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/nvim.log'})})
      T.eq(rpc:request('nvim_eval',{'1+1'}),2)
      -- execvp can skip a missing shebang interpreter and continue searching
      -- PATH. The spawn case must not reach the real system ps as a fallback.
      vim.env.PATH=dir..'/bin'..(case.kind=='spawn' and '' or ':'..saved.PATH)
      vim.env.FORGE_PS_PROBE_CASE=case.kind
      vim.env.FORGE_PS_PROBE_CALLS=dir..'/probe-calls.txt'
      vim.env.FORGE_PS_PROBE_REAL=real_ps
      local primary=case.kind~='real' and 'FORGE_PRIMARY_PS_PROBE' or nil
      local result=require('editor_process').stop(rpc,dir,primary)
      restore()
      receipt={case=case.kind,real_ps=real_ps,root_code=result.exit_code,root_signal=result.exit_signal,
        scope_ok=result.scope.ok,scope=result.scope}
      T.eq(result.exit_code,0);T.eq(result.exit_signal,0);T.eq(result.api_errors,{})
      T.eq(result.hard_kill,false);T.eq(result.scope.stages,{})
      -- Независимый настоящий probe после восстановления PATH, до assertions
      -- о negative case: failed observer не доказывает пустые own groups.
      local actual=vim.system({real_ps,'-ax','-o','pgid=','-o','stat='},{text=true,timeout=2000}):wait()
      vim.fn.writefile({vim.json.encode(actual)},dir..'/real-ps.json')
      T.eq(actual.code,0);T.eq(actual.signal,0)
      for line in actual.stdout:gmatch('[^\n]+') do
        local group,state=line:match('^%s*(%d+)%s+(%S+)')
        assert(not rpc.scope.groups[tonumber(group)] or state:sub(1,1)=='Z','Own group всё ещё исполняется')
      end
      receipt.real_groups_empty=true
      if case.kind=='real' then
        T.eq(result.ok,true);T.eq(result.scope.active_before,false);T.eq(result.scope.active_after,false)
        T.eq(result.scope.probe_failure,nil)
        assert(vim.fn.filereadable(dir..'/probe-calls.txt')==1,'Delegation через частный executable не произошла')
      else
        receipt.intentional_probe_failure=true
        T.eq(result.ok,false,'Failed probe не является успешным cleanup')
        T.eq(result.scope.ok,false);T.eq(result.scope.active_after,nil)
        local failure=assert(result.scope.probe_failure,'Потерян native probe failure')
        T.eq(failure.argv,{'ps','-ax','-o','pgid=','-o','stat='})
        T.eq(failure.attempt,1);T.eq(result.scope.probe_count,1)
        assert(type(failure.elapsed_ms)=='number' and failure.elapsed_ms>=0)
        assert(result.error:find(primary,1,true),result.error)
        if case.kind=='spawn' then
          assert(failure.spawn_error:find('ENOENT',1,true),failure.spawn_error)
          T.eq(failure.result,nil)
        else
          T.eq(failure.result.code,case.kind=='code' and 17 or 0)
          T.eq(failure.result.signal,case.kind=='code' and 0 or 9)
          T.eq(failure.result.stdout,'FORGE_PS_STDOUT\n')
          T.eq(failure.result.stderr,case.kind=='code' and '' or 'FORGE_PS_STDERR\n')
          T.eq(vim.fn.readfile(dir..'/probe-calls.txt'),{'-ax -o pgid= -o stat='})
        end
      end
      T.eq(require('editor_process').stop(rpc,dir),result,'Cached verdict сохраняет evidence')
    end,debug.traceback)
    restore()
    if rpc and not rpc.exited then pcall(function() rpc.process:kill('sigkill') end);vim.wait(2000,function() return rpc.exited end,10) end
    if rpc and not rpc.shutdown_result then require('editor_process').stop(rpc,dir) end
    receipt=receipt or {case=case.kind};receipt.ok=ok;receipt.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(receipt)},dir..'/probe-test.json')
    io.stdout:write('  artifacts: '..dir..'\n')
    assert(ok,err)
  end)
end
T.finish()
