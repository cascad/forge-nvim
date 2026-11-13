-- WF-04/05: выбранный repo и независимые native language/run contexts.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function copy(from,to)
  vim.fn.mkdir(to,'p')
  for name,kind in vim.fs.dir(from) do
    if kind=='directory' then copy(from..'/'..name,to..'/'..name)
    else assert(kind=='file',from..'/'..name);assert(vim.uv.fs_copyfile(from..'/'..name,to..'/'..name)) end
  end
end
T.check('SELF: MIXED-PROJECT шесть language roots, Node script и Python venv debug',function()
  local e,report,logs
  local ok,err=xpcall(function()
    local win=vim.fn.has('win32')==1;local sep=win and ';' or ':';local suffix=win and '.exe' or ''
    local deps={}
    for _,name in ipairs({'node','python','rust','bash','sql','lsp','test'}) do
      deps[name]=vim.env['FORGE_E2E_'..name:upper()..'_DEPS'] or root..'/.tests/'..name..'-deps'
    end
    local go=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
    local node=read(deps.node..'/manifest.json');local python=read(deps.python..'/manifest.json')
    local rust=read(deps.rust..'/manifest.json');local bash=read(deps.bash..'/manifest.json')
    local node_exe=deps.node..'/'..node.node
    local tools_python=deps.python..'/'..python.tools_python
    local sysroot=rust.sysroot:gsub('\\','/')
    local path={vim.fs.dirname(node_exe),deps.python..'/tools/node_modules/.bin',vim.fs.dirname(tools_python),
      sysroot..'/bin',deps.lsp..'/bin',go..'/go/bin',deps.bash..'/bin',deps.sql..'/bin',vim.env.PATH}
    local prepared,project_python
    e=require('editor').start(root,{timeout=240000,site=deps.node..'/site',
      snapshot_ignore={node_modules=true,['.venv']=true,__pycache__=true},env={PATH=table.concat(path,sep),
        FORGE_NODE_EXECUTABLE=node_exe,FORGE_NODE_TOOLS=deps.node..'/tools',
        FORGE_BASH_EXECUTABLE=bash.bash,FORGE_SQLS_EXECUTABLE=deps.sql..'/bin/sqls'..suffix,
        FORGE_SQRUFF_EXECUTABLE=deps.sql..'/bin/sqruff'..suffix,
        FORGE_PYTHON_PATH='',VIRTUAL_ENV='',CONDA_PREFIX='',PYTHONHOME='',PYTHONPATH='',
        FORGE_DEBUGPY_PYTHON=tools_python,FORGE_DEBUGPY_ADAPTER=vim.fs.dirname(tools_python)..'/debugpy-adapter'..suffix,
        PYTHONNOUSERSITE='1',PYTHONIOENCODING='utf-8',NODE_OPTIONS='',NODE_PATH='',
        npm_config_offline='true',npm_config_audit='false',npm_config_update_notifier='false',
        GOTOOLCHAIN='local',GOENV='off',GOWORK='',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
        GOMAXPROCS='2',GOFLAGS='-p=2',CGO_ENABLED='0',GOCACHE=require('go_cache').path(root),
        RUSTUP_AUTO_INSTALL='0',CARGO_NET_OFFLINE='true',CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2',
        RUSTC=sysroot..'/bin/rustc'..suffix,RUSTDOC=sysroot..'/bin/rustdoc'..suffix},
      prepare=function(project,env,runtime)
        copy(root..'/tests/e2e/fixtures/mixed-project',project)
        for _,name in ipairs({'go.work','app/go.mod','app/main.go','shared/go.mod','shared/answer.go'}) do
          vim.fn.mkdir(vim.fs.dirname(project..'/go/'..name),'p')
          assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-workspace/'..name,project..'/go/'..name))
        end
        local data=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')
        for _,name in ipairs({'test','python','rust','bash','sql'}) do
          copy(deps[name]..'/site/parser',data..'/site/parser')
        end
        -- Native project-local deps: links не обходятся snapshot/owned cleanup.
        for _,pair in ipairs({{deps.node..'/tools/node_modules',project..'/web/node_modules'},
            {deps.bash..'/tools/node_modules',project..'/node_modules'}}) do
          assert(vim.uv.fs_symlink(assert(vim.uv.fs_realpath(pair[1])),pair[2],win and {junction=true} or {dir=true}))
        end
        env.GOPATH=runtime..'/go';env.GOBIN='';env.PYTHONPYCACHEPREFIX=runtime..'/pycache'
        env.DEBUGPY_LOG_DIR=runtime..'/debugpy-logs'
        env.CARGO_HOME=runtime..'/cargo-home';env.CARGO_TARGET_DIR=runtime..'/target'
        env.RUSTUP_HOME=vim.env.RUSTUP_HOME or vim.fn.fnamemodify(sysroot,':h:h')
        for _,k in ipairs({'RUSTC_WRAPPER','RUSTC_WORKSPACE_WRAPPER','RUSTFLAGS','CARGO_ENCODED_RUSTFLAGS',
            'VIRTUAL_ENV','CONDA_PREFIX','PYTHONHOME','PYTHONPATH'}) do env[k]=nil end
        vim.fn.mkdir(env.CARGO_HOME,'p')
        local venv=project..'/python/.venv'
        project_python=venv..(win and '/Scripts/python.exe' or '/bin/python')
        local r=vim.system({python.host_python,'-m','venv','--without-pip',venv},
          {env=env,clear_env=true,text=true}):wait();assert(r.code==0,r.stderr);prepared=r.stdout..r.stderr
        r=vim.system({python.host_python,'-B','-c',"import sqlite3,sys;d=sqlite3.connect(sys.argv[1]);d.execute('CREATE TABLE fixture(value INTEGER)');d.commit();d.close()",project..'/db/mixed.sqlite3'},
          {env=env,clear_env=true,text=true}):wait();assert(r.code==0,r.stderr)
        vim.fn.writefile({vim.json.encode({connections={{alias='Mixed',driver='sqlite3',dataSourceName='file:mixed.sqlite3?mode=rw'}}})},project..'/db/.sqls.json')
        vim.fn.writefile({'node_modules/','.venv/','db/mixed.sqlite3','db/.sqls.json','python-run.txt','web/node-run.txt'},project..'/.gitignore')
      end})
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/mixed-project.test.lua',e.dir..'/mixed-project.test.lua'))
    vim.fn.writefile(vim.split(prepared,'\n',{plain=true}),e.dir..'/prepare.txt')
    report={states={}}
    e:lua([[vim.lsp.log.set_level('debug');require('dap').set_log_level('TRACE')]])
    logs=e:lua([[return {lsp=vim.lsp.log.get_filename(),cache=vim.fn.stdpath('cache'),debugpy=vim.env.DEBUGPY_LOG_DIR}]])
    local project=e.project:gsub('\\','/')
    local function state()
      return e:lua([[local clients={};for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do
        clients[c.name]={id=c.id,root=c.root_dir:gsub('\\','/'),initialized=c.initialized,
          python=c.settings.python and c.settings.python.pythonPath}
        end;local d=package.loaded.dap;local s=d and d.session();return {
          file=vim.api.nvim_buf_get_name(0):gsub('\\','/'),ft=vim.bo.filetype,clients=clients,
          cwd=vim.fn.getcwd():gsub('\\','/'),installs=vim.g.forge_e2e_installs,
          session=s and {type=s.config.type,program=s.config.program,cwd=s.config.cwd,python=s.config.python} or false,
          debug_timing=_G.forge_mixed_debug_timing,
          mode=vim.api.nvim_get_mode()}]])
    end
    local function capture(label)
      local s=state();T.eq(s.cwd,project);T.eq(s.installs,0);assert(not s.mode.blocking)
      report.states[label]=s;vim.fn.writefile({vim.json.encode(report)},e.dir..'/mixed-project.json');return s
    end
    local function open(file,ft,server,server_root)
      e:input('<F7>:edit '..file..'<CR>')
      e:wait('mixed '..file..' + '..server,function()
        local s=state();local c=s.clients[server]
        report.pending_open={file=file,state=s}
        return s.file==project..'/'..file and s.ft==ft and c and c.initialized and c.root==server_root
      end,60000)
      return capture(file)
    end
    local first=open('go/app/main.go','go','gopls',project..'/go')
    open('rust/src/main.rs','rust','rust_analyzer',project..'/rust')
    local py=open('python/app.py','python','pyright',project..'/python')
    T.eq(py.clients.pyright.python:gsub('\\','/'),project_python:gsub('\\','/'))
    open('web/app.js','javascript','ts_ls',project..'/web')
    open('scripts/run.sh','sh','bashls',project)
    open('db/query.sql','sql','sqls',project..'/db')
    open('web/app.js','javascript','ts_ls',project..'/web')
    local function picker()
      e:wait('script picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    end
    e:input(' jn');picker();e:input('<Esc><Esc>')
    e:wait('cancel вернул код',function() return e:current_ft()=='javascript' end)
    T.eq(e:lua([[return #require('overseer').list_tasks()]]),0)
    T.eq(vim.fn.filereadable(e.project..'/web/node-run.txt'),0)
    e:input(' jn');picker();e:input('start')
    e:wait('script start выбран',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal=='start' or false]]) end)
    e:input('<CR>')
    e:wait('настоящий npm script завершён',function() return e:lua([[local t=require('overseer').list_tasks();return #t==1 and t[1].status=='SUCCESS']]) end,30000)
    T.eq(table.concat(vim.fn.readfile(e.project..'/web/node-run.txt'),'' ):gsub('\\','/'),project..'/web|nested-script')
    report.task=e:lua([[local t=require('overseer').list_tasks()[1];return {name=t.name,status=t.status} ]])
    open('python/app.py','python','pyright',project..'/python')
    e:lua([[_G.forge_mixed_debug_timing={start=vim.uv.hrtime()};local d=require('dap')
      d.listeners.after.event_initialized.forge_mixed_timing=function(s)
        local t=_G.forge_mixed_debug_timing;t.elapsed_ms=(vim.uv.hrtime()-t.start)/1e6
        t.timeout=s.adapter.options.initialize_timeout_sec
      end]])
    e:input('gg/MIX_BREAKPOINT<CR><F9><F5>')
    e:wait('default Python picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
    e:input('Current Python file')
    e:wait('без args configuration',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Current Python file',1,true) and not v.ordinal:find('(args)',1,true) or false]]) end)
    e:input('<CR>')
    e:wait('реальный Python breakpoint',function() return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil or false]]) end,40000)
    local paused=capture('python-paused');T.eq(paused.session.type,'debugpy')
    T.eq(paused.debug_timing.timeout,30);assert(paused.debug_timing.elapsed_ms>0)
    T.eq(paused.session.program:gsub('\\','/'),project..'/python/app.py')
    T.eq(paused.session.python:gsub('\\','/'),project_python:gsub('\\','/'))
    T.eq(paused.session.cwd:gsub('\\','/'),project)
    T.eq(table.concat(vim.fn.readfile(e.project..'/python-run.txt'),'' ):gsub('\\','/'),project..'/python/.venv')
    local function output()
      local p=require('output_policy').state(e,'dap-repl')[1];return p and p.text or ''
    end
    e:wait('Python output до pause',function() return e:has_window('dap-repl') and output():find('MIX_PY_BEFORE 42',1,true) end)
    e:input('<F7><F5>')
    e:wait('Python exit и output',function() return e:lua([[return require('dap').session()==nil]]) and output():find('MIX_PY_AFTER 42',1,true) end,30000)
    report.output=output()
    local returned=open('go/app/main.go','go','gopls',project..'/go')
    T.eq(returned.clients.gopls.id,first.clients.gopls.id);T.eq(returned.session,false)
  end,debug.traceback)
  if e then
    report=report or {};report.ok=ok;report.error=not ok and err or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/mixed-project.json')
    -- Пути получены заранее: blocking prompt не должен лишать нас первичных logs.
    if logs then
      local sources={logs.lsp}
      vim.list_extend(sources,vim.fn.glob(logs.cache..'/dap*.log',false,true))
      vim.list_extend(sources,vim.fn.glob(logs.debugpy..'/*.log',false,true))
      for _,p in ipairs(sources) do if vim.fn.filereadable(p)==1 then
        assert(vim.uv.fs_copyfile(p,e.dir..'/'..vim.fs.basename(p))) end end
    end
    local snapped,why=pcall(e.snapshot,e,'mixed-project')
    if not snapped then ok=false;err=tostring(err or '')..'\nSnapshot: '..tostring(why) end
    io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
  end
  assert(ok,err)
end)
T.finish()
