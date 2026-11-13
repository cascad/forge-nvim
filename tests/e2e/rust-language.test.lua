-- spec: IDE-TEST-3 IDE-TEST-4. Реальные Rust/Cargo workspace UI.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function content(e) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]) end
local function text(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local function open(e,file)
  e:input(':edit '..vim.fn.fnameescape(e.rust_project..'/'..file)..'<CR>')
  e:wait('Rust файл '..file,function() return e:current_file():sub(-#file)==file and e:current_ft()=='rust' end)
end
local function seek(e,word)
  e:input('gg/\\<lt>'..word..'\\><CR>')
  e:wait('курсор '..word,function() return e:lua([[return vim.fn.expand('<cword>')]])==word end)
end
local function language(e,file)
  open(e,file)
  e:wait('rust-analyzer готов',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='rust_analyzer'})) do
    if c.initialized and vim.fn.maparg('gd','n',false,true).buffer==1 and _G.forge_rust_server_status and _G.forge_rust_server_status.quiescent then return true end end;return false]]) end,30000)
end
local function state(e)
  return e:lua([[local n=package.loaded.neotest;local d=package.loaded.dap;local s=d and d.session();local positions,statuses={},{};
    if n then for _,id in ipairs(n.state.adapter_ids()) do local tree=n.state.positions(id);if tree then positions[id]=tree:to_list() end;statuses[id]=n.state.status_counts(id) end end;return {
    file=vim.api.nvim_buf_get_name(0),mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
    notifications=vim.g.forge_e2e_notifications,installs=vim.g.forge_e2e_installs,spawns=_G.forge_e2e_spawns,
    diagnostics=vim.diagnostic.get(0),clients=vim.tbl_map(function(c) return {name=c.name,cmd=type(c.config.cmd)=='table' and c.config.cmd or type(c.config.cmd),root=c.root_dir} end,vim.lsp.get_clients()),
    adapters=n and n.state.adapter_ids() or {},positions=positions,statuses=statuses,server_status=_G.forge_rust_server_status,
    session=s and {type=s.config.type,program=s.config.program,cwd=s.config.cwd,paused=s.stopped_thread_id} or false} ]])
end
local function check(name,fn,before_enter)
  if vim.env.FORGE_RUST_CASE and not name:find(vim.env.FORGE_RUST_CASE,1,true) then return end
  T.check((name:match('^IDE%-') and '' or 'SELF: RUST-LANGUAGE ')..name,function()
    local e
    local ok,err=pcall(function()
      require('rust_project').start(root,function(child) e=child end,before_enter)
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/rust-language.test.lua'),e.dir..'/rust-language.test.lua')
      assert(vim.uv.fs_copyfile(root..'/tests/lib/rust_project.lua',e.dir..'/rust_project.lua'))
      fn(e)
      local observed=state(e);vim.fn.writefile({vim.json.encode(observed)},e.dir..'/rust-state.json')
      T.eq(observed.installs,0);assert(not observed.mode.blocking,'неожиданный prompt')
      assert(not observed.messages:match('E%d%d%d+:'),observed.messages)
      for _,n in ipairs(observed.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end)
    if e then
      local got,observed=pcall(state,e)
      if got then vim.fn.writefile({vim.json.encode(observed)},e.dir..'/action-state.json') end
      for _,source in ipairs({e.log_lsp,e.log_cache..'/dap.log',e.log_state..'/neotest.log'}) do
        if vim.fn.filereadable(source)==1 then assert(vim.uv.fs_copyfile(source,e.dir..'/'..vim.fs.basename(source))) end
      end
      for _,source in ipairs(vim.fn.glob(e.log_cache..'/dap*.log',false,true)) do
        assert(vim.uv.fs_copyfile(source,e.dir..'/'..vim.fs.basename(source)))
      end
      if e.rust_stdout and vim.fn.filereadable(e.rust_stdout)==1 then
        assert(vim.uv.fs_copyfile(e.rust_stdout,e.dir..'/test-stdout.txt'))
      end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
local function without_clippy(e)
  local manifest=vim.json.decode(table.concat(vim.fn.readfile(e.rust_deps..'/manifest.json'),'\n'))
  local sdk=manifest.sysroot:gsub('\\','/')..'/bin/'
  local suffix=e.rust_suffix
  local tools=e.runtime..'/cargo-only';vim.fn.mkdir(tools,'p')
  local cargo=tools..'/cargo'..suffix
  assert(vim.uv.fs_copyfile(sdk..'cargo'..suffix,cargo))
  if suffix=='' then assert(vim.uv.fs_chmod(cargo,448)) end
  local copied=assert(io.open(cargo,'rb'));local raw=copied:read('*a');copied:close()
  local original=assert(io.open(sdk..'cargo'..suffix,'rb'));local expected=original:read('*a');original:close()
  T.eq(vim.fn.sha256(raw),vim.fn.sha256(expected),'Cargo binary не изменяется')
  local env=e:lua('return vim.fn.environ()')
  local sep=suffix=='.exe' and ';' or ':'
  local path={tools}
  for _,dir in ipairs(vim.split(env.PATH,sep,{plain=true,trimempty=true})) do
    if vim.fn.filereadable(dir..'/cargo-clippy'..suffix)==0 and vim.fn.filereadable(dir..'/clippy-driver'..suffix)==0
      and vim.fn.filereadable(dir..'/rustup'..suffix)==0 then path[#path+1]=dir end
  end
  env.PATH=table.concat(path,sep);env.CARGO=cargo;env.RUSTC=sdk..'rustc'..suffix
  local missing=vim.system({cargo,'clippy','--version'},{cwd=e.rust_project,env=env,clear_env=true,text=true,timeout=10000}):wait()
  vim.fn.writefile({vim.json.encode({argv={cargo,'clippy','--version'},result=missing,
    cargo_sha256=vim.fn.sha256(raw),path=env.PATH,rustc=env.RUSTC})},e.dir..'/no-clippy.json')
  assert(missing.code~=0 and missing.signal==0 and (missing.stderr or ''):find('clippy',1,true),
    'Fixture должна реально исключить cargo-clippy: '..vim.inspect(missing))
  e:lua([[local env,ra=...;vim.env.PATH=env.PATH;vim.env.CARGO=env.CARGO;vim.env.RUSTC=env.RUSTC
    require('lazy').load({plugins={'nvim-lspconfig'}})
    vim.lsp.config('rust_analyzer',{cmd={ra}});vim.lsp.enable('rust_analyzer')]],{env,sdk..'rust-analyzer'..suffix})
end
check('IDE-RUST-1 Cargo diagnostics без Clippy',function(e)
  local file=e.rust_project..'/app/src/lib.rs'
  vim.fn.writefile({'#[deprecated(note = "FORGE_CARGO_DIAGNOSTIC")]','pub fn old_api() {}',
    '#[deny(deprecated)]','pub fn call_api() {','    old_api();','}'},file)
  open(e,'app/src/lib.rs');e:input(':write<CR>')
  local function compiler_error()
    return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do
      if d.source=='rustc' and tostring(d.code)=='deprecated' and d.message:find('FORGE_CARGO_DIAGNOSTIC',1,true) then return d end
    end;return false]])
  end
  local diagnostic
  e:wait('настоящая rustc diagnostic без Clippy',function()
    if vim.fn.filereadable(e.log_lsp)==1 then
      local log=table.concat(vim.fn.readfile(e.log_lsp),'\n')
      assert(not (log:find('Flycheck failed',1,true) and log:find('no such command',1,true) and log:find('clippy',1,true)),
        'Native flycheck выбрал отсутствующий Clippy; смотри lsp.log')
    end
    diagnostic=compiler_error();return diagnostic~=false
  end,30000)
  T.eq(diagnostic.severity,1)
  vim.fn.writefile({vim.json.encode(diagnostic)},e.dir..'/compiler-diagnostic.json')
  e:input('5Ggl')
  e:wait('gl показывает compiler diagnostic',function() return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative~='' and table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n'):find('FORGE_CARGO_DIAGNOSTIC',1,true) then return true end
  end;return false]]) end)
  e:input('<Esc>5Gcc    // corrected<Esc>:write<CR>')
  e:wait('compiler diagnostic убрана после save',function() return compiler_error()==false end,30000)
  T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
end,without_clippy)
local function held_build_script(e)
  local before=e:lua([[return {clients=#vim.lsp.get_clients({name='rust_analyzer'}),spawns=_G.forge_e2e_spawns}]])
  T.eq(before.clients,0,'Без Cargo.toml в initial cwd Rust не запускается')
  for _,spawn in ipairs(before.spawns) do
    assert(not vim.fs.basename(spawn.cmd):find('rust-analyzer',1,true),'Rust backend до выбора Cargo project')
  end
  e.warmup_gate=e.runtime..'/warmup-build-gate';vim.fn.mkdir(e.warmup_gate,'p')
  e:lua('vim.env.FORGE_E2E_WARMUP_GATE=...',{e.warmup_gate})
  vim.fn.writefile({'native UI during Cargo preparation'},e.rust_project..'/README.txt')
  vim.fn.writefile({
    'fn main() {',
    '    println!("cargo:rerun-if-changed=build.rs");',
    '    let gate = std::path::PathBuf::from(std::env::var("FORGE_E2E_WARMUP_GATE").unwrap());',
    '    std::fs::write(gate.join("started"), std::process::id().to_string()).unwrap();',
    '    let until = std::time::Instant::now() + std::time::Duration::from_secs(20);',
    '    while !gate.join("release").exists() {',
    '        assert!(std::time::Instant::now() < until, "native build gate timed out");',
    '        std::thread::sleep(std::time::Duration::from_millis(10));',
    '    }',
    '}'},e.rust_project..'/app/build.rs')
end
check('IDE-RUST-2 IDE-BOOT-7 prepare до первого Rust файла сохраняет UI и reuse',function(e)
  local evidence={}
  local ok,err=xpcall(function()
    evidence.before=e:lua([[local rust=0;for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='rust' then rust=rust+1 end end
      return {rust_buffers=rust,clients=#vim.lsp.get_clients({name='rust_analyzer'}),cwd=vim.fn.getcwd()}]])
    T.eq(evidence.before.rust_buffers,0)
    local id
    e:wait('Rust client запущен до первого файла',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({name='rust_analyzer'})) do
      if c.initialized then return c.id end end;return false]])~=false end,5000)
    id=e:lua([[return vim.lsp.get_clients({name='rust_analyzer'})[1].id]])
    e:wait('реальный build script выполняется',function() return vim.fn.filereadable(e.warmup_gate..'/started')==1 end,15000)
    evidence.build_pid=tonumber(vim.fn.readfile(e.warmup_gate..'/started')[1])
    assert(evidence.build_pid and evidence.build_pid>0)
    T.eq(vim.fn.filereadable(e.warmup_gate..'/release'),0)
    evidence.prepared=e:lua([[local out={};for _,name in ipairs({'Comment.nvim','indent-blankline.nvim',
      'vim-illuminate','barbecue.nvim','satellite.nvim','nvim-hlslens'}) do
      out[name]=not not require('lazy.core.config').plugins[name]._.loaded end;return out]])
    for name,ready in pairs(evidence.prepared) do T.eq(ready,true,name..' не подготовлен до первого файла') end
    evidence.startup_ms=e:lua([[return require('lazy').stats().startuptime]])
    local began=vim.uv.hrtime()
    e:input(':edit '..vim.fn.fnameescape(e.rust_project..'/README.txt')..'<CR>')
    e:wait('обычный текст во время Cargo preparation',function()
      return e:current_file():sub(-10)=='README.txt' and e:current_ft()=='text'
    end)
    evidence.text_open_ms=(vim.uv.hrtime()-began)/1e6
    began=vim.uv.hrtime();e:input('A_FORGE_WARMUP_UI<Esc>')
    e:wait('ввод во время compile-time deps',function() return e:lua('return vim.api.nvim_get_current_line()'):find('FORGE_WARMUP_UI',1,true)~=nil end)
    evidence.input_ms=(vim.uv.hrtime()-began)/1e6
    T.eq(e:lua([[return #vim.lsp.get_clients({bufnr=0,name='rust_analyzer'})]]),0,'RA не attach к txt')
    began=vim.uv.hrtime();open(e,'app/src/lib.rs')
    evidence.rust_open_ms=(vim.uv.hrtime()-began)/1e6
    e:wait('Rust file использует подготовленный client',function() return e:lua([[local id=...;for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='rust_analyzer'})) do
      if c.id==id then return true end end;return false]],{id}) end)
    evidence.client_id=id;evidence.clients=e:lua([[local out={};for _,c in ipairs(vim.lsp.get_clients({name='rust_analyzer'})) do out[#out+1]={id=c.id,root=c.config.root_dir} end;return out]])
    T.eq(#evidence.clients,1)
    for _,key in ipairs({'text_open_ms','input_ms','rust_open_ms'}) do assert(evidence[key]<300,key..': '..evidence[key]..'ms >=300ms') end
  end,debug.traceback)
  vim.fn.writefile({'release'},e.warmup_gate..'/release')
  evidence.ok=ok;evidence.error=not ok and tostring(err) or nil
  vim.fn.writefile({vim.json.encode(evidence)},e.dir..'/rust-warmup.json')
  assert(ok,err)
  e:wait('Cargo preparation завершена',function() return e:lua([[return _G.forge_rust_server_status and _G.forge_rust_server_status.quiescent or false]]) end,30000)
  T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
end,held_build_script)
check('Rust LSP definition references rename между workspace crates',function(e)
  language(e,'app/src/use_math.rs');seek(e,'calculate_answer');e:input('gd')
  e:wait('definition в local crate',function() return e:current_file():sub(-15)=='math/src/lib.rs' end,30000)
  open(e,'app/src/use_math.rs');seek(e,'calculate_answer');e:input('gr')
  e:wait('references quickfix',function() return e:current_ft()=='qf' end,20000)
  local refs=e:lua([[local found={};for _,r in ipairs(vim.fn.getqflist()) do local p=vim.api.nvim_buf_get_name(r.bufnr);if p:find('use_math.rs',1,true) then found[tostring(r.lnum)]=true end end;return found]])
  assert(refs['2'] and refs['6'],vim.inspect(refs));e:input('<CR>')
  open(e,'app/src/use_math.rs');seek(e,'calculate_answer');e:input('<F2>')
  e:wait('rename prompt',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
  e:input('<C-u>twice_forge<CR>')
  e:wait('rename usages',function() return content(e):find('twice_forge(21)',1,true)~=nil end,20000)
  e:input(':wall<CR>')
  e:wait('rename сохранён в двух crates',function()
    local a=table.concat(vim.fn.readfile(e.rust_project..'/math/src/lib.rs'),'\n')
    local b=table.concat(vim.fn.readfile(e.rust_project..'/app/src/use_math.rs'),'\n')
    return a:find('pub fn twice_forge(',1,true) and b:find('twice_forge(21)',1,true) and b:find('twice_forge(2)',1,true)
  end,20000)
end)
check('Rust LSP completion diagnostics correction',function(e)
  language(e,'app/src/complete.rs');e:input('2G0f0ciw')
  e:wait('insert ready',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('forge_math::FORG<C-Space>')
  e:wait('LSP cmp FORGE_ANSWER',function() return e:lua([[local c=require('cmp');if not c.visible() then return false end;for _,v in ipairs(c.get_entries()) do
    if v.source.name=='nvim_lsp' and v.completion_item.label:find('FORGE_ANSWER',1,true) then return true end end;return false]]) end,30000)
  for _=1,30 do
    if e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label:find('FORGE_ANSWER',1,true)~=nil or false]]) then break end
    e:input('<C-n>');vim.wait(60)
  end
  assert(e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label:find('FORGE_ANSWER',1,true)~=nil or false]]))
  e:input('<CR>');e:wait('completion вставлен',function() return content(e):find('forge_math::FORGE_ANSWER',1,true)~=nil end)
  e:input('<Esc>')
  e:input('2Gcc    MISSING_FORGE_NAME<Esc>')
  e:wait('native Rust diagnostic',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.severity==1 and d.message:find('MISSING_FORGE_NAME',1,true) then return true end end;return false]]) end,30000)
  e:input('gl');e:wait('diagnostic UI',function() return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative~='' and
    table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n'):find('MISSING_FORGE_NAME',1,true) then return true end end;return false]]) end)
  e:input('<Esc>2Gcc    forge_math::FORGE_ANSWER<Esc>:write<CR>')
  e:wait('исправление убрало diagnostic',function() return e:lua([[return #vim.diagnostic.get(0,{severity=1})==0]]) end,30000)
end)
check('Rust rustfmt manual и after save',function(e)
  open(e,'app/src/format.rs');e:input(' lf')
  local expected='pub fn unformatted() -> i32 {\n    let value = 42;\n    value\n}'
  e:wait('rustfmt manual',function() return content(e)==expected end,15000)
  e:input('ggVGcpub fn unformatted( )->i32{let value=42;value}<Esc>:write<CR>')
  e:wait('rustfmt сохранён без второго write',function() return table.concat(vim.fn.readfile(e.rust_project..'/app/src/format.rs'),'\n')==expected end,15000)
end)
local function choose(e,name)
  e:wait('DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(name);e:wait('DAP config выбран',function() return e:lua([[local name=...;local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find(name,1,true) and not v.ordinal:find(name..' (args)',1,true) or false]],{name}) end)
  e:input('<CR>')
end
local function breakpoint(e)
  e:wait('Rust breakpoint или настоящая ошибка launch',function()
    for _,n in ipairs(e.rpc.notifications) do if n.level>=vim.log.levels.ERROR then return true end end
    return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil or false]])
  end,45000)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
end
local function debugged(e,marker)
  breakpoint(e)
  e:input('<F7>');seek(e,'value');e:input(' de')
  e:wait('eval 42',function() return text(e,'dap-float'):find('42',1,true)~=nil end,15000)
  e:input('q<F7><F5>');e:wait('Rust session завершена',function() return e:lua([[return require('dap').session()==nil]]) end,30000)
  e:wait('Rust output сохранён',function() return text(e,'dap-terminal'):find(marker,1,true)~=nil end,15000)
end
check('Rust F5 default Cargo preLaunch build и output',function(e)
  open(e,'app/src/main.rs');e:input('gg/E2E_BREAKPOINT<CR><F9>')
  T.eq(vim.fn.filereadable(e.rust_target..'/debug/forge_app'..e.rust_suffix),0)
  e:input('<F5>');choose(e,'Current Rust file bin');debugged(e,'RUST_BEFORE 42')
  assert(text(e,'dap-terminal'):find('RUST_STDERR',1,true));assert(text(e,'dap-terminal'):find('RUST_AFTER',1,true))
  T.eq(vim.fn.filereadable(e.rust_target..'/debug/forge_app'..e.rust_suffix),1)
  assert(table.concat(vim.fn.readfile(e.rust_project..'/app/rust-cwd.txt'),'\n'):gsub('\\','/'):find('/app',1,true))
end)
check('Rust alternate binary и project launch.json',function(e)
  open(e,'app/src/bin/alternate.rs');e:input('gg/E2E_BREAKPOINT<CR><F9><F5>');choose(e,'Current Rust file bin');debugged(e,'RUST_ALTERNATE 42')
  local cfg={name='Project Rust',type='codelldb',request='launch',program=e.rust_target..'/debug/alternate'..e.rust_suffix,
    cwd=e.rust_project..'/app',args={'from-launch'},console='integratedTerminal',sourceLanguages={'rust'},preLaunchTask='cargo build (debug)'}
  vim.fn.writefile({vim.json.encode({version='0.2.0',configurations={cfg}})},e.rust_project..'/.vscode/launch.json')
  e:input('<F7><F5>');choose(e,'Project Rust');debugged(e,'RUST_ALTERNATE 42 from-launch')
end)
check('IDE-DAP-7 Rust Cargo target отмена и запуск выбранного второго bin',function(e)
  for _,file in ipairs({'Cargo.toml','src/lib.rs','src/main.rs','src/bin/alternate.rs'}) do
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/rust-target-choice/'..file,e.rust_project..'/app/'..file))
  end
  open(e,'app/src/lib.rs');e:input('gg/E2E_BREAKPOINT<CR><F9><F5>')
  choose(e,'Current Rust file bin')
  local function target_picker()
    return e:current_ft()=='TelescopePrompt' and e:lua([[local v=require('telescope.actions.state').get_selected_entry();
      return v and v.ordinal:find('_worker',1,true)~=nil or false]])
  end
  e:wait('список реальных Cargo targets',target_picker)
  e:input('<Esc><Esc>')
  e:wait('выбор отменён без DAP session',function()
    return e:current_ft()~='TelescopePrompt' and e:lua([[return require('dap').session()==nil]])
  end)
  local marker=e.rust_project..'/app/rust-target-ran.txt'
  T.eq(vim.fn.filereadable(marker),0,'отмена запустила первый binary')
  e:input('<F7><F5>');choose(e,'Current Rust file bin')
  e:wait('повторный список Cargo targets',target_picker)
  e:input('beta_worker')
  e:wait('выбран beta_worker',function()
    return e:lua([[local v=require('telescope.actions.state').get_selected_entry();
      return v and v.ordinal:find('beta_worker',1,true)~=nil or false]])
  end)
  e:input('<CR>');breakpoint(e)
  local program=e:lua([[return require('dap').session().config.program]])
  T.eq(vim.fs.basename(program),'beta_worker'..e.rust_suffix)
  T.eq(vim.fn.readfile(marker),{'BETA'},'запущена другая Cargo цель')
  debugged(e,'RUST_CHOICE_BETA 42')
  assert(not text(e,'dap-terminal'):find('RUST_CHOICE_ALPHA',1,true),'запущен первый target вместо выбранного')
end)

local function counts(e)
  return e:lua([[local n=require('neotest');local out={passed=0,failed=0,skipped=0,running=0,total=0};for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);if s then
    for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end;return out]])
end
local function discover(e)
  e:input(' wt');e:wait('Rust Tests',function() return e:current_ft()=='neotest-summary' end)
  e:wait('Rust tests обнаружены',function() return counts(e).total==3 end,30000)
  e:input('<F7>');e:wait('Rust code focus',function() return e:current_ft()=='rust' end)
end
check('IDE-TEST-3 Rust nextest nearest/file pass fail output',function(e)
  open(e,'math/src/lib.rs');discover(e);e:input('gg/E2E_BREAKPOINT<CR> Tt')
  e:wait('nearest result',function() local s=counts(e);return s.passed+s.failed+s.skipped>0 and s.running==0 end,45000)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0);T.eq(vim.fn.filereadable(e.rust_project..'/math/neighbor-ran.txt'),0)
  e:wait('Test Output',function() return text(e,'neotest-output-panel'):find('RUST_TEST_VALUE 42',1,true)~=nil end)
  e:input('<F7> Tf');e:wait('file pass fail',function() local s=counts(e);return s.passed==1 and s.failed==1 and s.running==0 end,45000)
  T.eq(vim.fn.filereadable(e.rust_project..'/math/neighbor-ran.txt'),1)
end)
check('IDE-TEST-3 Rust nextest integration test',function(e)
  open(e,'math/tests/integration.rs');discover(e);e:input('gg/integration_pass<CR> Tt')
  e:wait('integration result',function() local s=counts(e);return s.passed+s.failed+s.skipped>0 and s.running==0 end,45000)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0)
  e:wait('integration output',function() return text(e,'neotest-output-panel'):find('RUST_INTEGRATION_OK',1,true)~=nil end)
  T.eq(vim.fn.filereadable(e.rust_project..'/math/neighbor-ran.txt'),0)
end)
check('IDE-TEST-4 Rust debug nearest breakpoint eval continue',function(e)
  open(e,'math/src/lib.rs');discover(e);e:input('gg/E2E_BREAKPOINT<CR><F9> Td')
  breakpoint(e)
  e.rust_stdout=e:lua([[return require('dap').session().config.stdio[2] ]])
  assert(e.rust_stdout:gsub('\\','/'):sub(1,#e.runtime:gsub('\\','/'))==e.runtime:gsub('\\','/'),'Stdout вне private runtime')
  e:input('<F7>');seek(e,'value');e:input(' de')
  e:wait('test eval 42',function() return text(e,'dap-float'):find('42',1,true)~=nil end,15000)
  e:input('q<F7><F5>');e:wait('test result',function() local s=counts(e);return s.passed==1 and s.failed==0 and s.running==0 end,45000)
  T.eq(vim.fn.filereadable(e.rust_project..'/math/neighbor-ran.txt'),0)
  e:input(' wr');e:wait('debug test output виден',function() return text(e,'neotest-output-panel'):find('RUST_TEST_VALUE 42',1,true)~=nil end)
  -- CodeLLDB может создать CPython __pycache__: readiness всё ещё работает
  -- без повторной установки и без записи в подготовленный каталог.
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
  assert(python~='','Нужен host Python для readiness CLI')
  local manifest=table.concat(vim.fn.readfile(e.rust_deps..'/manifest.json'),'\n')
  local ready=vim.system({python,'-B',root..'/tests/e2e/prepare_rust.py','--output',e.rust_deps,
    '--rustc',e.rustc,'--nvim',vim.v.progpath},{text=true,timeout=60000}):wait()
  vim.fn.writefile(vim.split((ready.stdout or '')..(ready.stderr or ''),'\n',{plain=true}),e.dir..'/readiness-after-debug.txt')
  assert(ready.code==0,ready.stderr)
  T.eq(table.concat(vim.fn.readfile(e.rust_deps..'/manifest.json'),'\n'),manifest,'readiness не переписывает manifest')
end)
T.finish()
