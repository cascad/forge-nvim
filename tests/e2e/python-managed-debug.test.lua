-- spec: IDE-PY-2. Настоящий adapter в отдельной managed среде, project без debugpy.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local uv=vim.uv
local win=vim.fn.has('win32')==1
local deps=vim.env.FORGE_E2E_PYTHON_DEPS or root..'/.tests/python-deps'
local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
local debugpy_wheel,dependency_wheel
for relative,expected in pairs(manifest.files) do
  local path=deps..'/'..relative
  local file=assert(io.open(path,'rb'));local raw=file:read('*a');file:close()
  T.eq(vim.fn.sha256(raw),expected,'Подготовленные Python deps: '..relative)
  local name=relative:gsub('\\','/')
  if name:match('^wheels/debugpy%-') then assert(not debugpy_wheel);debugpy_wheel=path end
  if name:match('^dependency%-wheels/forge_fixture_dependency%-') then assert(not dependency_wheel);dependency_wheel=path end
end
assert(debugpy_wheel and dependency_wheel,'Нужны prepared debugpy и fixture wheels')
local function binary(env,name)
  return env..(win and '/Scripts/' or '/bin/')..name..(win and '.exe' or '')
end
local function same(a,b)
  local function key(path)
    -- Python выбирает venv по пути запуска; realpath склеивает разные env.
    local value=vim.fs.normalize(path):gsub('\\','/')
    return win and value:lower() or value
  end
  return key(a)==key(b)
end
local function output(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then
      vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local cases={
  {name='managed launcher',kind='launcher'},
  {name='managed Python без launcher',kind='python'},
  {name='global adapter override при другом env override',kind='adapter_override'},
  {name='global Python override при другом env override',kind='python_override'},
}
for _,case in ipairs(cases) do
  if not vim.env.FORGE_PY_MANAGED_CASE or case.name:find(vim.env.FORGE_PY_MANAGED_CASE,1,true) then
    T.check('IDE-PY-2 '..case.name,function()
      local e,info
      local setup=root..'/.tests/python-managed-setup/'..tostring(uv.hrtime())
      vim.fn.mkdir(setup,'p')
      local commands={}
      local function run(argv,env,cwd)
        local result=vim.system(argv,{env=env,clear_env=true,cwd=cwd,text=true,timeout=60000}):wait()
        commands[#commands+1]={argv=argv,result=result}
        vim.fn.writefile({vim.json.encode(commands)},setup..'/commands.json')
        assert(result.code==0 and result.signal==0,(result.stderr or '')..'\n'..(result.stdout or '')..'\nsetup: '..setup)
      end
      local ok,err=xpcall(function()
        local path={}
        for _,dir in ipairs(vim.split(vim.env.PATH,win and ';' or ':',{plain=true})) do
          local found=false
          for _,suffix in ipairs({'','.exe','.cmd','.bat'}) do
            if vim.fn.filereadable(dir..'/debugpy-adapter'..suffix)==1 then found=true end
          end
          if not found then path[#path+1]=dir end
        end
        e=require('editor').start(root,{timeout=90000,site=deps..'/site',
          snapshot_ignore={['.venv']=true,__pycache__=true},
          env={PATH=table.concat(path,win and ';' or ':'),
            VIRTUAL_ENV='',CONDA_PREFIX='',PYTHONHOME='',PYTHONPATH='',PYTHONNOUSERSITE='1',
            PYTHONIOENCODING='utf-8',PIP_NO_INDEX='1',PIP_DISABLE_PIP_VERSION_CHECK='1',
            PIP_CONFIG_FILE=win and 'NUL' or '/dev/null',
            FORGE_PYTHON_PATH='',FORGE_DEBUGPY_ADAPTER='',FORGE_DEBUGPY_PYTHON=''},
          prepare=function(project,env,runtime)
            local app=project..'/Managed Python project ü'
            vim.fn.mkdir(app,'p')
            assert(uv.fs_copyfile(root..'/tests/e2e/fixtures/python-managed/app.py',app..'/app.py'))
            vim.fn.writefile({'[project]','name = "managed-debug-fixture"','version = "0.0.0"'},app..'/pyproject.toml')
            env.PYTHONPYCACHEPREFIX=runtime..'/tmp/pycache'
            env.DEBUGPY_LOG_DIR=runtime..'/debugpy-logs'
            for _,key in ipairs({'VIRTUAL_ENV','CONDA_PREFIX','PYTHONHOME','PYTHONPATH',
              'FORGE_PYTHON_PATH','FORGE_DEBUGPY_ADAPTER','FORGE_DEBUGPY_PYTHON'}) do env[key]=nil end
            local managed=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')..'/mason/packages/debugpy/venv'
            local alternate=runtime..'/explicit adapter ü'
            info={case=case.kind,app=app,managed=managed,alternate=alternate,
              project_python=binary(app..'/.venv','python'),managed_python=binary(managed,'python'),
              managed_adapter=binary(managed,'debugpy-adapter'),alternate_python=binary(alternate,'python'),
              alternate_adapter=binary(alternate,'debugpy-adapter')}
            run({manifest.host_python,'-m','venv',app..'/.venv'},env,project)
            run({info.project_python,'-m','pip','install','--no-index','--no-deps',dependency_wheel},env,project)
            run({info.project_python,'-c',"import importlib.util;assert importlib.util.find_spec('debugpy') is None;from forge_fixture_dependency import calculate_answer;assert calculate_answer(21)==42"},env,project)
            run({manifest.host_python,'-m','venv',managed},env,project)
            run({info.managed_python,'-m','pip','install','--no-index','--no-deps',debugpy_wheel},env,project)
            run({info.managed_python,'-c','import debugpy;print(debugpy.__file__)'},env,project)
            if case.kind:find('override',1,true) then
              run({manifest.host_python,'-m','venv',alternate},env,project)
              run({info.alternate_python,'-m','pip','install','--no-index','--no-deps',debugpy_wheel},env,project)
            end
            if case.kind=='python' or case.kind=='python_override' then assert(uv.fs_unlink(info.managed_adapter)) end
            if case.kind=='python_override' then assert(uv.fs_unlink(info.alternate_adapter));env.FORGE_DEBUGPY_PYTHON=info.managed_python end
            if case.kind=='adapter_override' then env.FORGE_DEBUGPY_ADAPTER=info.managed_adapter end
          end})
        assert(uv.fs_copyfile(root..'/tests/e2e/python-managed-debug.test.lua',e.dir..'/python-managed-debug.test.lua'))
        assert(uv.fs_copyfile(root..'/tests/e2e/fixtures/python-managed/app.py',e.dir..'/managed-app.py'))
        e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
        e:lua([[vim.lsp.enable('pyright',false);vim.lsp.enable('ruff',false)]])
        if case.kind=='adapter_override' then e:lua('vim.g.forge_debugpy_adapter=...',{info.alternate_adapter}) end
        if case.kind=='python_override' then e:lua('vim.g.forge_debugpy_python=...',{info.alternate_python}) end
        e:input(':cd '..vim.fn.fnameescape(info.app)..'<CR>:edit app.py<CR>')
        e:wait('Python config ready',function() return e:current_ft()=='python' and e:lua([[return vim.fn.exists(':DapPythonInfo')==2]]) end,10000)
        local before=e:lua([[return {path=vim.fn.exepath('debugpy-adapter'),installs=vim.g.forge_e2e_installs,
          spawns=_G.forge_e2e_spawns,project_adapter=vim.fn.filereadable(...)}]],{binary(info.app..'/.venv','debugpy-adapter')})
        T.eq(before.path,'');T.eq(before.project_adapter,0);T.eq(before.installs,0)
        for _,spawn in ipairs(before.spawns) do
          for _,key in ipairs({'managed_python','managed_adapter','alternate_python','alternate_adapter'}) do
            assert(not same(spawn.cmd,info[key]),'Adapter запущен до F5')
          end
        end
        info.before=before
        -- Сохранить путь до возможного failed launch/hit-enter; cleanup не
        -- зависит от нового Lua RPC, когда adapter не смог стартовать.
        info.dap_log=e:lua([[require('dap').set_log_level('DEBUG');return vim.fn.stdpath('cache')..'/dap.log']])
        e:input(':DapPythonInfo<CR>gg/E2E_BREAKPOINT<CR><F9><F5>')
        e:wait('DAP picker',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
        e:input('Current Python file')
        e:wait('Current Python file selected',function() return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.ordinal:find('Current Python file',1,true)
          and not v.ordinal:find('Current Python file (args)',1,true) or false]]) end)
        e:input('<CR>')
        e:wait('actual Python breakpoint',function() return e:lua([[local s=require('dap').session();return s and s.stopped_thread_id~=nil and s.current_frame~=nil or false]]) end,30000)
        e:wait('actual project stdout',function()
          local text=output(e,'dap-repl');return text:find('MANAGED_VALUE 42',1,true) and text:find('MANAGED_PROJECT_VENV True',1,true)
        end,10000)
        local spawns=e:lua('return _G.forge_e2e_spawns')
        local expected=case.kind=='launcher' and info.managed_adapter or case.kind=='python' and info.managed_python
          or case.kind=='adapter_override' and info.alternate_adapter or info.alternate_python
        local selected={}
        for _,spawn in ipairs(spawns) do if same(spawn.cmd,expected) then selected[#selected+1]=spawn end end
        T.eq(#selected,1,'Actual adapter spawn должен использовать выбранную среду')
        if case.kind=='python' or case.kind=='python_override' then T.eq(selected[1].args,{'-m','debugpy.adapter'}) end
        info.actual_adapter=selected[1];info.stdout_before=output(e,'dap-repl')
        e:input('<F7>gg/\\<lt>answer\\><CR>')
        e:wait('answer under cursor',function() return e:current_ft()=='python' and e:lua([[return vim.fn.expand('<cword>')]])=='answer' end)
        e:input(' de');e:wait('actual eval42',function() return output(e,'dap-float'):find('42',1,true)~=nil end)
        e:input('q<F7><F5>')
        e:wait('session and output complete',function() return e:lua([[return require('dap').session()==nil]])
          and output(e,'dap-repl'):find('MANAGED_AFTER 42',1,true)~=nil end,30000)
        info.stdout_after=output(e,'dap-repl')
        T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
        for _,notice in ipairs(e.rpc.notifications) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
      end,debug.traceback)
      if e then
        info=info or {};info.ok=ok;info.error=not ok and tostring(err) or nil
        vim.fn.writefile({vim.json.encode(info)},e.dir..'/managed-python.json')
        assert(uv.fs_copyfile(setup..'/commands.json',e.dir..'/venv-commands.json'))
        if info.dap_log and vim.fn.filereadable(info.dap_log)==1 then assert(uv.fs_copyfile(info.dap_log,e.dir..'/dap.log')) end
        e:snapshot('managed-python');io.stdout:write('  artifacts: '..e.dir..'; setup: '..setup..'\n')
        local stopped,issue=pcall(e.stop,e,not ok and tostring(err) or nil)
        if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(issue) end
      else io.stdout:write('  setup: '..setup..'\n') end
      assert(ok,err)
    end)
  end
end
T.finish()
