-- Настоящий Python project venv; подготовка offline до запуска редактора.
local M={}
local uv=vim.uv
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function copy(from,to)
  vim.fn.mkdir(to,'p')
  for name,kind in vim.fs.dir(from) do
    if kind=='directory' then copy(from..'/'..name,to..'/'..name)
    elseif kind=='file' then assert(uv.fs_copyfile(from..'/'..name,to..'/'..name))
    else error('Неожиданный тип fixture '..name) end
  end
end
local function run(command,env)
  local r=vim.system(command,{text=true,env=env,clear_env=true}):wait()
  assert(r.code==0,r.stderr..'\n'..r.stdout);return r.stdout
end
function M.start(root,on_create)
  if vim.env.FORGE_PYTHON_DAP_LEGACY then assert(vim.env.FORGE_PYTHON_CASE=='pytest debug','Legacy DAP replay только для pytest debug') end
  local deps=vim.env.FORGE_E2E_PYTHON_DEPS or root..'/.tests/python-deps'
  local manifest=read(deps..'/manifest.json')
  for path,hash in pairs(manifest.files) do
    local f=assert(io.open(deps..'/'..path,'rb'));local raw=f:read('*a');f:close()
    assert(vim.fn.sha256(raw)==hash,'Изменены Python deps: '..path)
  end
  local win=vim.fn.has('win32')==1
  local bin=win and '/Scripts' or '/bin'
  local tools=vim.fn.fnamemodify(deps..'/'..manifest.tools_python,':h')
  local node=vim.fn.fnamemodify(manifest.node,':h')
  local sep=win and ';' or ':'
  local path={node,deps..'/tools/node_modules/.bin',tools}
  for _,dir in ipairs(vim.split(vim.env.PATH,sep,{plain=true})) do
    -- Пользовательские pyright/ruff не должны скрыть ошибки prepared tools.
    local foreign=false
    for _,name in ipairs(win and {'pyright-langserver.exe','ruff.exe'} or {'pyright-langserver','ruff'}) do
      if vim.fn.filereadable(dir..'/'..name)==1 then foreign=true end
    end
    if not foreign then path[#path+1]=dir end
  end
  local project_python,prepared_output
  local e=require('editor').start(root,{timeout=45000,site=deps..'/site',
    snapshot_ignore={['.venv']=true,__pycache__=true,['.pytest_cache']=true},
    env={PATH=table.concat(path,sep),VIRTUAL_ENV='',CONDA_PREFIX='',PYTHONHOME='',PYTHONPATH='',
      PYTHONNOUSERSITE='1',PYTHONIOENCODING='utf-8',PYTEST_DISABLE_PLUGIN_AUTOLOAD='1',PYTEST_ADDOPTS='',PYTEST_PLUGINS='',
      PIP_NO_INDEX='1',PIP_DISABLE_PIP_VERSION_CHECK='1',PIP_CONFIG_FILE=win and 'NUL' or '/dev/null',
      FORGE_PYTHON_PATH='',FORGE_DEBUGPY_ADAPTER='',FORGE_DEBUGPY_PYTHON='',
      FORGE_NODE_EXECUTABLE=manifest.node,FORGE_NODE_TOOLS=deps..'/tools'},
    prepare=function(project,env,runtime)
      if vim.env.FORGE_PYTHON_ADAPTER_GROUP_SOURCE then
        assert(vim.env.FORGE_E2E_CONFIG_SOURCE,'Root replay requires original config metadata')
        local spec
        for _,item in ipairs(read(root..'/nvim_forge/patches/plugins.json').neotest.extra) do
          if item.file=='lua/neotest/adapters/init.lua' then spec=item end end
        assert(spec,'Missing root companion declaration')
        local source=vim.env.FORGE_PYTHON_ADAPTER_GROUP_SOURCE
        local f=assert(io.open(source,'rb'));local raw=f:read('*a');f:close()
        assert(vim.fn.sha256((raw:gsub('\r\n','\n')))==spec.before_sha256,'Replay must be exact upstream source')
        local data=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')
        assert(uv.fs_copyfile(source,data..'/lazy/neotest/'..spec.file))
      end
      if vim.env.FORGE_PYTHON_DAP_LEGACY then
        local patch=read(root..'/nvim_forge/patches/plugins.json')['nvim-dap']
        local data=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')
        local file=data..'/lazy/nvim-dap/'..patch.file
        local f=assert(io.open(file,'rb'));local raw=f:read('*a');f:close();assert(vim.fn.sha256(raw)==patch.after_sha256)
        local a,b=assert(raw:find(patch.after,1,true));raw=raw:sub(1,a-1)..patch.before..raw:sub(b+1)
        assert(vim.fn.sha256(raw)==patch.before_sha256);f=assert(io.open(file,'wb'));f:write(raw);f:close()
      end
      for _,key in ipairs({'VIRTUAL_ENV','CONDA_PREFIX','PYTHONHOME','PYTHONPATH','FORGE_PYTHON_PATH','FORGE_DEBUGPY_ADAPTER','FORGE_DEBUGPY_PYTHON'}) do env[key]=nil end
      local dir=project..'/Python project ü';copy(root..'/tests/e2e/fixtures/python-language/project',dir)
      env.PYTHONPYCACHEPREFIX=runtime..'/tmp/pycache'
      env.DEBUGPY_LOG_DIR=runtime..'/debugpy-logs'
      vim.fn.writefile({'.venv/','__pycache__/','.pytest_cache/','neighbor-ran.txt','python-cwd.txt'},dir..'/.gitignore')
      vim.fn.mkdir(dir..'/.vscode','p')
      project_python=dir..'/.venv'..bin..(win and '/python.exe' or '/python')
      prepared_output=run({manifest.host_python,'-m','venv',dir..'/.venv'},env)
      prepared_output=prepared_output..run({project_python,'-m','pip','install','--no-index','--find-links',deps..'/wheels',
        '--require-hashes','-r',root..'/tests/e2e/python-tools/requirements.lock'},env)
      prepared_output=prepared_output..run({project_python,'-m','pip','install','--no-index','--no-deps',
        deps..'/dependency-wheels/forge_fixture_dependency-0.1.0-py3-none-any.whl'},env)
      prepared_output=prepared_output..run({project_python,'-c',"import sys,forge_fixture_dependency as d;assert d.calculate_answer(21)==42;print(sys.prefix)"},env)
    end})
  if on_create then on_create(e) end
  e.python_project=(e.project..'/Python project ü'):gsub('\\','/')
  e.project_python=project_python
  e.tools_python=deps..'/'..manifest.tools_python
  e.log_cache=e:lua([[return vim.fn.stdpath('cache')]])
  e.log_state=e:lua([[return vim.fn.stdpath('log')]])
  e.log_lsp=e:lua([[return vim.lsp.log.get_filename()]])
  assert(uv.fs_copyfile(e:lua([[return vim.fn.stdpath('data')..'/lazy/neotest/lua/neotest/adapters/init.lua']]),e.dir..'/neotest-adapters-source.lua'))
  assert(uv.fs_copyfile(e:lua([[return vim.fn.stdpath('data')..'/lazy/nvim-dap/lua/dap/session.lua']]),e.dir..'/dap-session-source.lua'))
  vim.fn.writefile(vim.split(prepared_output,'\n',{plain=true}),e.dir..'/venv-prepare.txt')
  vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/python-dependencies.json')
  vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/python-tools/requirements.lock'),e.dir..'/requirements.lock')
  e:input(':cd '..vim.fn.fnameescape(e.python_project)..'<CR>')
  e:lua([[vim.lsp.log.set_level('debug')]])
  return e
end
return M
