-- spec: IDE-BOOT-36. Real tools/editor/Go workspace, no SDK downloads.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local filter=vim.env.FORGE_TEST_ID
if filter and filter~='' and not (T.matches('IDE-BOOT-36',filter) or T.matches(filter,'IDE-BOOT-36')) then T.finish();return end
local win=vim.fn.has('win32')==1
local suffix,sep=win and '.exe' or '',win and ';' or ':'
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function json(path,data)
  vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile({vim.json.encode(data)},path)==0)
end
local lsp=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
local test=vim.env.FORGE_E2E_TEST_DEPS or root..'/.tests/test-deps'
local rust=vim.env.FORGE_E2E_RUST_DEPS or root..'/.tests/rust-deps'
local sdk=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
local lm,rm=read(lsp..'/manifest.json'),read(rust..'/manifest.json')
local sysroot=vim.fs.normalize(rm.sysroot)
local go_bin=vim.fn.executable(sdk..'/go/bin/go'..suffix)==1 and sdk..'/go/bin' or vim.fs.dirname(vim.fn.exepath('go'))
local machine=vim.uv.os_uname().machine:lower()
local arch=(machine=='arm64' or machine=='aarch64') and 'arm64' or 'x64'
local platform=(win and 'windows' or vim.fn.has('macunix')==1 and 'macos' or 'linux')..'-'..arch
local mason=root..'/.tests/ide-tools/'..platform..'/data/'..(win and 'fride-data' or 'fride')..'/mason/packages'
local sources={gopls=lsp..'/'..lm.tools.gopls.path,gofumpt=lsp..'/'..lm.tools.gofumpt.path,
  golines=mason..'/golines/golines'..suffix,
  dlv=vim.fn.executable(sdk..'/bin/dlv'..suffix)==1 and sdk..'/bin/dlv'..suffix or vim.fn.exepath('dlv'),
  ['rust-analyzer']=sysroot..'/bin/rust-analyzer'..suffix,rustfmt=sysroot..'/bin/rustfmt'..suffix,
  codelldb=rust..'/codelldb/extension/adapter/codelldb'..suffix}
for name,path in pairs(sources) do assert(path~='' and vim.fn.executable(path)==1,'Prepare existing tool explicitly: '..name..' '..path) end
local function copy(source,target)
  vim.fn.mkdir(vim.fs.dirname(target),'p');assert(vim.uv.fs_copyfile(source,target))
  if not win then assert(vim.uv.fs_chmod(target,493)) end
end
local function check(name,fn)
  if vim.env.FORGE_GO_RUST_PATH_CASE and not name:find(vim.env.FORGE_GO_RUST_PATH_CASE,1,true) then return end
  T.check('IDE-BOOT-36 '..name,function()
    local e
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=180000,site=test..'/site',snapshot_ignore={['ide tools']=true},
        env={GOTOOLCHAIN='local',GOENV='off',GOWORK='',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
          CGO_ENABLED='0',GOMAXPROCS='2',GOFLAGS='-p=2',GOCACHE=require('go_cache').path(root),
          CARGO_NET_OFFLINE='true',CARGO_BUILD_JOBS='2',RUSTUP_AUTO_INSTALL='0'},
        prepare=function(project,env,runtime)
          env.GOPATH=runtime..'/gopath';env.GOBIN=''
          env.CARGO_HOME=runtime..'/cargo-home';env.CARGO_TARGET_DIR=runtime..'/target'
          env.RUSTUP_HOME=vim.env.RUSTUP_HOME or vim.fs.dirname(vim.fs.dirname(sysroot))
          env.RUSTC=sysroot..'/bin/rustc'..suffix;env.RUSTDOC=sysroot..'/bin/rustdoc'..suffix
          for _,key in ipairs({'RUSTC_WRAPPER','RUSTC_WORKSPACE_WRAPPER','RUSTFLAGS','CARGO_ENCODED_RUSTFLAGS'}) do env[key]=nil end
          local directory=project..'/ide tools';vim.fn.mkdir(directory,'p')
          local selected={}
          for _,id in ipairs({'gopls','gofumpt','golines','dlv'}) do
            local path=directory..'/selected-'..id..suffix;copy(sources[id],path);selected[id]=path
          end
          selected['rust-analyzer']=sources['rust-analyzer'];selected.rustfmt=sources.rustfmt;selected.codelldb=sources.codelldb
          json(project..'/.fride/tools.json',{tools=selected})
          -- Executable-looking shadows make an ignored override fail visibly.
          local shadow=runtime..'/shadow';vim.fn.mkdir(shadow,'p')
          for _,id in ipairs({'gopls','rust-analyzer','rustfmt','codelldb'}) do
            local path=shadow..'/'..id..suffix;vim.fn.writefile({'SHOULD_NOT_EXECUTE'},path)
            if not win then assert(vim.uv.fs_chmod(path,493)) end
          end
          env.PATH=table.concat({shadow,go_bin,sysroot..'/bin',test..'/bin',env.PATH},sep)
          for _,file in ipairs({'go.work','app/go.mod','app/main.go','app/navigation.go','app/main_test.go',
              'shared/go.mod','shared/answer.go','shared/navigation.go'}) do
            local target=project..'/'..file;vim.fn.mkdir(vim.fs.dirname(target),'p')
            assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-workspace/'..file,target))
          end
          vim.fn.writefile({'package main','func   formatted( )int {return  1}'},project..'/app/format.go')
          vim.fn.mkdir(project..'/rust/src','p')
          vim.fn.writefile({'[package]','name="fride_tool_paths"','version="0.1.0"','edition="2021"'},project..'/rust/Cargo.toml')
          vim.fn.writefile({'fn main(){','let value=1;','let observed=value;','println!("RUST_CUSTOM_PATH {}",observed);','}'},project..'/rust/src/main.rs')
          local site=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')..'/site/parser'
          vim.fn.mkdir(site,'p');assert(vim.uv.fs_copyfile(rust..'/site/parser/rust.so',site..'/rust.so'))
          json(runtime..'/selected-tools.json',selected)
        end})
      e:wait('editor ready',function() return e:lua('return _G.forge_e2e_observed') end,12000)
      e.selected=read(e.runtime..'/selected-tools.json')
      e:lua([[_G.tool_path_env={PATH=vim.env.PATH,GOPATH=vim.env.GOPATH,CARGO_HOME=vim.env.CARGO_HOME,RUSTUP_HOME=vim.env.RUSTUP_HOME,GOTOOLCHAIN=vim.env.GOTOOLCHAIN}]])
      fn(e)
      local state=e:lua([[local original=_G.tool_path_env;for key,value in pairs(original) do assert(vim.env[key]==value,key..' changed') end
        return {installs=vim.g.forge_e2e_installs,spawns=_G.forge_e2e_spawns} ]])
      T.eq(state.installs,0);json(e.dir..'/tool-path-processes.json',state)
    end,debug.traceback)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,why=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
    end
    assert(ok,err)
  end)
end
local function open(e,file,server)
  e:input(':edit '..file..'<CR>')
  e:wait(server..' native attach',function() return e:lua([[local name=...;for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name=name})) do
    if c.initialized then return true end end;return false]],{server}) end,40000)
end
local function text(e,buf) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n')]],{buf or 0}) end
check('Go workspace LSP and explicit formatter paths',function(e)
  open(e,'app/format.go','gopls')
  local selected=e:lua([[local c=vim.lsp.get_clients({bufnr=0,name='gopls'})[1];return {root=c.root_dir,command=require('forge.tool_paths').executable('gopls')} ]])
  T.eq(vim.fs.normalize(selected.root),vim.fs.normalize(e.project));T.eq(vim.fs.normalize(selected.command),vim.fs.normalize(e.selected.gopls))
  e:input(' lf');e:wait('Go native formatter',function() return text(e):find('func formatted() int { return 1 }',1,true)~=nil end,15000)
  local commands=e:lua([[local out={};for _,p in ipairs(_G.forge_e2e_spawns) do
    if p.cmd:find('selected-',1,true) then out[#out+1]=p.cmd end end;return out]])
  for _,id in ipairs({'gopls','gofumpt','golines'}) do
    assert(vim.tbl_contains(vim.tbl_map(vim.fs.normalize,commands),vim.fs.normalize(e.selected[id])),id..' was not executed')
  end
end)
check('Rust native LSP and formatter paths',function(e)
  e:input(':cd rust<CR>');open(e,'src/main.rs','rust_analyzer')
  e:input(' lf');e:wait('Rust native formatter',function() return text(e):find('let value = 1;',1,true)~=nil end,15000)
  local commands=e:lua([[local out={};for _,p in ipairs(_G.forge_e2e_spawns) do out[#out+1]=p.cmd end;return out]])
  for _,id in ipairs({'rust-analyzer','rustfmt'}) do assert(vim.tbl_contains(vim.tbl_map(vim.fs.normalize,commands),vim.fs.normalize(e.selected[id])),id) end
end)
check('native Go tests preserve the workspace SDK',function(e)
  open(e,'app/main_test.go','gopls')
  e:lua([[require('neotest').run.run(vim.api.nvim_buf_get_name(0))]])
  e:wait('native Go test finished',function() return vim.fn.filereadable(e.project..'/app/app-runs.txt')==1 end,45000)
  e:wait('test result',function() return e:lua([[local state=require('neotest').state
    for _,id in ipairs(state.adapter_ids()) do local counts=state.status_counts(id)
      if counts and counts.passed>0 and counts.running==0 then return true end end;return false]]) end,20000)
end)
check('user paths and background formatter use the file project',function(e)
  local state=e:lua([[local paths=require('forge.tool_paths');local file=vim.fn.getcwd()..'/app/format.go'
    local project=paths.root(file);local p=project..'/.fride/tools.json'
    local data=vim.json.decode(table.concat(vim.fn.readfile(p),'\n'));local selected=vim.deepcopy(data.tools)
    local user=vim.fn.stdpath('config')..'/tools.json';vim.fn.writefile({vim.json.encode(data)},user)
    data.tools={};vim.fn.writefile({vim.json.encode(data)},p)
    for id,value in pairs(selected) do assert(paths.executable(id,{root=file})==value,id..' user path') end
    local second=project..'/other';vim.fn.mkdir(second..'/.fride','p')
    vim.fn.writefile({vim.json.encode({tools={gofumpt='./missing formatter'}})},second..'/.fride/tools.json')
    vim.cmd.cd(second)
    local command=paths.formatter_command('gofumpt')(nil,{filename=file})
    local ok,why=pcall(paths.executable,'gofumpt',{root=second})
    local buf=vim.fn.bufadd(file);vim.fn.bufload(buf);vim.bo[buf].filetype='go';_G.background_format_buf=buf
    _G.background_format_done=false
    require('conform').format({bufnr=buf,async=true,lsp_format='never'},function(err)
      _G.background_format_error=err and tostring(err);_G.background_format_done=true end)
    return {command=command,expected=selected.gofumpt,other_ok=ok,error=tostring(why)} ]])
  T.eq(state.command,state.expected);T.eq(state.other_ok,false);assert(state.error:find('project:',1,true))
  e:wait('real background formatter finished',function() return e:lua([[return _G.background_format_done]]) end,15000)
  local result=e:lua([[assert(not _G.background_format_error,_G.background_format_error)
    local buf=_G.background_format_buf;local file=vim.api.nvim_buf_get_name(buf)
    assert(table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n'):find('func formatted() int { return 1 }',1,true))
    local p=require('forge.tool_paths').root(file)..'/.fride/tools.json'
    vim.fn.writefile({vim.json.encode({tools={gofumpt='./missing explicit formatter'}})},p)
    local before=#_G.forge_e2e_spawns
    local ok,why=pcall(require('conform').format,{bufnr=buf,async=true})
    assert(#_G.forge_e2e_spawns==before,'Invalid formatter executed a fallback')
    return {ok=ok,error=tostring(why)} ]])
  T.eq(result.ok,false);assert(result.error:find('project:',1,true))
end)
check('debug adapter paths preserve templates and run native Delve',function(e)
  open(e,'app/main.go','gopls')
  e:lua([[local dap=require('dap');for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
    if line:find('E2E_BREAKPOINT',1,true) then vim.api.nvim_win_set_cursor(0,{i,0});dap.toggle_breakpoint();break end end
    dap.run({name='Configured Delve',type='go',request='launch',mode='debug',program=vim.fn.getcwd()..'/app',cwd=vim.fn.getcwd(),outputMode='remote'}) ]])
  e:wait('native Delve breakpoint',function() return e:lua([[local s=require('dap').session();return s and s.current_frame and s.stopped_thread_id~=nil or false]]) end,90000)
  assert(e:lua([[local command=...;for _,p in ipairs(_G.forge_e2e_spawns) do if p.cmd:gsub('\\','/')==command:gsub('\\','/') then return true end end;return false]],{e.selected.dlv}))
  e:lua([[require('dap').continue()]])
  e:wait('debug completed',function() return e:lua([[return require('dap').session()==nil]]) end,20000)
  local adapter=e:lua([[_G.path_cl=nil;require('dap').adapters.codelldb(function(value) _G.path_cl=value end,{cwd=vim.fn.getcwd()..'/rust'});return _G.path_cl]])
  T.eq(vim.fs.normalize(adapter.executable.command),vim.fs.normalize(e.selected.codelldb))
  T.eq(adapter.executable.args,{'--port','${port}'})
end)
check('invalid overrides and report never probe SDKs',function(e)
  open(e,'app/main.go','gopls')
  local state=e:lua([[local p=vim.fn.getcwd()..'/.fride/tools.json';local data=vim.json.decode(table.concat(vim.fn.readfile(p),'\n'))
    data.tools.dlv='./missing delve';data.tools.codelldb='./missing codelldb';vim.fn.writefile({vim.json.encode(data)},p)
    local before=#_G.forge_e2e_spawns;local report=require('forge.tool_paths').report()
    assert(#_G.forge_e2e_spawns==before,'Passive report started processes')
    local errors={};for _,entry in ipairs(report) do if entry.error then errors[entry.id]=entry.error end end
    local a,b=pcall(require('forge.debug_tools').dlv_override)
    data.tools.dlv=nil;vim.fn.writefile({vim.json.encode(data)},p)
    vim.env.FORGE_DLV_PATH='./invalid legacy delve';vim.env.DLV_PATH=...
    local c,d=pcall(require('forge.debug_tools').dlv_override)
    return {errors=errors,project_ok=a,project_error=tostring(b),legacy_ok=c,legacy_error=tostring(d)} ]],{e.selected.dlv})
  assert(state.errors.dlv and state.errors.codelldb);T.eq(state.project_ok,false);T.eq(state.legacy_ok,false)
  assert(state.project_error:find('project:',1,true));assert(state.legacy_error:find('$FORGE_DLV_PATH',1,true))
end)
check('CodeLLDB override runs native Rust breakpoint and output',function(e)
  e:input(':cd rust<CR>');open(e,'src/main.rs','rust_analyzer')
  e:lua([[_G.path_rust_build=nil;vim.system({'cargo','build','--offline'},{text=true},function(result)
    _G.path_rust_build={code=result.code,stderr=result.stderr} end)]])
  e:wait('native offline Cargo build',function() return e:lua([[return _G.path_rust_build~=nil]]) end,45000)
  local built=e:lua([[return _G.path_rust_build]]);T.eq(built.code,0,built.stderr)
  e:lua([[local dap=require('dap');vim.api.nvim_win_set_cursor(0,{3,0});dap.toggle_breakpoint()
    dap.run({name='Configured CodeLLDB',type='codelldb',request='launch',
      program=...,cwd=vim.fn.getcwd(),console='integratedTerminal',sourceLanguages={'rust'}})]],
    {e.runtime..'/target/debug/fride_tool_paths'..suffix})
  e:wait('native Rust breakpoint',function() return e:lua([[local s=require('dap').session()
    return s and s.current_frame and s.stopped_thread_id~=nil or false]]) end,45000)
  T.eq(vim.fs.normalize(e:lua([[return require('dap').session().adapter.executable.command]])),vim.fs.normalize(e.selected.codelldb))
  e:lua([[require('dap').clear_breakpoints();require('dap').continue()]])
  e:wait('Rust debug completed',function() return e:lua([[return require('dap').session()==nil]]) end,20000)
  e:wait('Rust debug output',function() return e:lua([[for _,buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype=='dap-terminal' and table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n'):find('RUST_CUSTOM_PATH 1',1,true) then return true end end;return false]]) end,10000)
end)
T.finish()
