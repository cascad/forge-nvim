-- IDE-PANEL-21: настоящее CodeLLDB/PTY в двух вкладках.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
T.check('IDE-PANEL-21 hide PTY сохраняет вид другой вкладки и паузу CodeLLDB',function()
  local e
  local ok,err=xpcall(function()
    e=require('rust_project').start(root,function(child) e=child end)
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/dap-tab-scope.test.lua',e.dir..'/dap-tab-scope.test.lua'))
    local file=e.rust_project..'/app/src/main.rs'
    vim.fn.writefile({'fn main() {','    let value = 42;',
      '    println!("VIEW_BEFORE {value}");','    let observed = value; // E2E_BREAKPOINT',
      '    println!("VIEW_AFTER {observed}");','}'},file)
    e:input(':edit '..vim.fn.fnameescape(file)..'<CR>')
    e:wait('Rust file',function() return e:current_ft()=='rust' end,15000)
    e:input('gg/E2E_BREAKPOINT<CR><F9><F5>')
    e:wait('выбор запуска',function() return e:current_ft()=='TelescopePrompt' end)
    e:input('Current Rust file bin')
    e:wait('готовая конфигурация',function()
      return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Current Rust file bin',1,true)~=nil or false]])
    end)
    e:input('<CR>')
    local function session()
      return e:lua([[local s=require('dap').session();return s and s.current_frame and
        {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame.id} or false]])
    end
    e:wait('реальная пауза и stdout',function()
      local output=P.state(e,'dap-terminal')
      return session()~=false and #output==1 and output[1].text:find('VIEW_BEFORE 42',1,true)~=nil
    end,120000)
    local identity=session()
    local original=P.state(e,'dap-terminal')[1]
    local tab=e:lua('return vim.api.nvim_get_current_tabpage()')
    local win=e:lua([[return require('ide.activities').find_window('dap-terminal')]])
    P.code(e);e:input(':tabnew panel-view.txt<CR>')
    e:wait('другая вкладка',function() return e:current_ft()=='text' and e:lua('return vim.api.nvim_get_current_tabpage()')~=tab end)
    e:input(':sbuffer '..original.buf..'<CR>')
    e:wait('два вида одного реального PTY',function() return e:has_window('dap-terminal') end)
    e:lua([[require('ide').hide_slot('bottom')]])
    e:wait('текущий вид скрыт',function()
      return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dap-terminal' then return false end end;return true]])
    end)
    T.eq(e:lua('return vim.api.nvim_win_is_valid(...)',{win}),true,'hide закрыл PTY другой вкладки')
    T.eq(session(),identity,'hide изменил реальную паузу')
    T.eq(P.state(e,'dap-terminal')[1].channel,original.channel)
    T.eq(e:lua('return vim.fn.jobwait({...},0)[1]',{original.channel}),-1,'PTY остановлен')
    e:lua([[require('ide').show('dap.terminal')]])
    e:wait('Show возвращает тот же PTY в текущую вкладку',function()
      return e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dap-terminal' then return true end end;return false]])
    end,1500)
    T.eq(e:lua('return vim.api.nvim_win_is_valid(...)',{win}),true,'Show пересоздал чужой вид')
    T.eq(session(),identity)
    T.eq(P.state(e,'dap-terminal')[1].channel,original.channel)
    e:lua('vim.api.nvim_set_current_tabpage(...)',{tab})
    T.eq(e:has_window('dap-terminal'),true)
    e:input('<F7><F5>')
    e:wait('тот же процесс завершился с выводом',function()
      local output=P.state(e,'dap-terminal')
      return e:lua([[return require('dap').session()==nil]]) and #output==1 and output[1].text:find('VIEW_AFTER 42',1,true)~=nil
    end,30000)
    T.eq(P.state(e,'dap-terminal')[1].buf,original.buf)
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    e:snapshot('dap-tab-scope');io.stdout:write('  artifacts: '..e.dir..'\n')
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
