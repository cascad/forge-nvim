-- spec: IDE-BOOT-33. Real editor, native processes, real venv; no SDK downloads.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local filter=vim.env.FORGE_TEST_ID
if filter and filter~='' and not (T.matches('IDE-BOOT-33',filter) or T.matches(filter,'IDE-BOOT-33')) then
  T.finish();return
end
local win=vim.fn.has('win32')==1
local function join(...) return vim.fs.joinpath(...) end
local function json(path,data)
  vim.fn.mkdir(vim.fs.dirname(path),'p')
  assert(vim.fn.writefile({vim.json.encode(data)},path)==0)
end
local function python_in(path) return join(path,win and 'Scripts/python.exe' or 'bin/python') end
local python=vim.fn.exepath(win and 'python' or 'python3')
assert(python~='','Native Python is required; prepare SDK explicitly')
local node_deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
local node_manifest=vim.json.decode(table.concat(vim.fn.readfile(node_deps..'/manifest.json'),'\n'))
local node=join(node_deps,node_manifest.node)
local bash=vim.fn.exepath('bash')
if win then
  local git=vim.fn.exepath('git')
  bash=join(vim.fs.dirname(vim.fs.dirname(git)),'bin/bash.exe')
end
assert(vim.fn.executable(node)==1 and vim.fn.executable(bash)==1,'Prepare native Node and Bash explicitly')
local function settings(project,tools) json(join(project,'.fride/tools.json'),{tools=tools}) end
local function check(name,prepare,fn)
  T.check('IDE-BOOT-33 '..name,function()
    local e
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=90000,prepare=function(project,env,runtime)
        -- No user settings leak into the private editor runtime.
        env.FORGE_PYTHON_PATH,env.FORGE_NODE_EXECUTABLE,env.FORGE_BASH_EXECUTABLE='','',''
        env.FORGE_JS_DEBUG_SERVER,env.FORGE_BASH_DEBUG_ADAPTER,env.FORGE_BATS_EXECUTABLE='','',''
        prepare(project,env,runtime)
      end})
      e:wait('editor ready',function() return e:lua('return _G.forge_e2e_observed') end,12000)
      fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local closed,why=pcall(e.stop,e,not ok and err or nil)
      if not closed then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
    end
    assert(ok,err)
  end)
end

check('project/user priority, real processes, spaces and logs',function(project,env)
  local venv=join(project,'venv with spaces')
  local result=vim.system({python,'-m','venv','--without-pip',venv},{text=true,timeout=30000}):wait()
  assert(result.code==0,result.stderr)
  local tools=join(project,'tools with spaces')
  vim.fn.mkdir(tools,'p')
  assert(vim.uv.fs_copyfile(node,join(tools,win and 'node.exe' or 'node')))
  if not win then assert(vim.uv.fs_chmod(join(tools,'node'),493)) end
  vim.fn.writefile({'console.log(JSON.stringify(process.argv.slice(2)))'},join(tools,'adapter.js'))
  vim.fn.writefile({[[require('fs').writeFileSync('node result.txt','NODE_TOOL_PATH_OK');]]},join(project,'run.js'))
  vim.fn.writefile({[[printf BASH_TOOL_PATH_OK > 'bash result.txt']]},join(project,'run.sh'))
  json(join(env.FORGE_E2E_CONFIG,'tools.json'),{tools={python=python,node=node,bash=bash}})
  settings(project,{python='venv with spaces/'..(win and 'Scripts/python.exe' or 'bin/python'),
    node='tools with spaces/'..(win and 'node.exe' or 'node'),bash=bash,
    ['js-debug-adapter']='tools with spaces/adapter.js',
    ['bash-debug-adapter']='tools with spaces/adapter.js',bats='tools with spaces/adapter.js'})
  env.FORGE_PYTHON_PATH=join(project,'missing legacy python')
end,function(e)
  local result=e:lua([[local p=require('forge.python').resolve({vim.fn.getcwd()})
    local r=vim.system({p,'-c','import sys; print(sys.prefix)'},{text=true}):wait(5000)
    return {path=p,code=r.code,output=r.stdout} ]])
  T.eq(result.code,0);assert(result.path:find('venv with spaces',1,true));assert(result.output:find('venv with spaces',1,true))
  e:input(':edit run.js<CR>');e:wait('JS file',function() return e:current_ft()=='javascript' end)
  e:lua([[_G.path_task=require('forge.node').run_file()]])
  e:wait('NodeRunFile native result',function() return vim.fn.filereadable(e.project..'/node result.txt')==1 end,10000)
  T.eq(table.concat(vim.fn.readfile(e.project..'/node result.txt')),'NODE_TOOL_PATH_OK')
  e:lua([[require('ide.controls').focus_code();vim.cmd.edit('run.sh');_G.path_task=require('forge.bash').run_file()]])
  e:wait('BashRunFile native result',function() return vim.fn.filereadable(e.project..'/bash result.txt')==1 end,10000)
  T.eq(table.concat(vim.fn.readfile(e.project..'/bash result.txt')),'BASH_TOOL_PATH_OK')
  local args=e:lua([[local node=require('forge.node');local script=node.debug_server()
    local result=vim.system({node.executable(),script,'one argument','two'},{text=true}):wait(5000)
    assert(result.code==0,result.stderr)
    assert(require('forge.bash_debug').entrypoint()==script)
    return vim.json.decode(result.stdout) ]])
  T.eq(args,{'one argument','two'})
  e:input(':ForgeToolPaths<CR>');e:wait('tool paths in IDE logs',function() return e:current_ft()=='forge-logs' end)
  local body=e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]])
  assert(body:find('project:',1,true) and body:find('venv with spaces',1,true),body)
end)

check('user paths, legacy overrides and active venv',function(project,env)
  json(join(env.FORGE_E2E_CONFIG,'tools.json'),{tools={python=python}})
  env.FORGE_NODE_EXECUTABLE=node
  env.FORGE_BASH_EXECUTABLE=bash
end,function(e)
  T.eq(e:lua([[return require('forge.python').resolve({vim.fn.getcwd()})]]),vim.fs.normalize(python))
  T.eq(e:lua([[return require('forge.node').executable()]]),vim.fs.normalize(node))
  T.eq(vim.fs.normalize(e:lua([[return require('forge.bash_host').executable()]])),vim.fs.normalize(bash))
  e:lua([[local p=require('forge.python').resolve();vim.g.forge_python_path=p
    vim.env.FORGE_PYTHON_PATH='missing-env-python';vim.fn.delete(vim.fn.stdpath('config')..'/tools.json')]])
  T.eq(e:lua([[return require('forge.python').resolve()]]),vim.fs.normalize(python))
  local invalid=e:lua([[vim.g.forge_python_path=nil
    local ok,err=pcall(require('forge.python').resolve);return {ok=ok,error=tostring(err)}]])
  T.eq(invalid.ok,false);assert(invalid.error:find('$FORGE_PYTHON_PATH',1,true),invalid.error)
  e:lua([[vim.env.FORGE_PYTHON_PATH=''
    vim.env.VIRTUAL_ENV=vim.fn.getcwd()..'/active venv'
    local p=vim.system({...,'-m','venv','--without-pip',vim.env.VIRTUAL_ENV},{text=true}):wait(30000)
    assert(p.code==0,p.stderr) ]],{python})
  local resolved=e:lua([[return require('forge.python').resolve()]])
  assert(resolved:find('active venv',1,true),resolved)
end)

check('invalid paths and malformed config never fall back',function(project,env)
  json(join(env.FORGE_E2E_CONFIG,'tools.json'),{tools={python=python,node=node,bash=bash}})
  settings(project,{python='./missing python',node='./missing node',bash='./missing bash'})
end,function(e)
  local result=e:lua([[local out={}
    for _,module in ipairs({'python','node','bash_host'}) do
      local m=require('forge.'..module);local ok,err=pcall(m.resolve or m.executable)
      out[#out+1]={ok=ok,error=tostring(err)}
    end;return out ]])
  for _,entry in ipairs(result) do T.eq(entry.ok,false);assert(entry.error:find('project:',1,true),entry.error) end
  e:lua([[vim.fn.writefile({'{broken json'},vim.fn.getcwd()..'/.fride/tools.json')]])
  local bad=e:lua([[local ok,err=pcall(require('forge.node').executable);return {ok=ok,error=tostring(err)}]])
  T.eq(bad.ok,false);assert(bad.error:find('tools.json',1,true))
  e:input(':ForgeToolPaths<CR>');e:wait('invalid selection report',function() return e:current_ft()=='forge-logs' end)
  assert(e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('ERROR:',1,true))
end)

check('config refresh and project isolation',function(project,env)
  json(join(env.FORGE_E2E_CONFIG,'tools.json'),{tools={python=python,node=node}})
  settings(project,{node='./missing node'})
  vim.fn.mkdir(join(project,'other/.git'),'p')
  vim.fn.writefile({'another project'},join(project,'other/file.txt'))
  settings(join(project,'other'),{node=node})
end,function(e)
  local initial=e:lua([[return pcall(require('forge.node').executable)]])
  T.eq(initial,false)
  e:lua([[vim.cmd.cd(vim.fn.getcwd()..'/other')]])
  T.eq(e:lua([[return require('forge.node').executable()]]),vim.fs.normalize(node))
  e:lua([[vim.cmd.cd('..');vim.fn.writefile({vim.json.encode({tools={node=...}})},vim.fn.getcwd()..'/.fride/tools.json')]],{node})
  T.eq(e:lua([[return require('forge.node').executable()]]),vim.fs.normalize(node))
  e:lua([[vim.cmd.edit('other/file.txt');vim.cmd('ForgeToolPaths');vim.cmd('ForgeToolPaths')]])
  local project=e:lua([[for _,entry in ipairs(require('forge.tool_paths').report()) do
    if entry.id=='node' then return entry.root end end]])
  assert(project:gsub('\\','/'):sub(-6)=='/other',project)
end)

T.finish()
