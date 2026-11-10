-- Сам capture проверяется на настоящем Nvim. Controlled delay не объясняет IDE-085.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function rows(path)
  local result={};for _,line in ipairs(vim.fn.readfile(path)) do result[#result+1]=vim.json.decode(line) end
  return result
end
local function find(items,kind)
  for _,item in ipairs(items) do if item.kind==kind then return item end end
end
local function check(name,delayed,api_error)
  T.check('SELF: QUIT-TRACE '..name,function()
    local dir=root..'/.tests/quit-trace-e2e/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
    local rpc
    local ok,err=xpcall(function()
      rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE'},
        {cwd=root,timeout=30000,artifacts=dir,trace_detail=api_error,
          env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/nvim.log'})})
      T.eq(rpc:request('nvim_eval',{'1+1'}),2)
      if api_error then
        for i=1,140 do T.eq(rpc:request('nvim_eval',{tostring(i)}),i) end
        rpc.process:write(vim.mpack.encode({2,'nvim_command',{'ForgeMissingQuitTraceCommand'}}))
        T.eq(rpc:request('nvim_eval',{'1+1'}),2)
        assert(vim.wait(1000,function() return #rpc.api_errors>0 end,10),'нет native nvim_error_event')
      end
      if delayed then
        rpc:request('nvim_exec_lua',{[[vim.api.nvim_create_autocmd('QuitPre',{once=true,callback=function() vim.wait(5000) end})]],{}})
      end
      local result=require('editor_process').stop(rpc,dir,delayed and 'controlled QuitPre delay' or nil)
      assert(result.ok and result.exited and not result.hard_kill)
      T.eq(result.trace.error,nil)
      local controller=rows(dir..'/quit-controller.jsonl');local native=rows(dir..'/quit-native.jsonl')
      assert(find(native,'observer_ready'))
      local received=assert(find(native,'QuitPre'),'нет native QuitPre')
      assert(find(controller,'quit') and find(controller,'quit_write_returned').fields.ok)
      T.eq(type(find(controller,'quit').fields.handle_closing),'boolean')
      assert(find(controller,'process_complete'))
      if api_error then
        T.eq(#result.api_errors,1)
        assert(result.api_errors[1].message:find('ForgeMissingQuitTraceCommand',1,true))
        assert(find(controller,'nvim_error_event'))
        assert(result.trace.detail and result.trace.dropped>0,'detail cap не проверен')
      else
        T.eq(#result.api_errors,0)
      end
      if delayed then
        local signal=assert(find(controller,'sigterm'),'delay не потребовал штатного SIGTERM')
        assert(received.ms<signal.ms,'QuitPre не предшествует сигналу')
        T.eq(result.primary_error,'controlled QuitPre delay')
      else
        T.eq(result.exit_code,0);T.eq(result.exit_signal,0)
        assert(find(native,'VimLeavePre') and find(native,'VimLeave'))
        assert(not find(controller,'sigterm') and not find(controller,'sigkill'))
      end
      local active=result.scope.active_after
      assert(result.scope.ok and (active==0 or active==false))
      vim.fn.writefile({vim.json.encode({ok=true,delayed=delayed,shutdown=result})},dir..'/test.json')
    end,debug.traceback)
    if rpc and not rpc.shutdown_result then require('editor_process').stop(rpc,dir,not ok and err or nil) end
    io.stdout:write('  artifacts: '..dir..'\n');assert(ok,err)
  end)
end
check('normal qa: native receipt и exit без сигнала',false)
check('реальный QuitPre delay отделён от недоставленного quit',true)
check('ошибка API notification сохраняется отдельно от успешного exit',false,true)
T.finish()
