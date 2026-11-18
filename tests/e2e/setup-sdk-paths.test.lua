-- spec: IDE-BOOT-39. Native SDKs and Mason processes, without installs/downloads.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
if vim.env.FORGE_TEST_ID and not T.matches('IDE-BOOT-39',vim.env.FORGE_TEST_ID) then T.finish();return end
local win=vim.fn.has('win32')==1
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local python=vim.fn.exepath(win and 'python' or 'python3')
local deps=vim.env.FORGE_E2E_DEPS or root..'/.tests/editor-deps'
local node_deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
local node=node_deps..'/'..read(node_deps..'/manifest.json').node
local function key(path) path=vim.fs.normalize(path):gsub('\\','/');return win and path:lower() or path end
local cases={'selected','none','unrelated','invalid','missing-npm','unsupported','late'}
local only=vim.env.FORGE_SETUP_SDK_CASE
assert(not only or vim.tbl_contains(cases,only),'Unknown FORGE_SETUP_SDK_CASE')
for _,case in ipairs(cases) do
  if not only or only==case then
  T.check('IDE-BOOT-39 native setup '..case,function()
    local base=root..'/.tests/setup-sdk/'..tostring(vim.uv.hrtime())..' space'
    vim.fn.mkdir(base..'/project/.git','p');vim.fn.mkdir(base..'/project/.fride','p')
    local tools={python=python,node=node}
    local venv=base..'/venv with spaces'
    if case=='selected' then
      local result=vim.system({python,'-m','venv','--without-pip',venv},{text=true,timeout=30000}):wait()
      assert(result.code==0,result.stderr)
      tools.python=venv..(win and '/Scripts/python.exe' or '/bin/python')
      assert(vim.uv.fs_symlink(vim.fs.dirname(node),base..'/Node with spaces',win and {junction=true,dir=true} or {dir=true}))
      tools.node=base..'/Node with spaces/'..(win and 'node.exe' or 'node')
    elseif case=='none' then tools={}
    elseif case=='invalid' or case=='unrelated' then tools.python=base..'/missing python';tools.node=base..'/missing node'
    elseif case=='missing-npm' then
      vim.fn.mkdir(base..'/node-only','p');tools.node=base..'/node-only/'..(win and 'node.exe' or 'node')
      assert(vim.uv.fs_copyfile(node,tools.node));if not win then assert(vim.uv.fs_chmod(tools.node,493)) end
    elseif case=='unsupported' then
      vim.fn.mkdir(base..'/custom-python','p');tools.python=base..'/custom-python/alternate-python'..(win and '.exe' or '')
      assert(vim.uv.fs_copyfile(python,tools.python));if not win then assert(vim.uv.fs_chmod(tools.python,493)) end
    end
    vim.fn.writefile({vim.json.encode({tools=tools})},base..'/project/.fride/tools.json')
    local result=vim.system({vim.v.progpath,'-u','NONE','-i','NONE','-l',root..'/tests/diagnostics/setup-sdk-actor.lua',root,base,case},
      {cwd=base..'/project',text=true,timeout=45000,env={NVIM_APPNAME='fride-sdk-fixture',XDG_CONFIG_HOME=base..'/config',
        XDG_DATA_HOME=base..'/data',XDG_STATE_HOME=base..'/state',XDG_CACHE_HOME=base..'/cache',
        FORGE_NVIM_COMPONENTS=case=='unrelated' and 'core' or 'core,python,node',FORGE_E2E_DEPS=deps,
        FORGE_PYTHON_PATH='',FORGE_NODE_EXECUTABLE='',NVIM_LOG_FILE=base..'/nvim.log'}}):wait()
    vim.fn.writefile(vim.split((result.stdout or '')..(result.stderr or ''),'\n'),base..'/process.log')
    local report=read(base..'/result.json')
    local expected=case=='selected' or case=='none' or case=='unrelated'
    T.eq(result.code,expected and 0 or 1,report.error);T.eq(result.signal,0);T.eq(report.ok,expected)
    if case=='selected' then
      T.eq(key(report.python.prefix),key(venv))
      T.eq(key(assert(vim.uv.fs_realpath(report.python.executable))),key(assert(vim.uv.fs_realpath(tools.python))))
      assert(report.node.version:match('^v%d+'))
      T.eq(key(assert(vim.uv.fs_realpath(report.node.executable))),key(assert(vim.uv.fs_realpath(node))))
      assert(report.selection.selected.python.source:find('project:',1,true))
      assert(report.frozen:find('venv with spaces',1,true) and report.frozen:find('Node with spaces',1,true))
    else
      assert(report.path_unchanged)
      if not expected then
        assert(report.error:find(case=='late' and 'before Mason' or 'project:',1,true),report.error)
        T.eq(report.mason_loaded,case=='late')
      end
    end
    io.stdout:write('  artifacts: '..base..'\n')
  end)
  end
end
T.finish()
