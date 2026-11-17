-- spec: IDE-BOOT-38. Real menus, venv/native runtimes, native project restart.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
if vim.env.FORGE_TEST_ID and not T.matches('IDE-BOOT-38',vim.env.FORGE_TEST_ID) then T.finish();return end
local win=vim.fn.has('win32')==1
local python=vim.fn.exepath(win and 'python' or 'python3')
local deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local node=deps..'/'..read(deps..'/manifest.json').node
assert(python~='' and vim.fn.executable(node)==1,'Prepare native Python/Node test dependencies explicitly')
local function write(path,data)
  vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile({vim.json.encode(data)},path)==0)
end
local function normalized(path)
  path=vim.fs.normalize(path):gsub('\\','/');return win and path:lower() or path
end
local function equal_path(actual,expected) T.eq(normalized(actual),normalized(expected)) end
local function venv(project)
  local path=project..'/venv with spaces'
  local result=vim.system({python,'-m','venv','--without-pip',path},{text=true,timeout=30000}):wait()
  assert(result.code==0,result.stderr);return path
end
local function prepare(project,env,runtime)
  env.FORGE_PYTHON_PATH='';env.FORGE_NODE_EXECUTABLE='';env.VIRTUAL_ENV='';env.CONDA_PREFIX=''
  env.FRIDE_SDK_BASE=nil;env.FRIDE_SDK_PROJECT=nil
  assert(vim.uv.fs_symlink(vim.fs.dirname(node),runtime..'/Node SDK with spaces',win and {junction=true,dir=true} or {dir=true}))
  write(env.FORGE_E2E_CONFIG..'/tools.json',{tools={python=python,node=node},metadata={keep='USER_METADATA'}})
end
local function check(name,fn)
  if vim.env.FORGE_RUNTIME_SDK_CASE and not name:find(vim.env.FORGE_RUNTIME_SDK_CASE,1,true) then return end
  T.check('IDE-BOOT-38 '..name,fn)
end
local function select(e,label)
  e:wait('SDK picker',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' and e:current_ft()=='TelescopePrompt'
    and e:lua('return vim.api.nvim_get_current_buf()')~=e.sdk_prompt end,30000)
  e:input(label)
  e:wait('choice '..label,function() return e:lua([[local entry=require('telescope.actions.state').get_selected_entry()
    return entry and entry.ordinal:find(...,1,true)~=nil]],{label}) end)
  e.sdk_prompt=e:lua('return vim.api.nvim_get_current_buf()');e:input('<CR>')
end
local function finish(e,ok,err)
  if e then
    e:snapshot('runtime-sdk');io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,why=pcall(e.stop,e,not ok and err or nil);if not stopped then ok=false;err=tostring(err)..'\n'..tostring(why) end
  end
  assert(ok,err)
end
check('common menu settings reset cancel errors preserve native venv and metadata',function()
  local e
  local ok,err=xpcall(function()
    e=require('editor').start(root,{timeout=180000,snapshot_ignore={['venv with spaces']=true},prepare=function(project,env,runtime)
      prepare(project,env,runtime);env.VIRTUAL_ENV=venv(project)
      write(project..'/.fride/tools.json',{tools={unrelated='keep'},metadata={keep='PROJECT_METADATA'}})
    end})
    e:wait('ready',function() return e:lua('return _G.forge_e2e_observed') end,12000)
    assert(e:lua([[for _,spawn in ipairs(_G.forge_e2e_spawns) do
      local name=vim.fs.basename(spawn.cmd):lower();assert(not name:match('^python') and not name:match('^node'),'Runtime probe at startup') end;return true]]))
    local original=e:lua([[return {PATH=vim.env.PATH,VIRTUAL_ENV=vim.env.VIRTUAL_ENV,CONDA_PREFIX=vim.env.CONDA_PREFIX,pid=vim.uv.os_getpid()}]])
    e:input(' lS');select(e,'python');select(e,'project');select(e,'venv with spaces');select(e,'Сохранить для следующих')
    local project=e.project..'/.fride/tools.json'
    local selected=e.project..'/venv with spaces/'..(win and 'Scripts/python.exe' or 'bin/python')
    e:wait('project Python saved',function() return read(project).tools.python~=nil end)
    equal_path(read(project).tools.python,selected)
    T.eq(read(project).tools.unrelated,'keep');T.eq(read(project).metadata.keep,'PROJECT_METADATA')
    local actual=e:lua([[local p=require('forge.python').resolve({vim.fn.getcwd()})
      local r=vim.system({p,'-I','-B','-c','import sys,json;print(json.dumps({"prefix":sys.prefix,"executable":sys.executable}))'},{text=true}):wait(5000)
      assert(r.code==0,r.stderr);return vim.json.decode(r.stdout)]])
    equal_path(actual.prefix,e.project..'/venv with spaces');equal_path(actual.executable,selected)
    write(e.dir..'/python-runtime.json',actual)
    e:input(':ForgeSdk python project<CR>');select(e,'Сбросить выбор');select(e,'Сохранить для следующих')
    e:wait('project reset',function() return read(project).tools.python==nil end)
    equal_path(e:lua([[return require('forge.python').resolve({vim.fn.getcwd()})]]),python)
    T.eq(read(project).metadata.keep,'PROJECT_METADATA')
    e:input(':ForgeSdk node user<CR>');select(e,'Указать путь')
    e:wait('manual Node input',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
    e:input(e.runtime..'/Node SDK with spaces<CR>');select(e,'Сохранить для следующих')
    local user=e:lua([[return vim.fn.stdpath('config')..'/tools.json']])
    local alias=e.runtime..'/Node SDK with spaces/'..(win and 'node.exe' or 'node')
    e:wait('user Node saved',function() return normalized(read(user).tools.node)==normalized(alias) end)
    T.eq(read(user).metadata.keep,'USER_METADATA');equal_path(read(user).tools.python,python)
    local result=e:lua([[local n=require('forge.node').executable()
      local r=vim.system({n,'--version'},{text=true}):wait(5000);assert(r.code==0,r.stderr);return {path=n,version=vim.trim(r.stdout)}]])
    equal_path(result.path,alias);assert(result.version:match('^v%d+'))
    write(e.dir..'/node-runtime.json',result)
    local saved=table.concat(vim.fn.readfile(user),'\n')
    e:input(':ForgeSdk node user<CR>');e:wait('cancel menu',function() return e:current_ft()=='TelescopePrompt' end,30000)
    e:input('<Esc><Esc>');e:wait('menu cancelled',function() return e:current_ft()~='TelescopePrompt' end)
    T.eq(table.concat(vim.fn.readfile(user),'\n'),saved)
    e:input(':ForgeSdk node user<CR>');select(e,'Указать путь')
    e:wait('invalid input',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
    e:input(e.runtime..'/missing SDK<CR>')
    e:wait('invalid error',function() for _,n in ipairs(e.rpc.notifications) do if n.message:find('SDK executable not found',1,true) then return true end end end)
    if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>') end
    T.eq(table.concat(vim.fn.readfile(user),'\n'),saved)
    local corrupt=e:lua([[local file=vim.fn.stdpath('config')..'/tools.json';local saved=vim.fn.readfile(file)
      vim.fn.writefile({'{broken'},file);local ok,err=pcall(require('forge.runtime_sdk').save,'node','auto','user')
      assert(not ok and tostring(err):find('user:',1,true));assert(vim.fn.readfile(file)[1]=='{broken')
      vim.fn.writefile(saved,file);return true]])
    assert(corrupt)
    -- Removing the user Python choice restores the existing active/project venv rules.
    e:lua([[require('forge.runtime_sdk').save('python','auto','user')]])
    equal_path(e:lua([[return require('forge.python').resolve({vim.fn.getcwd()})]]),selected)
    local final=e:lua([[return {PATH=vim.env.PATH,VIRTUAL_ENV=vim.env.VIRTUAL_ENV,CONDA_PREFIX=vim.env.CONDA_PREFIX,pid=vim.uv.os_getpid()}]])
    T.eq(final,original);T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
  end,debug.traceback)
  finish(e,ok,err)
end)
check('native TUI Python Node apply restores session and reaches native workflows',function()
  local tui,report
  local ok,err=xpcall(function()
    tui=require('session_tui').start(root,{timeout=180000,snapshot_ignore={['venv with spaces']=true},prepare=function(project,env,runtime)
      prepare(project,env,runtime);venv(project..'/Project A ü')
      assert(vim.fn.writefile({[[require('fs').writeFileSync('node-run.json',JSON.stringify({executable:process.execPath,version:process.version}))]]},project..'/Project A ü/run.js')==0)
    end})
    local e=tui.host;report={backends={},states={}}
    local first=tui:launch();report.backends[1]=first
    local original=tui:lua([[return {PATH=vim.env.PATH,VIRTUAL_ENV=vim.env.VIRTUAL_ENV,CONDA_PREFIX=vim.env.CONDA_PREFIX}]])
    tui:command('edit first.txt');e:wait('first code file',function() return tui:state().file==tui.a..'/first.txt' end)
    tui:lua('vim.api.nvim_win_set_cursor(0,{23,7})')
    local prompt
    local function choose(label)
      e:wait('native SDK picker',function() return tui:mode().mode=='i' and tui:lua([[return vim.bo.filetype=='TelescopePrompt'
        and tostring(vim.uv.os_getpid())..':'..vim.api.nvim_get_current_buf()~=...]],{prompt or ''}) end,30000)
      local found=false
      for _=1,100 do
        local ordinal=tui:lua([[local entry=require('telescope.actions.state').get_selected_entry();return entry and entry.ordinal or '']])
        if ordinal:find(label,1,true) then found=true;break end
        tui:send('\14');e:wait('picker moved',function() return tui:lua([[local entry=require('telescope.actions.state').get_selected_entry();return entry and entry.ordinal~=...]],{ordinal}) end)
      end
      assert(found,'Choice missing: '..label)
      prompt=tui:lua([[return tostring(vim.uv.os_getpid())..':'..vim.api.nvim_get_current_buf()]]);tui:send('\r')
    end
    local function apply(kind,scope,manual)
      local previous=report.backends[#report.backends]
      tui:command('ForgeSdk '..kind..' '..scope);choose('Указать путь')
      e:wait('native manual input',function() return tui:mode().mode=='c' end);tui:send(manual..'\r')
      choose('Сохранить и переоткрыть проект')
      local ready=tui:connect(previous.pid);assert(ready.ms>previous.ms);report.backends[#report.backends+1]=ready
      e:wait('restored code and cursor',function() local s=tui:state();return s.file==tui.a..'/first.txt' and s.cursor[1]==23 and s.cursor[2]==7 end,10000)
    end
    apply('python','project',tui.a..'/venv with spaces')
    local observed=tui:lua([[local p=require('forge.python').resolve({vim.fn.getcwd()})
      local result=vim.system({p,'-I','-B','-c','import sys,json;print(json.dumps({"prefix":sys.prefix,"executable":sys.executable}))'},{text=true}):wait(5000)
      assert(result.code==0,result.stderr);return vim.json.decode(result.stdout)]])
    equal_path(observed.prefix,tui.a..'/venv with spaces');report.states.python=observed
    apply('node','user',e.runtime..'/Node SDK with spaces')
    tui:command('edit run.js');e:wait('JS file',function() return tui:state().file==tui.a..'/run.js' end)
    tui:command('NodeRunFile')
    e:wait('native NodeRunFile',function() return vim.fn.filereadable(tui.a..'/node-run.json')==1 end,15000)
    report.states.node=read(tui.a..'/node-run.json');assert(report.states.node.version:match('^v%d+'))
    -- Node reports the native resolved image path, while settings retain the alias.
    equal_path(assert(vim.uv.fs_realpath(report.states.node.executable)),assert(vim.uv.fs_realpath(node)))
    e:wait('Node task ended',function() return tui:lua([[for _,task in ipairs(require('overseer').list_tasks()) do if task:is_running() then return false end end;return true]]) end)
    local final=tui:lua([[return {PATH=vim.env.PATH,VIRTUAL_ENV=vim.env.VIRTUAL_ENV,CONDA_PREFIX=vim.env.CONDA_PREFIX}]])
    T.eq(final,original);T.eq(tui:state().installs,0)
    tui:lua([[_G.sdk_task=require('overseer').new_task({cmd={vim.v.progpath,'--headless','-u','NONE','-i','NONE','-c','sleep 30','-c','qa!'},components={'default'}});_G.sdk_task:start()]])
    e:wait('active task',function() return tui:lua('return _G.sdk_task:is_running()') end)
    assert(not tui:lua('return require("forge.sdk").apply()'))
    T.eq(tui:lua('return vim.uv.os_getpid()'),report.backends[#report.backends].pid)
    tui:lua('_G.sdk_task:stop()');e:wait('task stopped',function() return tui:lua('return not _G.sdk_task:is_running()') end)
    T.eq(#report.backends,3)
  end,debug.traceback)
  if tui then
    report=report or {};report.ok=ok;report.error=not ok and tostring(err) or nil
    write(tui.host.dir..'/runtime-sdk-native.json',report)
    io.stdout:write('  artifacts: '..tui.host.dir..'\n')
    local closed,why=pcall(tui.stop,tui,not ok and err or nil)
    if not closed then ok=false;err=tostring(err)..'\n'..tostring(why) end
    if closed then
      local shutdown=read(tui.host.dir..'/shutdown.json')
      assert(shutdown.ok and shutdown.exit_code==0 and shutdown.exit_signal==0 and not shutdown.hard_kill)
      assert(shutdown.scope.ok and not shutdown.scope.terminated and (shutdown.scope.active_after==0 or shutdown.scope.active_after==false))
    end
  end
  assert(ok,err)
end)
T.finish()
