-- spec: IDE-PANEL-13. Real CodeLLDB/PTY, keyboard only; no DAP/UI mocks.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
for _,terminal_only in ipairs({false,true}) do
  T.check('IDE-PANEL-13 Debug toggle '..(terminal_only and 'with PTY only' or 'with sidebar and PTY'),function()
    local e,observed
    local ok,err=xpcall(function()
      require('rust_project').start(root,function(child) e=child end)
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/debug-toggle.test.lua',e.dir..'/debug-toggle.test.lua'))
      local file=e.rust_project..'/app/src/main.rs'
      vim.fn.writefile({'fn main() {','    let value = forge_math::calculate_answer(21);',
        '    println!("TOGGLE_BEFORE {value}");','    let observed = value; // TOGGLE_BREAKPOINT',
        '    println!("TOGGLE_AFTER {observed}");','}'},file)
      e:input(':edit '..vim.fn.fnameescape(file)..'<CR>')
      e:wait('Rust source',function() return e:current_ft()=='rust' end)
      e:input('gg/TOGGLE_BREAKPOINT<CR><F9><F5>')
      e:wait('DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
      e:input('Current Rust file bin')
      e:wait('selected config',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Current Rust file bin',1,true)~=nil or false]]) end)
      e:input('<CR>')
      e:wait('real breakpoint',function()
        if e:ack_warning("Debug adapter didn't respond.") then return false end
        return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id and s.current_frame~=nil or false]])
      end,120000)
      e:wait('real PTY stdout',function() local s=P.state(e,'dap-terminal');return #s==1 and s[1].text:find('TOGGLE_BEFORE 42',1,true)~=nil end)
      local function session() return e:lua([[local s=require('dap').session();return s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false]]) end
      local before=P.state(e,'dap-terminal')[1]
      local paused=session()
      if terminal_only then
        e:input(' wd');e:wait('Locals focus',function() return e:current_ft()=='dapui_scopes' end)
        e:input('q');e:wait('sidebar hidden, PTY stays',function() return not e:has_window('dapui_scopes') and e:has_window('dap-terminal') end)
      end
      P.code(e);e:input(' du')
      e:wait('entire Debug group hidden',function()
        for _,ft in ipairs({'dapui_scopes','dapui_watches','dapui_stacks','dapui_breakpoints','dapui_console','dap-repl','dap-terminal'}) do
          if e:has_window(ft) then return false end
        end
        return true
      end)
      T.eq(e:current_ft(),'rust','focus returns to code')
      T.eq(session(),paused,'hide preserves pause')
      T.eq(P.state(e,'dap-terminal')[1].channel,before.channel,'hide preserves native channel')
      e:input(' du');e:wait('same Output restored',function() return e:has_window('dapui_scopes') and e:has_window('dap-terminal') end)
      local after=P.state(e,'dap-terminal')[1]
      T.eq(after.buf,before.buf);T.eq(after.channel,before.channel)
      assert(after.text:find('TOGGLE_BEFORE 42',1,true),'stdout lost on restore')
      T.eq(session(),paused,'restore preserves pause')
      e:input('<F7><F5>');e:wait('same debuggee finished',function() return session()==false end,30000)
      e:wait('same PTY final stdout',function() local s=P.state(e,'dap-terminal');return #s==1 and s[1].text:find('TOGGLE_AFTER 42',1,true)~=nil end)
      local final=P.state(e,'dap-terminal')[1]
      T.eq(final.buf,before.buf);T.eq(final.channel,before.channel)
      observed={terminal_only=terminal_only,before=before,after=after,final=final,paused=paused}
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      if observed then vim.fn.writefile({vim.json.encode(observed)},e.dir..'/debug-toggle.json') end
      e:snapshot('Debug toggle');io.stdout:write('  artifacts: '..e.dir..'\n')
      e:stop(not ok and tostring(err) or nil)
      assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
      T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
    end
    assert(ok,tostring(err))
  end)
end
T.finish()
