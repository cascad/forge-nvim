-- IDE-DAP-6: настоящий debugpy, ошибка его CLI до DAP initialize.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-DAP-6 ошибка настоящего debugpy видна в UI и stderr',function()
  local e
  local ok,err=xpcall(function()
    e=require('python_project').start(root,function(child) e=child end)
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/debugpy-exit.test.lua',e.dir..'/debugpy-exit.test.lua'))
    e:input(':edit '..vim.fn.fnameescape(e.python_project..'/app.py')..'<CR>')
    e:wait('Python source',function() return e:current_ft()=='python' end,15000)
    -- Публичная adapter configuration; запускается реальный installed debugpy.
    e:lua([[local python=...;local dap=require('dap');dap.adapters.debugpy={type='executable',command=python,
      args={'-m','debugpy.adapter','--forge-invalid-option'},options={detached=false}}]],{e.tools_python})
    local cfg={name='Broken debugpy startup',type='debugpy',request='launch',program='${file}'}
    vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={cfg}})},e.python_project..'/.vscode/launch.json')
    e:input('<F5>')
    e:wait('picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    e:input('Broken debugpy startup')
    e:wait('project config',function()
      return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Broken debugpy startup',1,true)~=nil or false]])
    end)
    e:input('<CR>')
    local stderr=e.log_cache..'/dap-debugpy-stderr.log'
    e:wait('реальная CLI ошибка debugpy',function()
      return vim.fn.filereadable(stderr)==1 and table.concat(vim.fn.readfile(stderr),'\n'):find('--forge-invalid-option',1,true)~=nil
    end,15000)
    assert(vim.uv.fs_copyfile(stderr,e.dir..'/debugpy-stderr.log'))
    e:wait('adapter завершён',function()
      if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('of adapter `debugpy` exited with 2') end
      return e:lua([[return require('dap').session()==nil]])
    end)
    e:wait('предупреждение настоящего debugpy',function()
      if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('of adapter `debugpy` exited with 2') end
      for _,n in ipairs(e.rpc.notifications) do
        if n.level==vim.log.levels.WARN and n.message:find('of adapter `debugpy` exited with 2',1,true) then return true end
      end
      return false
    end,2000)
    e:input(' wi')
    e:wait('ошибка в общей консоли IDE',function()
      return e:current_ft()=='forge-logs' and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('of adapter `debugpy` exited with 2',1,true)~=nil]])
    end)
    e:input(' w0')
    e:wait('возврат в Python source',function() return e:current_ft()=='python' and e:current_file()==e.python_project..'/app.py' end)
    e:input('gg0i# EDITABLE_AFTER_DEBUGPY_FAILURE<CR><Esc>:write<CR>')
    e:wait('редактирование после ошибки',function()
      return vim.fn.readfile(e.python_project..'/app.py')[1]=='# EDITABLE_AFTER_DEBUGPY_FAILURE'
    end)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    local captured,focus=pcall(e.lua,e,[[return {win=vim.api.nvim_get_current_win(),ft=vim.bo.filetype,mode=vim.api.nvim_get_mode(),
      logs=package.loaded['forge.logs'] and require('forge.logs').visible() or false}]])
    if captured then vim.fn.writefile({vim.json.encode(focus)},e.dir..'/focus.json') end
    local daplog=e.log_cache..'/dap.log'
    if vim.fn.filereadable(daplog)==1 then assert(vim.uv.fs_copyfile(daplog,e.dir..'/dap.log')) end
    e:snapshot('debugpy-exit');io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
    local exited,issue=pcall(function()
      T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
      assert(e.rpc.shutdown_result and e.rpc.shutdown_result.ok)
    end)
    if not exited then ok=false;err=tostring(err or '')..'\nNative exit: '..tostring(issue) end
  end
  assert(ok,err)
end)
T.finish()
