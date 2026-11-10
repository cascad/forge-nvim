-- spec: IDE-PANEL-11. Native DAP, без подмены session/output/PTY.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
local function check(name,fn)
  if vim.env.FORGE_OUTPUT_CASE and not name:find(vim.env.FORGE_OUTPUT_CASE,1,true) then return end
  T.check('IDE-PANEL-11 '..name,function()
    local e
    local ok,err=pcall(function() fn(function(child) e=child end)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      assert(e:lua('return vim.g.forge_e2e_installs')==0)
    end)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      e:stop(not ok and tostring(err) or nil)
      assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result));T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0)
      T.eq(e.rpc.api_errors,{})
    end
    assert(ok,err)
  end)
end
local function ready(e,file,ft)
  e:input(':edit '..vim.fn.fnameescape(file)..'<CR>')
  e:wait('Открыт '..ft,function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>');return false end
    return e:current_ft()==ft
  end,15000)
end
local function paused(e)
  e:wait('Настоящий breakpoint',function()
    if e:ack_warning("Debug adapter didn't respond.") then return false end
    return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil or false]])
  end,120000)
end
local function choose(e,name)
  e:wait('DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(name)
  e:wait('Выбрана конфигурация',function() return e:lua([[local n=...;local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find(n,1,true)~=nil or false]],{name}) end)
  e:input('<CR>')
end
check('cold manual view и explicit channels',function(set)
  local e=require('editor').start(root);set(e)
  vim.fn.writefile({'local value = 42'},e.project..'/main.lua')
  ready(e,e.project..'/main.lua','lua')
  e:input(' md');e:wait('Холодный Debug View = REPL',function() return e:has_window('dap-repl') end)
  assert(e:lua([[return require('dap').session()==nil]]))
  P.code(e);e:input(' mo');e:wait('Явная Console',function() return e:current_ft()=='dapui_console' end)
  P.reopen(e,'dapui_console',' du')
  P.code(e);e:input(' dR');e:wait('Явный REPL',function() return e:current_ft()=='dap-repl' end)
  P.reopen(e,'dap-repl',' Dc')
  P.code(e);e:input(' Dv');e:wait('Dv остаётся Variables',function() return e:current_ft()=='dapui_scopes' end)
end)
check('Go remote after exit и legacy Output поверх Tasks',function(set)
  local sep=vim.fn.has('win32')==1 and ';' or ':'
  local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
  local e=require('editor').start(root,{timeout=240000,env={PATH=tools..'/bin'..sep..tools..'/go/bin'..sep..vim.env.PATH,
    GOTOOLCHAIN='local',GOENV='off',GOPROXY='off',GOCACHE=require('go_cache').path(root)}});set(e)
  for _,name in ipairs({'main.go','go.mod'}) do assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/debug-panels/'..name,e.project..'/'..name)) end
  vim.fn.mkdir(e.project..'/.vscode','p')
  vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={{name='Output Go',type='go',request='launch',mode='debug',program=e.project,cwd=e.project,
    outputMode='remote',console='integratedTerminal'}}})},e.project..'/.vscode/launch.json')
  ready(e,'main.go','go');e:input('gg/E2E_BREAKPOINT<CR><F9><F5>');choose(e,'Output Go');paused(e)
  e:wait('Go stdout',function() local s=P.state(e,'dap-repl');return #s==1 and s[1].text:find('PANEL_BEFORE',1,true)~=nil end)
  P.reopen(e,'dap-repl',' md')
  e:input('<F7><F5>');e:wait('Go завершён',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
  e:wait('Go итоговый stdout',function() return P.state(e,'dap-repl')[1].text:find('PANEL_AFTER',1,true)~=nil end)
  P.reopen(e,'dap-repl',' md')
  P.code(e);e:input(' wb');e:wait('Tasks вместо Output',function() return e:current_ft()=='OverseerList' end)
  e:input(' Dc');e:wait('Legacy Output возвращает REPL',function() return e:current_ft()=='dap-repl' end)
end)
check('Rust PTY hide continue exit и fresh launch',function(set)
  local e=require('rust_project').start(root,set)
  local file=e.rust_project..'/app/src/main.rs'
  -- Вывод до паузы и после неё в настоящем fixture-проекте.
  vim.fn.writefile({'fn main() {','    let value = forge_math::calculate_answer(21);',
    '    println!("POLICY_BEFORE {value}");','    eprintln!("POLICY_STDERR");',
    '    let observed = value; // E2E_BREAKPOINT','    println!("POLICY_AFTER {observed}");','}'},file)
  ready(e,file,'rust');e:input('gg/E2E_BREAKPOINT<CR><F9><F5>');choose(e,'Current Rust file bin');paused(e)
  e:wait('PTY stdout до паузы',function() local s=P.state(e,'dap-terminal');return #s==1 and s[1].text:find('POLICY_BEFORE 42',1,true)~=nil and s[1].text:find('POLICY_STDERR',1,true)~=nil end)
  local original=P.state(e,'dap-terminal')[1]
  P.reopen(e,'dap-terminal',' md')
  P.reopen(e,'dap-terminal',' du')
  -- Явный REPL запоминается даже при активном CodeLLDB.
  P.code(e);e:input(' dR');e:wait('Rust interactive REPL',function() return e:current_ft()=='dap-repl' end)
  P.reopen(e,'dap-repl',' md')
  e:input('<F7><F5>');e:wait('Rust завершён',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
  e:wait('Continue оставляет PTY доступным',function() return e:has_window('dap-terminal') and P.state(e,'dap-terminal')[1].text:find('POLICY_AFTER 42',1,true)~=nil end)
  P.reopen(e,'dap-terminal',' md')
  local after=P.state(e,'dap-terminal')[1];T.eq(after.buf,original.buf);T.eq(after.channel,original.channel)
  e:input('<F7><F5>');choose(e,'Current Rust file bin');paused(e)
  e:wait('Следующий запуск создал новый PTY',function() local s=P.state(e,'dap-terminal');return #s==1 and s[1].buf~=original.buf and s[1].channel~=original.channel and s[1].text:find('POLICY_BEFORE 42',1,true)~=nil end)
  assert(not P.state(e,'dap-terminal')[1].text:find('POLICY_AFTER',1,true),'Старый stdout попал в свежий PTY')
  e:input('<F7><F5>');e:wait('Второй Rust завершён',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
end)
T.finish()
