-- Control checks observer reliability; it does not reproduce IDE-097.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local title='SELF: NATIVE-ASSERT '
if vim.fn.has('win32')~=1 then T.skip(title..'capture','Windows CRT/Job diagnostic');T.finish() end
if vim.fn.filereadable(root..'/.tests/rust-deps/codelldb/extension/lldb/bin/lldb.exe')~=1 then
  T.skip(title..'capture','Prepare CodeLLDB with tests/e2e/prepare_rust.py --download');T.finish()
end
for _,case in ipairs({'detach','deadline','foreign-job','assertion'}) do
  T.check(title..case,function()
    local dir=root..'/.tests/native-assert/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
    local profile,rpc,foreign,capture
    local function start(suffix)
      return require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE'},
        {cwd=root,timeout=60000,artifacts=dir,env=vim.tbl_extend('force',vim.fn.environ(),
          {HOME=profile.path..'/home',USERPROFILE=profile.path..'/home',TEMP=profile.path..'/tmp',TMP=profile.path..'/tmp',
            TMPDIR=profile.path..'/tmp',NVIM_LOG_FILE=dir..'/'..suffix..'.log'})})
    end
    local ok,err=xpcall(function()
      profile=require('editor_runtime').create(root)
      vim.fn.mkdir(dir..'/foreign','p')
      vim.fn.mkdir(profile.path..'/home','p');vim.fn.mkdir(profile.path..'/tmp','p')
      rpc=start('host');T.eq(rpc:request('nvim_eval',{'2+2'}),4)
      if case=='foreign-job' then foreign=start('foreign') end
      if foreign then
        local copied,why=pcall(rpc.scope.duplicate_query_handle,rpc.scope,foreign.process.pid)
        T.eq(copied,false);assert(tostring(why):find('outside the fixture Job',1,true),why)
      end
      local target_pid=foreign and foreign.process.pid or rpc.process.pid
      if case=='assertion' then
        assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/native-assert-control.lua',dir..'/control.lua'))
        target_pid=rpc:request('nvim_exec_lua',{[[local dir=...
          _G.forge_assertion_job=vim.fn.jobstart({vim.v.progpath,'--headless','-u','NONE','-i','NONE','-l',dir..'/control.lua',dir..'/release'})
          assert(_G.forge_assertion_job>0);return vim.fn.jobpid(_G.forge_assertion_job)]],{dir}})
      end
      capture=require('native_assert').start(root,rpc,profile.path,dir..'/capture',target_pid,case=='deadline' and 1 or 20)
      if foreign then
        local result=capture:wait('done.json')
        T.eq(result.attached,false);T.eq(result.outcome,'error')
        assert(result.error:find('outside the fixture Job',1,true),result.error)
        T.eq(foreign:request('nvim_eval',{'2+2'}),4)
      else
        local ready=capture:ready();T.eq(ready.attached,true)
        assert(ready.breakpoint_locations>0 and ready.version:find('codelldb',1,true))
        if case=='assertion' then
          capture:phase({control=true,label='FORGE_CONTROL_ONLY'})
          assert(vim.fn.writefile({'release'},dir..'/release')==0)
          local result=capture:wait('done.json')
          T.eq(result.outcome,'assertion-captured');T.eq(result.diagnostic_termination,true)
          local stack=capture:wait('capture.json');T.eq(stack.assertion,true);T.eq(stack.phase.control,true)
          T.eq(stack.assertion_args,{expression='FORGE_CONTROL_ONLY',file='forge_capture_control',line=97})
          local found=false;for _,thread in ipairs(stack.threads) do for _,frame in ipairs(thread.frames) do
            if (frame['function'] or ''):find('_wassert',1,true) then found=true end
          end end;assert(found,'No actual CRT assertion frame')
          T.eq(rpc:request('nvim_eval',{'2+2'}),4,'Fixture host survives captured child assertion')
        else
          local done=case=='deadline' and capture:wait('done.json',4000) or capture:stop()
          T.eq(done.detached,true);T.eq(done.outcome,case=='deadline' and 'deadline' or 'stop-request')
          T.eq(rpc:request('nvim_eval',{'2+2'}),4,'Detached fixture remains responsive')
        end
      end
      T.eq(capture:wait('debugger-exit.json',5000).code,0)
      for _,child in ipairs({foreign or false,rpc}) do if child then
        child.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}}))
        assert(vim.wait(5000,function() return child.exited end,10),'Fixture native quit timed out')
        assert(vim.wait(3000,function() return child.scope:active_count()==0 end,10),'Fixture Job did not drain')
        T.eq(child.exit_code,0);T.eq(child.exit_signal,0)
      end end
    end,debug.traceback)
    if capture then pcall(capture.stop,capture) end
    for _,child in ipairs({foreign or false,rpc or false}) do if child then
      if child.exited then vim.wait(3000,function() return child.scope:active_count()==0 end,10) end
      local closed,cleanup=pcall(require('editor_process').stop,child,dir..(child==foreign and '/foreign' or ''),not ok and err or nil)
      if not closed or not cleanup.ok then ok=false;err=tostring(err or '')..'\nCleanup: '..vim.inspect(cleanup) end
    end end
    if profile then require('editor_runtime').remove(profile) end
    assert(vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and err or nil,case=case})},dir..'/test.json')==0)
    io.stdout:write('  artifacts: '..dir..'\n');assert(ok,err)
  end)
end
T.finish()
