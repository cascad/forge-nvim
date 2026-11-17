-- spec: IDE-BOOT-37. Native SDKs, real menu/input, native TUI restart and workflows.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local filter=vim.env.FORGE_TEST_ID
if filter and filter~='' and not T.matches('IDE-BOOT-37',filter) then T.finish();return end
local win=vim.fn.has('win32')==1
local suffix,sep=win and '.exe' or '',win and ';' or ':'
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function write(path,lines) vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile(lines,path)==0) end
local lsp=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
local tests=vim.env.FORGE_E2E_TEST_DEPS or root..'/.tests/test-deps'
local rust=vim.env.FORGE_E2E_RUST_DEPS or root..'/.tests/rust-deps'
local dap=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
local rm=read(rust..'/manifest.json')
local new_rust=vim.fs.normalize(vim.env.FORGE_SDK_RUST_NEW or rm.sysroot)
local host=vim.fs.basename(new_rust):match('^[^-]+%-(.+)$')
local old_rust=vim.fs.normalize(vim.env.FORGE_SDK_RUST_OLD or (win and vim.fs.dirname(new_rust)..'/1.91.1-'..host
  or root..'/.tests/sdk selection/rustup/toolchains/1.91.1-x86_64-unknown-linux-gnu'))
local new_go=vim.fs.normalize(vim.env.FORGE_SDK_GO_NEW or (vim.fn.isdirectory(dap..'/go')==1 and dap..'/go' or '/opt/go'))
local old_go=vim.fs.normalize(vim.env.FORGE_SDK_GO_OLD or (win and vim.fs.dirname(vim.fs.dirname(vim.fn.exepath('go')))
  or root..'/.tests/sdk selection/go-mod/golang.org/toolchain@v0.0.1-go1.23.3.linux-amd64'))
local function version(command,kind)
  local result=vim.system(command,{text=true,timeout=10000,env={GOTOOLCHAIN='local',GOENV='off',RUSTUP_AUTO_INSTALL='0'}}):wait()
  assert(result.code==0,result.stderr);return vim.trim(result.stdout):match(kind=='go' and 'go%d+%.%d+%.%d+' or 'rustc %d+%.%d+%.%d+')
end
local versions={go_old=version({old_go..'/bin/go'..suffix,'version'},'go'),go_new=version({new_go..'/bin/go'..suffix,'version'},'go'),
  rust_old=version({old_rust..'/bin/rustc'..suffix,'--version'},'rust'),rust_new=version({new_rust..'/bin/rustc'..suffix,'--version'},'rust')}
assert(versions.go_old~=versions.go_new and versions.rust_old~=versions.rust_new,'Prepare two actual Go and Rust versions explicitly; see docs/SDK_SELECTION.md')
local function environment()
  return {PATH=table.concat({old_go..'/bin',new_go..'/bin',old_rust..'/bin',lsp..'/bin',tests..'/bin',rust..'/nextest',
      rust..'/codelldb/extension/adapter',dap..'/bin',vim.env.PATH},sep),
    GOTOOLCHAIN='local',GOROOT=old_go,GOENV='off',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',GOMAXPROCS='2',
    GOFLAGS='-p=2',CGO_ENABLED='0',GOCACHE=require('go_cache').path(root),
    RUSTC=old_rust..'/bin/rustc'..suffix,RUSTDOC=old_rust..'/bin/rustdoc'..suffix,CARGO=old_rust..'/bin/cargo'..suffix,
    RUSTUP_HOME=vim.env.RUSTUP_HOME or vim.fs.dirname(vim.fs.dirname(new_rust)),RUSTUP_AUTO_INSTALL='0',
    CARGO_NET_OFFLINE='true',CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2'}
end
local function prepare(project,env,runtime)
  env.FRIDE_SDK_BASE=nil;env.FRIDE_SDK_PROJECT=nil;env.RUSTUP_TOOLCHAIN=nil
  env.GOPATH=runtime..'/go-home';env.GOBIN=runtime..'/go-home/bin'
  env.CARGO_HOME=runtime..'/cargo-home';env.CARGO_TARGET_DIR=runtime..'/rust-target'
  env.RUSTC_WRAPPER=nil;env.RUSTC_WORKSPACE_WRAPPER=nil
  env.RUSTFLAGS=nil;env.CARGO_ENCODED_RUSTFLAGS=nil
  -- An incomplete wrapper-looking installation must never be offered or executed.
  vim.fn.mkdir(runtime..'/home/sdk/go9.99.1/bin','p');vim.fn.mkdir(env.GOBIN,'p')
  write(env.GOBIN..'/go9.99.1'..suffix,{'NOT_AN_INSTALLED_SDK'})
  if not win then assert(vim.uv.fs_chmod(env.GOBIN..'/go9.99.1',493)) end
  -- Manual input contains spaces; normalization may resolve the real SDK root.
  assert(vim.uv.fs_symlink(old_go,runtime..'/Manual SDK path',win and {junction=true,dir=true} or {dir=true}))
end
local function check(name,fn)
  if vim.env.FORGE_SDK_SELECTION_CASE and not name:find(vim.env.FORGE_SDK_SELECTION_CASE,1,true) then return end
  T.check('IDE-BOOT-37 '..name,fn)
end
local function select_rpc(e,label)
  e:wait('SDK picker',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' and e:current_ft()=='TelescopePrompt'
    and e:lua('return vim.api.nvim_get_current_buf()')~=e.sdk_prompt end,20000)
  e:input(label)
  e:wait('SDK choice '..label,function() return e:lua([[local entry=require('telescope.actions.state').get_selected_entry()
    return entry and entry.ordinal:find(...,1,true)~=nil]],{label}) end)
  e.sdk_prompt=e:lua('return vim.api.nvim_get_current_buf()');e:input('<CR>')
end
check('real menu discovery manual save cancel invalid and active task guard',function()
  local e
  local ok,err=xpcall(function()
    e=require('editor').start(root,{env=environment(),prepare=prepare,timeout=180000})
    e:wait('ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    local original=e:lua([[return {pid=vim.uv.os_getpid(),PATH=vim.env.PATH,GOROOT=vim.env.GOROOT,RUSTC=vim.env.RUSTC} ]])
    assert(e:lua([[for _,spawn in ipairs(_G.forge_e2e_spawns) do
      local name=vim.fs.basename(spawn.cmd):lower();assert(name~='rustc' and name~='rustc.exe' and name~='go' and name~='go.exe','SDK probe at startup') end;return true]]))
    e:lua([[local sdk,path,old= require('forge.sdk'),...;local file=vim.fn.stdpath('state')..'/probe-go-env'
      vim.fn.writefile({'GOROOT='..old},file);local saved=vim.env.GOENV;vim.env.GOENV=file
      _G.sdk_probe=nil;sdk.probe('go',path,function(value,err) _G.sdk_probe={value=value,error=err} end)
      vim.env.GOENV=saved ]],{new_go,old_go})
    e:wait('SDK probe ignores unrelated persistent GOROOT',function() return e:lua([[return _G.sdk_probe~=nil]]) end)
    T.eq(vim.fs.normalize(e:lua([[assert(not _G.sdk_probe.error,_G.sdk_probe.error);return _G.sdk_probe.value.path]])),new_go)
    e:input(':ForgeSdk go project<CR>');select_rpc(e,'Указать путь')
    e:wait('manual SDK input',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
    e:input(e.runtime..'/Manual SDK path<CR>');select_rpc(e,'Сохранить для следующего запуска')
    e:wait('saved SDK',function() return vim.fn.filereadable(e.project..'/.fride/sdk.json')==1 end)
    T.eq(read(e.project..'/.fride/sdk.json').sdks.go,old_go)
    T.eq(e:lua([[return {pid=vim.uv.os_getpid(),PATH=vim.env.PATH,GOROOT=vim.env.GOROOT,RUSTC=vim.env.RUSTC} ]]),original)
    local saved=table.concat(vim.fn.readfile(e.project..'/.fride/sdk.json'),'\n')
    e:input(':ForgeSdk go project<CR>')
    e:wait('cancel picker',function() return e:current_ft()=='TelescopePrompt' end,20000);e:input('<Esc><Esc>')
    e:wait('cancel returns to code',function() return e:current_ft()~='TelescopePrompt' end)
    T.eq(table.concat(vim.fn.readfile(e.project..'/.fride/sdk.json'),'\n'),saved)
    e:input(':ForgeSdk go project<CR>');select_rpc(e,'Указать путь')
    e:wait('invalid manual input',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
    e:input(e.runtime..'/missing SDK<CR>')
    e:wait('explicit invalid SDK error',function()
      for _,notice in ipairs(e.rpc.notifications) do if notice.message:find('SDK path does not exist',1,true) then return true end end
    end)
    if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>') end
    e:wait('editor after expected error',function() return not e.rpc:request('nvim_get_mode',{}).blocking end)
    T.eq(table.concat(vim.fn.readfile(e.project..'/.fride/sdk.json'),'\n'),saved)
    local priority=e:lua([[local sdk=require('forge.sdk');sdk.save('rust',...,'user');sdk.save('rust','auto','project')
      return sdk.choice('rust')]],{new_rust});T.eq(priority.value,'auto');assert(priority.source:find('project:',1,true))
    e:lua([[local sdk=require('forge.sdk');local file=sdk.files().user;local old=vim.fn.readfile(file)
      vim.fn.writefile({'{broken'},file);local ok=pcall(sdk.save,'go','auto','user')
      assert(not ok and vim.fn.readfile(file)[1]=='{broken','Corrupt SDK settings overwritten')
      vim.fn.writefile(old,file)
      local project=sdk.files().project;old=vim.fn.readfile(project)
      vim.fn.writefile({vim.json.encode({version=1,sdks={go='./missing sdk'}})},project)
      local valid,why=pcall(sdk.validate);assert(not valid and tostring(why):find('project:',1,true))
      vim.fn.writefile(old,project) ]])
    e:lua([[_G.sdk_task=require('overseer').new_task({cmd={vim.v.progpath,'--headless','-u','NONE','-i','NONE','-c','sleep 30','-c','qa!'},components={'default'}});_G.sdk_task:start()]])
    e:wait('real task running',function() return e:lua([[return _G.sdk_task:is_running()]]) end)
    local busy=e:lua([[local sdk=require('forge.sdk');return {reason=sdk.busy(),applied=sdk.apply(),pid=vim.uv.os_getpid()}]])
    assert(busy.reason and busy.reason~='');T.eq(busy.applied,false);T.eq(busy.pid,original.pid)
    e:lua([[_G.sdk_task:stop()]])
    e:wait('real task stopped',function() return e:lua([[return not _G.sdk_task:is_running()]]) end)
    local spawns=e:lua([[return _G.forge_e2e_spawns]])
    for _,spawn in ipairs(spawns) do assert(not spawn.cmd:find('go9.99.1',1,true),'Incomplete SDK wrapper executed') end
    write(e.dir..'/sdk-discovery-processes.json',{vim.json.encode(spawns)})
  end,debug.traceback)
  if e then e:snapshot('sdk-menu');io.stdout:write('  artifacts: '..e.dir..'\n');local stopped,why=pcall(e.stop,e,not ok and err or nil);if not stopped then ok=false;err=tostring(err)..'\n'..tostring(why) end end
  assert(ok,err)
end)
local function sdk_fixture(project,env,runtime)
  prepare(project,env,runtime)
  local lm=read(lsp..'/manifest.json')
  local dlv=vim.fn.executable(dap..'/bin/dlv'..suffix)==1 and dap..'/bin/dlv'..suffix or vim.fn.exepath('dlv')
  local tools={gopls=lsp..'/'..lm.tools.gopls.path,['rust-analyzer']=new_rust..'/bin/rust-analyzer'..suffix,
    dlv=dlv,codelldb=rust..'/codelldb/extension/adapter/codelldb'..suffix}
  for _,name in ipairs({'Project A ü','Project B ü'}) do
    local path=project..'/'..name
    write(path..'/.fride/tools.json',{vim.json.encode({tools=tools})})
    write(path..'/go.mod',{'module sdk_selection','','go 1.22'})
    write(path..'/main.go',{'package main','import ("fmt";"os";"runtime")','func main(){',
      'version:=runtime.Version()','os.WriteFile("go-run.txt",[]byte(version),0600)','value:=42',
      'observed:=value // SDK_BREAKPOINT','fmt.Println("GO_SDK",version,observed)','}'})
    write(path..'/main_test.go',{'package main','import ("os";"runtime";"testing";"time")',
      'func TestSDK(t *testing.T){os.WriteFile("go-test-start.txt",[]byte("started"),0600);',
      'deadline:=time.Now().Add(20*time.Second);for time.Now().Before(deadline){if _,err:=os.Stat("go-test-release.txt");err==nil{break};time.Sleep(50*time.Millisecond)}',
      'os.WriteFile("go-test.txt",[]byte(runtime.Version()),0600)}'})
    write(path..'/rust/Cargo.toml',{'[package]','name="sdk_selection"','version="0.1.0"','edition="2021"'})
    write(path..'/rust/build.rs',{'fn main(){','let rustc=std::env::var("RUSTC").unwrap();',
      'let out=std::process::Command::new(rustc).arg("--version").output().unwrap();',
      'println!("cargo:rustc-env=SDK_BUILD_RUST={}",String::from_utf8(out.stdout).unwrap().trim());','}'})
    write(path..'/rust/src/main.rs',{'fn main(){','let value=42;','let observed=value; // SDK_BREAKPOINT',
      'std::fs::write("rust-run.txt",env!("SDK_BUILD_RUST")).unwrap();',
      'println!("RUST_SDK {} {}",env!("SDK_BUILD_RUST"),observed);','}',
      '#[cfg(test)]','mod tests {','#[test]','fn actual_sdk(){',
      'std::fs::write("rust-test.txt",env!("SDK_BUILD_RUST")).unwrap();','}','}'})
  end
  local site=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')..'/site/parser'
  vim.fn.mkdir(site,'p');assert(vim.uv.fs_copyfile(rust..'/site/parser/rust.so',site..'/rust.so'))
  local observer=env.FORGE_SESSION_PROBE..'/observer.lua'
  assert(vim.fn.writefile({'dofile('..vim.inspect(root..'/tests/diagnostics/sdk-selection-native.lua')..')'},observer,'a')==0)
end
check('native TUI SDK switches restore session and reach Go Rust workflows',function()
  local tui,report
  local ok,err=xpcall(function()
    tui=require('session_tui').start(root,{env=environment(),site=tests..'/site',prepare=sdk_fixture,timeout=600000,compiler_helpers='msvc-telemetry'})
    local e=tui.host;report={versions=versions,states={},pids={},backends={}}
    local function state(label)
      local s=tui:lua([[return {pid=vim.uv.os_getpid(),go=vim.fn.exepath('go'),GOROOT=vim.env.GOROOT,
        rust=vim.fn.exepath('rustc'),RUSTUP_TOOLCHAIN=vim.env.RUSTUP_TOOLCHAIN,RUSTC=vim.env.RUSTC,
        CARGO=vim.env.CARGO,cwd=vim.fn.getcwd(),file=vim.api.nvim_buf_get_name(0),cursor=vim.api.nvim_win_get_cursor(0)}]])
      report.states[label]=s;return s
    end
    local function connected(previous)
      local ready=tui:connect(previous)
      local last=report.backends[#report.backends]
      assert(ready.pid~=previous and (not last or ready.ms>last.ms),'Backend was not restarted')
      -- Windows may reuse a PID from an earlier, exited backend. Readiness time
      -- and the preceding native lifecycle distinguish those process instances.
      report.backends[#report.backends+1]=ready
      report.pids[tostring(ready.pid)]=true;return ready.pid
    end
    local prompt_token
    local function choose(label)
      e:wait('native SDK picker',function() return tui:mode().mode=='i' and tui:lua([[return vim.bo.filetype=='TelescopePrompt'
        and tostring(vim.uv.os_getpid())..':'..vim.api.nvim_get_current_buf()~=...]],{prompt_token or ''}) end,30000)
      -- Native PTY navigation uses keys, not a UTF-8 paste into Windows console input.
      local found=false
      for _=1,100 do
        local ordinal=tui:lua([[local entry=require('telescope.actions.state').get_selected_entry();return entry and entry.ordinal or '']])
        if ordinal:find(label,1,true) then found=true;break end
        tui:send('\14')
        e:wait('native picker moved',function() return tui:lua([[local entry=require('telescope.actions.state').get_selected_entry();return entry and entry.ordinal~=...]],{ordinal}) end)
      end
      assert(found,'SDK choice not found: '..label)
      prompt_token=tui:lua([[return tostring(vim.uv.os_getpid())..':'..vim.api.nvim_get_current_buf()]]);tui:send('\r')
    end
    local function sdk(kind,label,pid,manual)
      tui:command('ForgeSdk '..kind..' project');choose(label)
      if manual then e:wait('native manual input',function() return tui:mode().mode=='c' end);tui:send(manual..'\r') end
      choose('Сохранить и переоткрыть проект');return connected(pid)
    end
    local function marker(path,expected)
      e:wait('native SDK marker '..path,function() return vim.fn.filereadable(path)==1 and table.concat(vim.fn.readfile(path),'\n'):find(expected,1,true)~=nil end,60000)
    end
    local function open(file,server)
      tui:command('edit '..vim.fn.fnameescape(file))
      e:wait('native file opened',function() return not tui:mode().blocking and tui:lua([[return vim.api.nvim_buf_get_name(0):gsub('\\','/'):sub(-#(...))==...]],{file}) end,10000)
      if server then e:wait('native '..server..' attach',function() return tui:lua([[for _,client in ipairs(vim.lsp.get_clients({bufnr=0,name=...})) do
        if client.initialized then return true end end;return false]],{server}) end,45000) end
    end
    local function run(argv,cwd,marker_path,expected)
      tui:lua([[local argv,cwd=...;_G.sdk_run_task=require('overseer').new_task({cmd=argv,cwd=cwd,components={'default'}});_G.sdk_run_task:start()]],{argv,cwd})
      marker(marker_path,expected)
      e:wait('native run task completed',function() return tui:lua([[return _G.sdk_run_task:is_complete()]]) end,20000)
      T.eq(tui:lua([[return _G.sdk_run_task.status]]),'SUCCESS')
    end
    local function debug(config,expected_version)
      config.name='SDK '..config.type
      tui:lua([[local dap=require('dap');for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
        if line:find('SDK_BREAKPOINT',1,true) then vim.api.nvim_win_set_cursor(0,{i,0});dap.toggle_breakpoint();break end end;dap.run(...)]],{config})
      local errors=tui.base..'/sdk-errors.jsonl'
      e:wait('native SDK breakpoint',function()
        if vim.fn.filereadable(errors)==1 then return true end
        if tui:mode().blocking then return false end
        return tui:lua([[local s=require('dap').session();return s and s.current_frame and s.stopped_thread_id~=nil or false]])
      end,90000)
      assert(vim.fn.filereadable(errors)==0,vim.fn.filereadable(errors)==1 and table.concat(vim.fn.readfile(errors),'\n') or '')
      T.eq(tui:lua([[return require('forge.sdk').busy()]]),'запущена отладка')
      tui:lua([[require('dap').clear_breakpoints();require('dap').continue()]])
      e:wait('native SDK debug exit',function() return tui:lua([[return require('dap').session()==nil]]) end,25000)
      e:wait('native debug SDK output',function() return tui:lua([[local version=...;for _,buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].filetype=='dap-terminal' or vim.bo[buf].filetype=='dap-repl' then
          if table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n'):find(version,1,true) then return true end end end;return false]],{expected_version}) end,10000)
    end
    local initial=tui:launch();local pid=initial.pid
    report.backends[1]=initial;report.pids[tostring(pid)]=true;state('inherited')
    open('first.txt');tui:lua([[vim.api.nvim_win_set_cursor(0,{23,7})]])
    pid=sdk('go',versions.go_new,pid);local go_new_state=state('go-selected')
    T.eq(vim.fs.normalize(go_new_state.GOROOT),new_go);assert(go_new_state.file:match('first.txt$'));T.eq(go_new_state.cursor,{23,7})
    pid=sdk('rust',versions.rust_new,pid);T.eq(vim.fs.normalize(state('rust-selected').RUSTUP_TOOLCHAIN),new_rust)
    open('main.go','gopls');run({'go','run','.'},tui.a,tui.a..'/go-run.txt',versions.go_new)
    open('main_test.go','gopls');tui:send(' Tf')
    marker(tui.a..'/go-test-start.txt','started')
    e:wait('real Go test active',function() return tui:lua([[return require('forge.sdk').busy()=='выполняются тесты']]) end,30000)
    T.eq(tui:lua([[return require('forge.sdk').apply()]]),false)
    write(tui.a..'/go-test-release.txt',{'release'})
    marker(tui.a..'/go-test.txt',versions.go_new)
    e:wait('Go tests finished',function() return tui:lua([[return require('forge.sdk').busy()==nil]]) end,20000)
    open('main.go','gopls');debug({type='go',request='launch',mode='debug',program=tui.a,cwd=tui.a,outputMode='remote'},versions.go_new)
    open('rust/src/main.rs','rust_analyzer');run({'cargo','run','--offline'},tui.a..'/rust',tui.a..'/rust/rust-run.txt',versions.rust_new)
    tui:send(' Tf')
    marker(tui.a..'/rust/rust-test.txt',versions.rust_new)
    e:wait('Rust tests finished',function() return tui:lua([[return require('forge.sdk').busy()==nil]]) end,20000)
    debug({type='codelldb',request='launch',program=e.runtime..'/rust-target/debug/sdk_selection'..suffix,
      cwd=tui.a..'/rust',console='integratedTerminal',sourceLanguages={'rust'}},versions.rust_new)
    report.processes=tui:lua([[return _G.forge_sdk_spawns]])
    local go_lsp,rust_lsp=false,false
    for _,spawn in ipairs(report.processes) do
      if spawn.cmd:find('gopls',1,true) then go_lsp=vim.fs.normalize(spawn.go)==new_go end
      if spawn.cmd:find('rust-analyzer',1,true) then rust_lsp=vim.fs.normalize(spawn.rust)==new_rust end
    end
    assert(go_lsp and rust_lsp,'LSP did not inherit chosen SDK')
    -- Debug output terminals are stopped before the explicit next restart.
    tui:lua([[for _,buf in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[buf].buftype=='terminal' then
      local job=vim.b[buf].terminal_job_id;if job then pcall(vim.fn.jobstop,job) end;pcall(vim.api.nvim_buf_delete,buf,{force=true}) end end]])
    tui:normal();pid=sdk('rust','Указать путь',pid,old_rust);state('older-rust')
    run({'cargo','run','--offline'},tui.a..'/rust',tui.a..'/rust/rust-run.txt',versions.rust_old)
    tui:normal();tui:lua([[require('forge.sdk').save('go',...,'user');require('forge.sdk').save('go','auto','project',select(2,...))]],{new_go,tui.b})
    tui:command('lua require("config.start").open_project('..vim.inspect(tui.b)..')');pid=connected(pid)
    T.eq(vim.fs.normalize(state('other-project-auto').GOROOT),old_go)
    run({'go','run','.'},tui.b,tui.b..'/go-run.txt',versions.go_old)
    tui:normal();tui:command('lua require("config.start").open_project('..vim.inspect(tui.a)..')');pid=connected(pid)
    T.eq(vim.fs.normalize(state('project-returned').GOROOT),new_go)
    pid=sdk('go','Авто',pid);T.eq(vim.fs.normalize(state('auto-go').GOROOT),old_go)
    pid=sdk('rust','Авто',pid);local restored=state('auto-rust')
    T.eq(vim.fs.normalize(restored.RUSTC),old_rust..'/bin/rustc'..suffix);assert(restored.RUSTUP_TOOLCHAIN==nil or restored.RUSTUP_TOOLCHAIN==vim.NIL)
    report.final=tui:state();T.eq(report.final.installs,0)
    T.eq(#report.backends,8,'Expected eight native process instances')
    tui:quit()
    if win then
      local parents={tui.host.rpc.process.pid}
      for pid in pairs(report.pids) do parents[#parents+1]=tonumber(pid) end
      local ids=table.concat(parents,',')
      local command='$ids=@('..ids..'); Get-CimInstance Win32_Process | Where-Object { $ids -contains $_.ProcessId -or $ids -contains $_.ParentProcessId } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Depth 3'
      local processes=vim.system({'powershell.exe','-NoProfile','-NonInteractive','-Command',command},{text=true,timeout=15000}):wait()
      write(tui.host.dir..'/sdk-owned-processes-after-tui.json',vim.split(processes.stdout or '', '\n',{plain=true}))
    end
  end,debug.traceback)
  if tui then
    report=report or {};report.functional_ok=ok;report.error=not ok and tostring(err) or nil
    local observed,last=pcall(tui.state,tui);if observed then report.last_state=last end
    local got,job=pcall(tui.job_state,tui);if got then report.native_screen=job end
    write(tui.host.dir..'/sdk-selection.json',{vim.json.encode(report)})
    tui.host:snapshot('sdk-native-host');io.stdout:write('  artifacts: '..tui.host.dir..'\n')
    local stopped,why=pcall(tui.stop,tui,not ok and err or nil);if not stopped then ok=false;err=tostring(err)..'\n'..tostring(why) end
    report.ok=ok;report.cleanup_ok=stopped;report.error=not ok and tostring(err) or nil
    write(tui.host.dir..'/sdk-selection.json',{vim.json.encode(report)})
    if stopped then
      local shutdown=read(tui.host.dir..'/shutdown.json');assert(shutdown.ok and shutdown.exit_code==0 and shutdown.exit_signal==0 and not shutdown.hard_kill)
      assert(shutdown.scope.ok and (shutdown.scope.active_after==0 or shutdown.scope.active_after==false))
      if shutdown.scope.terminated then assert(win and read(tui.host.dir..'/native-host-exit.json').compiler_helpers,'Unexpected application child survived') end
    end
  end
  assert(ok,err)
end)
T.finish()
