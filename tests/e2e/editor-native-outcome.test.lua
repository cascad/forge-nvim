-- IDE-114: настоящий outcome child не подменяется успешным cleanup.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
if vim.env.FORGE_E2E_DRIVER_SOURCE then package.path=vim.env.FORGE_E2E_DRIVER_SOURCE..'/?.lua;'..package.path end
local T=require('check')
local E=require('editor')
local driver=debug.getinfo(E.start,'S').source:sub(2)
local cases={
  {name='cquit23 сообщает native exit',code=23},
  {name='SIGKILL собственного child сообщает native signal',signal=9},
  {name='primary error сохраняется рядом с native exit',code=23,primary='FORGE_PRIMARY_BEFORE_EXIT'},
  {name='обычный quit остаётся успешным'},
}
for _,case in ipairs(cases) do
  T.check('SELF: NATIVE-OUTCOME '..case.name,function()
    local e,receipt
    local ok,err=xpcall(function()
      e=E.start(root)
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      assert(vim.uv.fs_copyfile(driver,e.dir..'/editor-source.lua'))
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/editor-native-outcome.test.lua',e.dir..'/editor-native-outcome.test.lua'))
      receipt={case=case.name,runtime=e.runtime,expected_code=case.code,expected_signal=case.signal,
        primary=case.primary,driver=driver}
      if case.code or case.signal then
        if case.code then e:input(':cquit '..case.code..'<CR>') else e.rpc.process:kill(case.signal) end
        assert(vim.wait(5000,function() return e.rpc.exited end,10),'native exit не получен')
      end
      local stopped,issue=pcall(e.stop,e,case.primary)
      receipt.stop_ok=stopped;receipt.error=not stopped and tostring(issue) or nil
      receipt.code=e.rpc.exit_code;receipt.signal=e.rpc.exit_signal
      local cleanup=e.rpc.shutdown_result
      T.eq(cleanup.ok,true,'cleanup должен быть успешен независимо от native outcome')
      T.eq(cleanup.api_errors,{});T.eq(cleanup.hard_kill,false)
      assert(cleanup.scope and cleanup.scope.ok and
        (cleanup.scope.active_after==false or cleanup.scope.active_after==0),'own scope не пуст')
      T.eq(e.stopped,true);T.eq(vim.fn.isdirectory(e.runtime),0)
      T.eq(vim.fn.filereadable(e.dir..'/config-source/init.lua'),1)
      if case.code then T.eq(cleanup.exit_code,case.code);T.eq(cleanup.exit_signal,0)
      elseif case.signal then T.eq(cleanup.exit_signal,case.signal)
      else T.eq(cleanup.exit_code,0);T.eq(cleanup.exit_signal,0) end
      if case.code or case.signal then
        receipt.intentional_native_failure=true
        assert(not stopped,'nonzero native outcome скрыт успешным cleanup')
        assert(tostring(issue):find('Native exit:',1,true),tostring(issue))
        assert(tostring(issue):find('code='..cleanup.exit_code,1,true),tostring(issue))
        assert(tostring(issue):find('signal='..cleanup.exit_signal,1,true),tostring(issue))
        if case.primary then
          assert(tostring(issue):find(case.primary,1,true),tostring(issue))
          T.eq(cleanup.primary_error,case.primary)
        end
      else assert(stopped,issue) end
      e:stop() -- удалённый runtime/уже полученный outcome не останавливается повторно
    end,debug.traceback)
    if e then
      if not e.stopped then pcall(e.stop,e,not ok and tostring(err) or nil) end
      receipt=receipt or {case=case.name};receipt.ok=ok
      receipt.test_error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(receipt)},e.dir..'/native-outcome.json')
      io.stdout:write('  artifacts: '..e.dir..'\n')
    end
    assert(ok,err)
  end)
end

T.check('SELF: NATIVE-OUTCOME generic cleanup допускает ожидаемый cquit24',function()
  local dir=root..'/.tests/editor-native-outcome/'..tostring(vim.uv.hrtime())
  vim.fn.mkdir(dir,'p')
  local rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE'},
    {cwd=root,timeout=30000,artifacts=dir,env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/nvim.log'})})
  local ok,err=xpcall(function()
    T.eq(rpc:request('nvim_eval',{'1+1'}),2)
    rpc.process:write(vim.mpack.encode({2,'nvim_command',{'cquit 24'}}))
    assert(vim.wait(5000,function() return rpc.exited end,10),'clean native cquit не завершён')
    local result=require('editor_process').stop(rpc,dir)
    T.eq(result.ok,true);T.eq(result.exit_code,24);T.eq(result.exit_signal,0)
    T.eq(result.api_errors,{});T.eq(result.hard_kill,false)
    T.eq(require('editor_process').stop(rpc,dir),result)
    vim.fn.writefile({vim.json.encode({intentional_native_failure=true,code=24,signal=0,ok=true})},dir..'/native-outcome.json')
  end,debug.traceback)
  if not rpc.exited then pcall(function() rpc.process:kill('sigkill') end);vim.wait(2000,function() return rpc.exited end,10) end
  local cleanup=require('editor_process').stop(rpc,dir)
  assert(cleanup.ok,cleanup.error)
  io.stdout:write('  artifacts: '..dir..'\n')
  assert(ok,err)
end)
T.finish()
