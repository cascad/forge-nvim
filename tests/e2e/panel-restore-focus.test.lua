-- spec: IDE-PANEL-23. Настоящие панели/IO; удерживается callback native navigate.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local helper=root..'/tests/diagnostics/neo-tree-navigate-delay.lua'
local function keys(e,value)
  local before=e:lua('return _G.restore_focus_keys')
  e:input(value..'<F35>')
  e:wait('input consumed',function() return e:lua('return _G.restore_focus_keys')>before end)
end
local function ready(e)
  return e:lua([[local s=require('neo-tree.sources.manager').get_state('filesystem')
    if not s._ready or not s.tree or s.tree.bufnr~=s.bufnr or not vim.api.nvim_buf_is_valid(s.bufnr) then return false end
    return table.concat(vim.api.nvim_buf_get_lines(s.bufnr,0,-1,false),'\n'):find('file_one.txt',1,true)~=nil]])
end
local function capture(e,report,label)
  local state=e:lua([[local w=vim.api.nvim_get_current_win();local b=vim.api.nvim_get_current_buf()
    return {win=w,buf=b,ft=vim.bo[b].filetype,name=vim.api.nvim_buf_get_name(b)}]])
  state.label=label;report.states[#report.states+1]=state
  return state
end
local cases={
  {name='cold fallback returns code after native render'},
  {name='saved Files and Quickfix return code after native render',saved=true},
  {name='later Logs focus survives native render',saved=true,choice=' wi',expected='forge-logs'},
  {name='explicit Files focus cancels pending return',saved=true,choice=' we',expected='neo-tree'},
  {name='native Files focus after render remains available',saved=true,native=true,expected='neo-tree'},
}
for _,case in ipairs(cases) do
  T.check('IDE-PANEL-23 '..case.name,function()
    local e,report
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=90000})
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/panel-restore-focus.test.lua',e.dir..'/panel-restore-focus.test.lua'))
      assert(vim.uv.fs_copyfile(helper,e.dir..'/neo-tree-navigate-delay.lua'))
      report={case=case.name,states={}}
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:lua([[_G.restore_focus_keys=0;vim.keymap.set('n','<F35>',function()
        vim.schedule(function() _G.restore_focus_keys=_G.restore_focus_keys+1 end) end)]])
      keys(e,':edit file_one.txt<CR> pc')
      e:wait('code without panels',function() return e:current_ft()=='text' and not e:has_window('neo-tree') end)
      local main=capture(e,report,'main')
      if case.saved then
        keys(e,':Neotree filesystem left<CR>')
        e:wait('native Files ready',function() return e:current_ft()=='neo-tree' and ready(e) end)
        e:lua([[vim.fn.setqflist({{filename='file_one.txt',lnum=1,text='restore focus'}})]])
        keys(e,' w0:copen<CR>')
        e:wait('native Quickfix',function() return e:has_window('qf') end)
        e:lua([[require('ide').toggle_panels()]])
        e:wait('all hidden',function() return not e:has_window('neo-tree') and not e:has_window('qf') end)
      end
      e:lua([[_G.restore_focus_io=dofile(...).arm(vim.fn.getcwd())]],{helper})
      e:lua([[require('ide').toggle_panels()]])
      e:wait('actual native navigate held',function() return e:lua('return _G.restore_focus_io.report().held') end)
      report.held=e:lua('return _G.restore_focus_io.report()')
      assert(report.held.callback_source:find('neo-tree/sources/filesystem/init.lua',1,true),'Wrong native producer')
      capture(e,report,'return before native completion')
      if case.choice then
        keys(e,case.choice)
        e:wait('explicit focus selected',function() return e:current_ft()==case.expected end)
        capture(e,report,'explicit choice')
      end
      e:lua('_G.restore_focus_io.release()')
      e:wait('real callback queue drained',function() return e:lua('return _G.restore_focus_io.report().drained') end)
      e:wait('actual new tree rows ready',function() return ready(e) end)
      -- Барьер ставится после ready: ранее запланированный lifecycle уже исполнен.
      e:lua([[_G.restore_focus_barrier=false;vim.schedule(function() _G.restore_focus_barrier=true end)]])
      e:wait('render callback barrier',function() return e:lua('return _G.restore_focus_barrier') end)
      report.released=e:lua('return _G.restore_focus_io.report()')
      assert(report.released.restored and report.released.released)
      capture(e,report,'native completion')
      if case.native then
        keys(e,':Neotree filesystem focus left<CR>')
        e:wait('native focus',function() return e:current_ft()=='neo-tree' end)
        capture(e,report,'native explicit focus')
      end
      T.eq(e:current_ft(),case.expected or 'text','late native render changed focus')
      if not case.expected then
        T.eq(e:lua('return vim.api.nvim_get_current_win()'),main.win)
        T.eq(e:lua('return vim.api.nvim_get_current_buf()'),main.buf)
      end
      T.eq(e:has_window('neo-tree'),true)
      if case.saved then T.eq(e:has_window('qf'),case.expected~='forge-logs') end
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,notice in ipairs(e.rpc.notifications) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
    end,debug.traceback)
    if e then
      pcall(e.lua,e,[[if _G.restore_focus_io then _G.restore_focus_io.release() end]])
      report=report or {case=case.name};report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/panel-restore-focus.json')
      e:snapshot('panel-restore-focus');io.stdout:write('  artifacts: '..e.dir..'\n')
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
end
T.finish()
