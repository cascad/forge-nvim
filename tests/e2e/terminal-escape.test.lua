-- spec: IDE-PANEL-16. Настоящий ввод, native PTY и CodeLLDB на паузе.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
local escape=string.char(28)..string.char(14) -- Настоящие байты Ctrl-Backslash, Ctrl-n.
local toggle=string.char(28)
local function keys(e,value)
  local previous=e:lua('return _G.forge_terminal_keys')
  e:input(value..'<F35>')
  e:wait('keyboard sequence consumed before snapshot',function() return e:lua('return _G.forge_terminal_keys')>previous end)
end
local function text(e,buf) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n')]],{buf or 0}) end
local function normal(e) return e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='n' end
local function input_mode(e)
  if e.rpc:request('nvim_get_mode',{}).mode~='t' then e:input('i') end
  e:wait('actual terminal-input mode',function() return e.rpc:request('nvim_get_mode',{}).mode=='t' end)
  keys(e,'');T.eq(e.rpc:request('nvim_get_mode',{}).mode,'t','Private input marker changed terminal mode')
end
local function code(e)
  local ft=e:current_ft()
  if (ft=='text' or ft=='rust') and normal(e) then return end
  e:input('<F7>');e:wait('ordinary code focus',function() return e:current_ft()=='text' or e:current_ft()=='rust' end)
end
local function check(name,rust,fn)
  T.check('IDE-PANEL-16 '..name,function()
    local e,report
    local ok,err=xpcall(function()
      if rust then require('rust_project').start(root,function(child) e=child end)
      else e=require('editor').start(root) end
      report={case=name,states={}}
      e:wait('real config ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      -- Частный no-op подтверждает обработку ввода, не меняя режим, фокус,
      -- callbacks или jobs. Добавленный key учитывает и асинхронный lazy RHS.
      e:lua([[_G.forge_terminal_keys=0
        vim.keymap.set({'n','t'},'<F35>',function()
          _G.forge_terminal_keys=_G.forge_terminal_keys+1
          _G.forge_terminal_marker_mode=vim.api.nvim_get_mode().mode
        end)]])
      if not rust then e:input(':edit file_one.txt<CR>');e:wait('text file',function() return e:current_ft()=='text' end) end
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/terminal-escape.test.lua',e.dir..'/terminal-escape.test.lua'))
      local function capture(label)
        local state=e:lua([[local b=vim.api.nvim_get_current_buf();local channel=vim.bo[b].channel
          local status=vim.fn.jobwait({channel},0)[1];local pid=status==-1 and vim.fn.jobpid(channel) or false;local managed={}
          for _,v in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[v].filetype=='toggleterm' then managed[#managed+1]=v end end
          local d=package.loaded.dap;local s=d and d.session()
          return {mode=vim.api.nvim_get_mode(),buf=b,win=vim.api.nvim_get_current_win(),ft=vim.bo[b].filetype,
            buftype=vim.bo[b].buftype,channel=channel,pid=pid,status=status,
            input_generation=_G.forge_terminal_keys,marker_mode=_G.forge_terminal_marker_mode,
            managed=managed,toggleterm_loaded=package.loaded.toggleterm~=nil,
            session=s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false,
            text=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')} ]])
        state.label=label;report.states[#report.states+1]=state
        assert(vim.fn.writefile({vim.json.encode(report)},e.dir..'/terminal-escape.json')==0)
        return state
      end
      fn(e,capture,report)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      report=report or {case=name};report.ok=ok;report.error=not ok and tostring(err) or nil
      assert(vim.fn.writefile({vim.json.encode(report)},e.dir..'/terminal-escape.json')==0)
      e:snapshot('terminal escape');io.stdout:write('  artifacts: '..e.dir..'\n')
      if not ok then pcall(e.lua,e,[[local d=package.loaded.dap;if d and d.session() then d.terminate() end]]) end
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then err=tostring(err or '')..'\nCleanup: '..tostring(cleanup);ok=false end
      if e.rpc.shutdown_result then
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
      end
    end
    assert(ok,err)
  end)
end
local function preserved(before,after)
  T.eq(after.buf,before.buf,'Native escape changed terminal buffer')
  T.eq(after.win,before.win,'Native escape changed terminal window')
  T.eq(after.channel,before.channel);T.eq(after.pid,before.pid)
  T.eq(after.managed,before.managed,'Native escape created ToggleTerm')
  T.eq(after.session,before.session,'Native escape changed DAP pause')
  assert(after.mode.mode:sub(1,1)=='n' and not after.mode.blocking,'Escape must leave terminal-normal')
  assert(P.history_preserved(before,after),'Native escape lost terminal output')
end
check('closed native command does not open ToggleTerm',false,function(e,capture,report)
  e:lua([[_G.forge_echo_exit=nil;vim.api.nvim_create_autocmd('TermClose',{once=true,
    callback=function(ev) _G.forge_echo_exit={buf=ev.buf,status=vim.v.event.status} end})]])
  e:input(':botright split<CR>:terminal echo FORGE_TERM_CLOSED<CR>')
  e:wait('native command actual TermClose',function() return e:lua('return _G.forge_echo_exit~=nil') end)
  report.echo_exit=e:lua('return _G.forge_echo_exit');T.eq(report.echo_exit.status,0)
  assert(text(e,report.echo_exit.buf):find('FORGE_TERM_CLOSED',1,true))
  e:lua([[local w=vim.fn.bufwinid(...);assert(w>0);vim.api.nvim_set_current_win(w)]],{report.echo_exit.buf})
  if not normal(e) then keys(e,escape) end
  local before=capture('closed-before');T.eq(before.buftype,'terminal');assert(normal(e));T.eq(before.managed,{})
  keys(e,escape)
  preserved(before,capture('closed-after'))
  keys(e,escape);preserved(before,capture('closed-repeat'))
end)
for _,loaded in ipairs({false,true}) do
  check('live native input and repeated escape '..(loaded and 'loaded' or 'cold'),false,function(e,capture,report)
    local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Prepare Python 3 explicitly')
    local dir=e.project..'/Terminal ü with spaces';vim.fn.mkdir(dir,'p')
    local worker=dir..'/echo.py';assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/terminal-echo.py',worker))
    assert(vim.uv.fs_copyfile(worker,e.dir..'/terminal-echo.py'))
    if loaded then e:lua([[require('lazy').load({plugins={'toggleterm.nvim'}})]]) end
    local native=e:lua([[local python,worker=...;vim.cmd('botright new')
      _G.forge_terminal_exit=nil
      _G.forge_terminal_job=vim.fn.jobstart({python,'-B','-u','-S',worker},{term=true,env={PYTHONIOENCODING='utf-8'},
        on_exit=function(_,status) _G.forge_terminal_exit=status end})
      assert(_G.forge_terminal_job>0)
      return {win=vim.api.nvim_get_current_win(),buf=vim.api.nvim_get_current_buf(),pid=vim.fn.jobpid(_G.forge_terminal_job)}]],{python,worker})
    report.worker=native;report.python=python
    e:wait('actual worker PID output',function() return text(e,native.buf):find('FORGE_TERM_READY '..native.pid,1,true)~=nil end)
    input_mode(e);local before=capture('live-before');T.eq(before.toggleterm_loaded,loaded);T.eq(before.status,-1)
    local payload=' q ? w h native ü'
    e:input(payload..'<CR>')
    e:wait('literal PTY input echoed by worker',function() return text(e,native.buf):find('FORGE_TERM_ACK:'..payload,1,true)~=nil end)
    before=capture('input-before-escape')
    keys(e,escape);preserved(before,capture('live-after'))
    keys(e,escape);preserved(before,capture('live-repeat'))
    T.eq(e:lua('return vim.fn.jobwait({_G.forge_terminal_job},0)[1]'),-1)
    code(e);T.eq(e:lua('return vim.fn.jobpid(_G.forge_terminal_job)'),native.pid)
    e:lua('vim.api.nvim_set_current_win(...)',{native.win});input_mode(e)
    keys(e,'<Esc><Esc>');e:wait('Esc Esc still leaves native Normal',function() return normal(e) end)
    preserved(before,capture('double-escape'))
    input_mode(e);e:input('FORGE_TERM_EXIT<CR>')
    e:wait('actual worker normal exit',function() return e:lua('return _G.forge_terminal_exit')==0 end)
    keys(e,escape);e:wait('Normal after worker exit',function() return normal(e) end)
    report.worker_exit=e:lua('return _G.forge_terminal_exit')
  end)
end
local function managed(e,open_key)
  e:input(open_key or string.char(20));e:wait('actual managed shell',function() return e:current_ft()=='toggleterm' end)
  input_mode(e);e:input('echo FORGE_MANAGED_INPUT<CR>')
  e:wait('real shell command output',function()
    return e:lua([[for _,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if line=='FORGE_MANAGED_INPUT' then return true end end;return false]])
  end)
end
check('managed terminal native escape is idempotent',false,function(e,capture)
  managed(e);local before=capture('managed-before');T.eq(before.status,-1)
  keys(e,escape);preserved(before,capture('managed-after'))
  keys(e,escape);preserved(before,capture('managed-repeat'))
end)
check('normal code aliases preserve managed shell job and history',false,function(e,capture)
  T.eq(e:lua('return package.loaded.toggleterm~=nil'),false,'Cold code alias must load the actual plugin')
  managed(e,toggle);keys(e,escape);e:wait('managed Normal',function() return normal(e) end)
  local before=capture('alias-before')
  e:input(string.char(20));e:wait('Ctrl-t hides managed shell',function() return not e:has_window('toggleterm') end)
  code(e);e:input(toggle);e:wait('code Ctrl-Backslash restores shell',function() return e:current_ft()=='toggleterm' end)
  local after=capture('alias-backslash');T.eq(after.buf,before.buf);T.eq(after.pid,before.pid);T.eq(after.status,-1)
  assert(P.history_preserved(before,after))
  code(e);e:input(' tt');e:wait('Space tt hides',function() return not e:has_window('toggleterm') end)
  e:input(' tt');e:wait('Space tt restores',function() return e:current_ft()=='toggleterm' end)
  after=capture('alias-space');T.eq(after.buf,before.buf);T.eq(after.pid,before.pid);T.eq(after.channel,before.channel)
  assert(P.history_preserved(before,after))
end)
check('paused CodeLLDB PTY preserves frame and stdout',true,function(e,capture)
  local file=e.rust_project..'/app/src/main.rs'
  vim.fn.writefile({'fn main() {','    let value = forge_math::calculate_answer(21);',
    '    println!("ESCAPE_BEFORE {value}");','    let observed = value; // ESCAPE_BREAKPOINT',
    '    println!("ESCAPE_AFTER {observed}");','}'},file)
  e:input(':edit '..vim.fn.fnameescape(file)..'<CR>');e:wait('Rust source',function() return e:current_ft()=='rust' end)
  e:input('gg/ESCAPE_BREAKPOINT<CR><F9><F5>')
  e:wait('actual DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('Current Rust file bin')
  e:wait('actual selected config',function() return e:lua([[local s=require('telescope.actions.state').get_selected_entry();return s and s.ordinal:find('Current Rust file bin',1,true)~=nil]]) end)
  e:input('<CR>')
  e:wait('actual breakpoint and PTY',function() return e:lua([[local s=require('dap').session();return s~=nil and s.stopped_thread_id~=nil and s.current_frame~=nil]]) and e:has_window('dap-terminal') end,120000)
  e:wait('stdout before pause',function() local states=P.state(e,'dap-terminal');return #states==1 and states[1].text:find('ESCAPE_BEFORE 42',1,true)~=nil end)
  keys(e,' wc');e:wait('actual DAP terminal focus',function() return e:current_ft()=='dap-terminal' end)
  input_mode(e);local before=capture('dap-before');assert(before.session and before.session.thread);T.eq(before.status,-1)
  keys(e,escape);preserved(before,capture('dap-after'))
  keys(e,escape);preserved(before,capture('dap-repeat'))
  code(e);e:input('<F5>');e:wait('actual Continue ended session',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
  e:wait('stdout after Continue',function() return P.state(e,'dap-terminal')[1].text:find('ESCAPE_AFTER 42',1,true)~=nil end)
  local after=P.state(e,'dap-terminal')[1];T.eq(after.buf,before.buf);T.eq(after.channel,before.channel)
end)
T.finish()
