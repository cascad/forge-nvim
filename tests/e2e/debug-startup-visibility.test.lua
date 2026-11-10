-- spec: IDE-PANEL-14. Actual running CodeLLDB, public DAP events and UI keys.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
T.check('IDE-PANEL-14 startup recovery respects hide and a new breakpoint restores Debug',function()
  local e,observed
  local ok,err=xpcall(function()
    require('rust_project').start(root,function(child) e=child end)
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/debug-startup-visibility.test.lua',e.dir..'/debug-startup-visibility.test.lua'))
    local file=e.rust_project..'/app/src/main.rs'
    vim.fn.writefile({'fn main() {',' let value=42;',' println!("STARTUP_BEFORE {value}");',
      ' std::thread::sleep(std::time::Duration::from_secs(4));',' let observed=value; // STARTUP_BREAK',
      ' println!("STARTUP_AFTER {observed}");','}'},file)
    e:input(':edit '..vim.fn.fnameescape(file)..'<CR>');e:wait('Rust source',function() return e:current_ft()=='rust' end)
    e:input('gg/STARTUP_BREAK<CR><F9>')
    e:wait('DAP loaded by breakpoint key',function() return e:lua([[return type(package.loaded.dap)=='table']]) end)
    e:lua([[local d=require('dap');_G.startup_probe={stopped=0}
      d.listeners.after.event_initialized.startup_probe=function() _G.startup_probe.initialized=vim.uv.hrtime() end
      d.listeners.after.event_stopped.startup_probe=function() _G.startup_probe.stopped=_G.startup_probe.stopped+1 end]])
    e:input('<F5>');e:wait('DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    e:input('Current Rust file bin')
    e:wait('selected config',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Current Rust file bin',1,true)~=nil or false]]) end)
    e:input('<CR>')
    e:wait('real PTY before first breakpoint',function() local p=P.state(e,'dap-terminal');return e:has_window('dap-terminal') and #p==1 and p[1].channel>0 end,30000)
    local before=P.state(e,'dap-terminal')[1]
    P.code(e);e:input(' wc');e:wait('Output focus',function() return e:current_ft()=='dap-terminal' end)
    e:input('q');e:wait('Output hidden',function() return not e:has_window('dap-terminal') end)
    if e:has_window('dapui_scopes') then e:input(' du') end
    local function hidden() return not e:has_window('dapui_scopes') and not e:has_window('dap-terminal') end
    e:wait('Debug hidden',hidden)
    local timing=e:lua([[local p=_G.startup_probe;return {initialized=p.initialized,hidden=vim.uv.hrtime(),stopped=p.stopped}]])
    observed={timing=timing,before=before}
    assert(timing.initialized and timing.hidden-timing.initialized<700000000,'Fixture missed pending startup recovery window')
    T.eq(timing.stopped,0,'no breakpoint caused a legitimate reopen')
    e:wait('past startup recovery deadline',function() return e:lua([[return vim.uv.hrtime()-_G.startup_probe.initialized>1200000000]]) end)
    observed.hidden_after_deadline=hidden()
    assert(observed.hidden_after_deadline,'Debug reopened before a new stopped event')
    e:wait('real later breakpoint restores Debug',function() return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame and _G.startup_probe.stopped==1 or false]])
      and e:has_window('dapui_scopes') and e:has_window('dap-terminal') end,15000)
    local after=P.state(e,'dap-terminal')[1];observed.after=after
    e:wait('real Locals refreshed after restored breakpoint',function()
      return e:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype=='dapui_scopes' then
          for _,line in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do
            if line:match('^%s*value%s') and line:find('42',1,true) then return true end
          end
        end
      end;return false]])
    end)
    T.eq(after.buf,before.buf);T.eq(after.channel,before.channel)
    assert(after.text:find('STARTUP_BEFORE 42',1,true),'stdout before pause lost')
    e:input('<F7><F5>');e:wait('program finished',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
    e:wait('same PTY final stdout',function() local p=P.state(e,'dap-terminal');return #p==1 and p[1].text:find('STARTUP_AFTER 42',1,true)~=nil end)
    observed.final=P.state(e,'dap-terminal')[1]
    T.eq(observed.final.buf,before.buf);T.eq(observed.final.channel,before.channel)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    local inspected,state=pcall(e.lua,e,[[local s=require('dap').session();return {probe=_G.startup_probe,
      session=s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false,
      breakpoints=require('dap.breakpoints').get()}]])
    if inspected then observed=observed or {};observed.state=state;observed.output=P.state(e,'dap-terminal') end
    if observed then vim.fn.writefile({vim.json.encode(observed)},e.dir..'/startup-visibility.json') end
    e:snapshot('startup visibility');io.stdout:write('  artifacts: '..e.dir..'\n')
    if not ok then
      pcall(e.lua,e,[[local d=require('dap');if d.session() then d.terminate() end]])
      pcall(function() e:wait('private fixture terminated',function() return e:lua([[return require('dap').session()==nil]]) end,10000) end)
    end
    e:stop(not ok and tostring(err) or nil)
    assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
    T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
  end
  assert(ok,tostring(err))
end)
T.finish()
