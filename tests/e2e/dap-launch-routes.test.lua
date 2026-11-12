-- IDE-DAP-1: одинаковая подготовка F5 и project picker, настоящий CodeLLDB.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
T.check('IDE-DAP-1 F5 и project picker сохраняют source buffer и fresh PTY',function()
  local e
  local ok,err=xpcall(function()
    e=require('rust_project').start(root,function(child) e=child end)
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/dap-launch-routes.test.lua',e.dir..'/dap-launch-routes.test.lua'))
    local file=e.rust_project..'/app/src/main.rs'
    vim.fn.writefile({'fn main() {','    let value = 42;',
      '    println!("ROUTE_ARGS {:?}", std::env::args().collect::<Vec<_>>());',
      '    println!("ROUTE_BEFORE {value}");','    let observed = value; // E2E_BREAKPOINT',
      '    println!("ROUTE_AFTER {observed}");','}'},file)
    e:input(':edit '..vim.fn.fnameescape(file)..'<CR>')
    e:wait('Rust file',function() return e:current_ft()=='rust' end,15000)
    e:input('gg/E2E_BREAKPOINT<CR><F9>')
    local history={}
    local function choose(name)
      e:wait('picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
      e:input(name)
      e:wait('выбор '..name,function()
        return e:lua([[local name=...;local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find(name,1,true)~=nil or false]],{name})
      end)
      e:input('<CR>')
    end
    local function run(keys,name,picker,label)
      e:input('<F7>'..keys)
      if picker then choose(name) end
      e:wait('реальная пауза '..name,function()
        return e:lua([[local name=...;local s=require('dap').session();return s and s.config.name==name
          and s.stopped_thread_id~=nil and s.current_frame~=nil or false]],{name})
      end,120000)
      local at_stop=P.state(e,'dap-terminal')[1]
      e:wait('stdout до паузы '..name,function()
        local output=P.state(e,'dap-terminal')[1]
        return output and output.text:find('ROUTE_BEFORE 42',1,true)~=nil
      end)
      local output=P.state(e,'dap-terminal')[1]
      assert(output and output.text:find('ROUTE_BEFORE 42',1,true),'stdout до паузы')
      for _,previous in ipairs(history) do
        assert(output.buf~=previous.buf and output.channel~=previous.channel,'launch переиспользовал старый PTY')
        if previous.label then assert(not output.text:find(previous.label,1,true),'старый stdout попал в свежий запуск') end
      end
      if label then
        assert(output.text:find(label,1,true),'project args не переданы')
        local arg=e:lua([[return require('dap').session().config.args[1] ]]):gsub('\\','/')
        T.eq(arg,file,'${file} прочитан из tool buffer')
      end
      e:input('<F7><F5>')
      e:wait('завершение '..name,function()
        return e:lua([[return require('dap').session()==nil]]) and P.state(e,'dap-terminal')[1].text:find('ROUTE_AFTER 42',1,true)~=nil
      end,30000)
      history[#history+1]={buf=output.buf,channel=output.channel,label=label,name=name,
        stdout_at_stop=at_stop and at_stop.text:find('ROUTE_BEFORE 42',1,true)~=nil or false}
    end
    run('<F5>','Current Rust file bin',true)
    local function config(name,label)
      return {name=name,type='codelldb',request='launch',console='integratedTerminal',
        program=e.rust_target..'/debug/forge_app'..e.rust_suffix,cwd='${workspaceFolder}',
        args={'${file}',label},sourceLanguages={'rust'}}
    end
    local single=config('Route single','PROJECT_SINGLE')
    vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={single}})},e.rust_project..'/.vscode/launch.json')
    run(' dP','Route single',false,'PROJECT_SINGLE')
    local alternate=config('Route alternate','PROJECT_MULTI')
    vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={single,alternate}})},e.rust_project..'/.vscode/launch.json')
    run(' dP','Route alternate',true,'PROJECT_MULTI')
    local before=P.state(e,'dap-terminal')[1]
    e:input('<F7> dP')
    e:wait('picker перед отменой',function() return e:current_ft()=='TelescopePrompt' end)
    e:input('<Esc><Esc>')
    e:wait('picker отменён',function() return e:current_ft()~='TelescopePrompt' end)
    T.eq(e:lua([[return require('dap').session()==nil]]),true)
    T.eq(P.state(e,'dap-terminal')[1].buf,before.buf)
    T.eq(P.state(e,'dap-terminal')[1].channel,before.channel)
    assert(P.history_preserved(before,P.state(e,'dap-terminal')[1]),'отмена очистила историю')
    vim.fn.writefile({vim.json.encode(history)},e.dir..'/launch-routes.json')
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end,debug.traceback)
  if e then
    e:snapshot('dap-launch-routes');io.stdout:write('  artifacts: '..e.dir..'\n')
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
