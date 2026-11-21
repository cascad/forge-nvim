-- spec: IDE-PY-3. Реальный F5 без project venv и Python SDK overrides.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local uv=vim.uv
local win=vim.fn.has('win32')==1
local sep,suffix=win and ';' or ':',win and '.exe' or ''
local deps=vim.env.FORGE_E2E_PYTHON_DEPS or root..'/.tests/python-deps'
local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
for path,hash in pairs(manifest.files) do
  local file=assert(io.open(deps..'/'..path,'rb'));local raw=file:read('*a');file:close()
  T.eq(vim.fn.sha256(raw),hash,'prepared Python deps: '..path)
end
local function key(path)
  local result=vim.fs.normalize(path):gsub('\\','/')
  return win and result:lower() or result
end
local function output(e)
  return e:lua([[local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype=='dap-repl' then
      vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]])
end
local function launch(e)
  e:input('<F5>')
  e:wait('Current File picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('Current Python file')
  e:wait('Current File selected',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();
    return v and v.ordinal:find('Current Python file',1,true) and not v.ordinal:find('(args)',1,true) or false]]) end)
  e:input('<CR>')
end
local function debugged(e,info)
  e:wait('real CPython breakpoint',function() return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil or false]]) end,30000)
  T.eq(key(e:lua([[return require('dap').session().config.python]])),key(info.good))
  e:input('<F7><F5>')
  e:wait('real stdout and normal exit',function() return e:lua([[return require('dap').session()==nil]]) and output(e):find('PY_AUTO_OK',1,true)~=nil end,30000)
  assert(key(output(e)):find(key(info.good),1,true),'stdout must identify actual PATH interpreter')
end
local function state(e)
  return e:lua([[return {mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
    installs=vim.g.forge_e2e_installs,notifications=vim.g.forge_e2e_notifications,
    spawns=_G.forge_e2e_spawns,logs=require('forge.log_store').memory,
    session=require('dap').session()~=nil,probe=_G.forge_python_probe_result}]])
end
local function adapter_count(e,info)
  local count=0
  for _,spawn in ipairs(e:lua('return _G.forge_e2e_spawns')) do if key(spawn.cmd)==key(info.adapter) then count=count+1 end end
  return count
end
for _,case in ipairs({'auto PATH','explicit invalid SDK and recovery','stale project'}) do
  if not vim.env.FORGE_PY_AUTO_CASE or case:find(vim.env.FORGE_PY_AUTO_CASE,1,true) then
    T.check('IDE-PY-3 '..case,function()
      local e,info
      local ok,err=xpcall(function()
        e=require('editor').start(root,{timeout=45000,site=deps..'/site',
          env={VIRTUAL_ENV='',CONDA_PREFIX='',PYTHONHOME='',PYTHONPATH='',
            FORGE_PYTHON_PATH='',FORGE_DEBUGPY_ADAPTER='',FORGE_DEBUGPY_PYTHON='',
            FORGE_NODE_EXECUTABLE=manifest.node,FORGE_NODE_TOOLS=deps..'/tools',PYTHONNOUSERSITE='1'},
          prepare=function(project,env,runtime)
            for _,name in ipairs({'VIRTUAL_ENV','CONDA_PREFIX','PYTHONHOME','PYTHONPATH',
              'FORGE_PYTHON_PATH','FORGE_DEBUGPY_ADAPTER','FORGE_DEBUGPY_PYTHON'}) do env[name]=nil end
            local sdk=runtime..'/system-sdk'
            local result=vim.system({manifest.host_python,'-m','venv','--without-pip',sdk},
              {env=env,clear_env=true,text=true,timeout=30000}):wait()
            assert(result.code==0,result.stderr)
            local goodbin=sdk..(win and '/Scripts' or '/bin')
            local badbin,tools=runtime..'/invalid-sdk',runtime..'/adapter-only'
            vim.fn.mkdir(badbin,'p');vim.fn.mkdir(tools,'p')
            info={good=goodbin..'/'..(win and 'python.exe' or 'python3'),
              bad=badbin..'/'..(win and 'python3.exe' or 'python'),adapter=tools..'/debugpy-adapter'..suffix}
            -- Controlled unusable CLI; actual incident used a broken MSYS2 Python.
            -- Node is standalone: no missing Python DLL/native error dialog fixture.
            assert(uv.fs_copyfile(manifest.node,info.bad));assert(uv.fs_chmod(info.bad,493))
            local prepared=vim.fs.dirname(deps..'/'..manifest.tools_python)
            for _,name in ipairs({'debugpy-adapter','ruff'}) do
              assert(uv.fs_copyfile(prepared..'/'..name..suffix,tools..'/'..name..suffix))
              assert(uv.fs_chmod(tools..'/'..name..suffix,493))
            end
            -- No tools-venv Python on PATH: it would hide the Auto regression.
            env.PATH=table.concat({badbin,tools,goodbin,vim.fs.dirname(manifest.node),deps..'/tools/node_modules/.bin',env.PATH},sep)
            env.DEBUGPY_LOG_DIR=runtime..'/debugpy-logs'
            vim.fn.writefile({'import sys','answer = 42','print("PY_AUTO_BEFORE", flush=True)',
              'answer += 0  # E2E_BREAKPOINT','print("PY_AUTO_OK", sys.executable, answer, flush=True)'},project..'/app.py')
          end})
        assert(uv.fs_copyfile(root..'/tests/e2e/python-auto-runtime.test.lua',e.dir..'/test.lua'))
        e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
        T.eq(vim.fn.isdirectory(e.project..'/.venv'),0)
        e:input(':edit app.py<CR>')
        e:wait('Python ready',function() return e:current_ft()=='python' and e:lua([[return vim.fn.exists(':DapPythonInfo')==2]]) end)
        local auto=e:lua([[return {selected=require('forge.python').resolve({vim.fn.getcwd()}),
          python=vim.fn.exepath('python'),python3=vim.fn.exepath('python3'),override=vim.env.FORGE_PYTHON_PATH or ''}]])
        info.auto=auto
        T.eq(auto.override,'');T.eq(key(auto.selected),key(info.good),'Auto PATH preference')
        e:lua([[require('dap').set_log_level('DEBUG')]])
        info.dap_log=e:lua([[return vim.fn.stdpath('cache')..'/dap.log']])
        e:input('4G<F9>')
        if case=='auto PATH' then
          launch(e);debugged(e,info);T.eq(adapter_count(e,info),1)
        elseif case=='explicit invalid SDK and recovery' then
          e:lua([[require('forge.tool_paths').save('python',...,'project',vim.fn.getcwd())]],{info.bad})
          launch(e)
          e:wait('invalid SDK diagnosed before adapter',function()
            for _,entry in ipairs(state(e).logs) do if entry.source=='DAP Python' and key(entry.message):find(key(info.bad),1,true) then return true end end
            return false
          end,6000)
          local failed=state(e);info.failed=failed
          T.eq(failed.session,false);T.eq(adapter_count(e,info),0);assert(not failed.mode.blocking)
          T.eq(key(e:lua([[return require('forge.python').resolve({vim.fn.getcwd()})]])),key(info.bad),'No silent SDK replacement')
          e:wait('native nonblocking notification',function() return e:lua([[for _,item in ipairs(require('fidget.notification').get_history()) do
            if item.message:find('Python SDK',1,true) then return true end end;return false]]) end)
          local detail=false
          for _,entry in ipairs(failed.logs) do if entry.source=='DAP Python' and entry.message:find('exit',1,true) then detail=true end end
          assert(detail,'Full native SDK failure must be logged')
          e:input('<F7>Go# STILL_EDITABLE<Esc>:write<CR>')
          e:wait('save after failed F5',function() return table.concat(vim.fn.readfile(e.project..'/app.py'),'\n'):find('# STILL_EDITABLE',1,true)~=nil end)
          e:lua([[require('forge.tool_paths').save('python',...,'project',vim.fn.getcwd())]],{info.good})
          launch(e);debugged(e,info);T.eq(adapter_count(e,info),1)
        else
          -- Hold the real probe completion, not its data/process, to exercise
          -- a project switch deterministically while launch is pending.
          e:lua([[local system=vim.system;local normalize=require('forge.dap.context').normalize_path;
            local expected=normalize(...);vim.system=function(argv,options,callback)
            if normalize(argv[1])==expected and argv[2]=='-I' then
              return system(argv,options,function(result)
                _G.forge_python_probe_result=result;_G.forge_python_probe_release=function() callback(result) end
              end)
            end;return system(argv,options,callback)
          end]],{info.good})
          launch(e)
          e:wait('real probe held',function() return e:lua('return _G.forge_python_probe_result~=nil') end,6000)
          T.eq(e:lua('return _G.forge_python_probe_result.code'),0)
          e:input('<F7>:cd nested<CR>')
          e:wait('other cwd',function() return key(e:lua('return vim.fn.getcwd()'))==key(e.project..'/nested') end)
          e:lua([[_G.forge_python_probe_release()]])
          e:wait('native DAP abort',function() return e:lua([[return vim.fn.execute('messages'):find('Run aborted',1,true)~=nil]]) end)
          T.eq(adapter_count(e,info),0);T.eq(state(e).session,false)
        end
        local observed=state(e);info.final=observed
        T.eq(observed.installs,0);assert(not observed.mode.blocking)
        for _,n in ipairs(observed.notifications) do
          assert(not n.message:find("adapter didn't respond",1,true),n.message)
          assert(n.level<vim.log.levels.ERROR or case=='explicit invalid SDK and recovery' and n.message:find('Python SDK',1,true),n.message)
        end
      end,debug.traceback)
      if e then
        info=info or {};info.ok=ok;info.error=not ok and tostring(err) or nil
        vim.fn.writefile({vim.json.encode(info)},e.dir..'/python-auto.json')
        if info.dap_log and vim.fn.filereadable(info.dap_log)==1 then uv.fs_copyfile(info.dap_log,e.dir..'/dap.log') end
        e:snapshot('python-auto-runtime');io.stdout:write('  artifacts: '..e.dir..'\n')
        local stopped,issue=pcall(e.stop,e,not ok and tostring(err) or nil)
        if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(issue) end
      end
      assert(ok,err)
    end)
  end
end
T.finish()
