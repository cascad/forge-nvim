local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local source=vim.env.FORGE_DESCENDANT_DRIVER_SOURCE
if source and source~='' then package.path=source..'/?.lua;'..package.path end
local T=require('check')
local posix_source=vim.env.FORGE_POSIX_SCOPE_SOURCE
if posix_source and posix_source~='' then
  assert(vim.fn.has('win32')==0 and not source,'POSIX replay нужен native Unix без driver override')
  local raw=table.concat(vim.fn.readfile(posix_source,'b'),'\n'):gsub('\r\n','\n')
  T.eq(vim.fn.sha256(raw),'cc71f6408e0752f654c0fd7448d92b1ed83b1f6cec5e2a5a2db9bf09e0291f2e','exact scope 054ee05')
  package.loaded.process_scope_posix=assert(loadstring(raw,'@'..posix_source))()
end
local baseline={
  ['editor.lua']='66531d6fe919f61089d18cacf357ec339bd4c044a714da48e311cedff3ed2126',
  ['editor_rpc.lua']='1b937039ecac80675bdaf561f818817ec2fec5ad9ab312c2c32b0cb3fc1828c6',
  ['editor_process.lua']='6fc531e96607f5d795e32f2f73e963b6096ad54f18480ff4a49ffb77ad592412',
  ['editor_runtime.lua']='ccb64a50ee1f16e69f304b6361cd252023fac2091252050631bf17426fd1a7a6',
}
local uv=vim.uv
local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
assert(python~='','Нужен host Python для настоящего process fixture')
local fixture=root..'/tests/e2e/process_worker.py'
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function alive(pid)
  if not uv.kill(pid,0) then return false end
  if vim.fn.has('win32')==1 then return true end
  local state=vim.system({'ps','-o','stat=','-p',tostring(pid)},{text=true}):wait()
  return state.code==0 and state.stdout:match('%S')~=nil and not state.stdout:match('^%s*Z')
end
local function wait(label,fn,timeout) assert(vim.wait(timeout or 4000,fn,10),label) end
local function control(dir,name)
  local path=dir..'/'..name;vim.fn.mkdir(path,'p');return path
end
local launch=[[
  local python,fixture,target,control,native_job=...
  _G.forge_worker_parent_exit=nil
  if native_job then
    local job=vim.fn.jobstart({python,'-B',fixture,'parent',target,control},{on_exit=function(_,code)
      _G.forge_worker_parent_exit={code=code,signal=0}
    end})
    assert(job>0,'native jobstart не запустил intermediate parent')
    _G.forge_worker_parent_pid=vim.fn.jobpid(job)
    return _G.forge_worker_parent_pid
  end
  local handle
  handle=assert(vim.uv.spawn(python,{args={'-B',fixture,'parent',target,control}},function(code,signal)
    _G.forge_worker_parent_exit={code=code,signal=signal}
    handle:close()
  end))
  _G.forge_worker_parent_pid=handle:get_pid()
  return _G.forge_worker_parent_pid
]]
local function check(name,real_editor,exit_mode,native_job)
  if vim.env.FORGE_DESCENDANT_CASE and not name:find(vim.env.FORGE_DESCENDANT_CASE,1,true) then return end
  T.check('SELF: EDITOR-DESCENDANTS '..name,function()
    local dir=root..'/.tests/editor-descendants-e2e/'..tostring(uv.hrtime())
    vim.fn.mkdir(dir,'p')
    local own,foreign=control(dir,'own'),control(dir,'foreign')
    local rpc,e,other,worker,foreign_pid,profile,result
    local code_sources={}
    for _,file in ipairs({'editor.lua','editor_rpc.lua','editor_process.lua','editor_runtime.lua'}) do
      local path=(source or root..'/tests/lib')..'/'..file
      local bytes=table.concat(vim.fn.readfile(path,'b'),'\n'):gsub('\r\n','\n')
      code_sources[file]=vim.fn.sha256(bytes)
      if source then T.eq(code_sources[file],baseline[file],'exact driver eeae06c: '..file) end
      assert(uv.fs_copyfile(path,dir..'/'..file))
    end
    for _,file in ipairs({'process_scope.lua','process_scope_windows.lua','process_scope_posix.lua'}) do
      local path=(file=='process_scope_posix.lua' and posix_source) or (root..'/tests/lib/'..file)
      if not source and vim.fn.filereadable(path)==1 then
        assert(uv.fs_copyfile(path,dir..'/'..file))
        code_sources[file]=vim.fn.sha256((table.concat(vim.fn.readfile(path,'b'),'\n'):gsub('\r\n','\n')))
      end
    end
    assert(uv.fs_copyfile(fixture,dir..'/process_worker.py'))
    assert(uv.fs_copyfile(root..'/tests/e2e/editor-descendants.test.lua',dir..'/editor-descendants.test.lua'))
    local ok,err=xpcall(function()
      other=vim.system({python,'-B',fixture,'worker',dir..'/foreign-held.txt',foreign},
        {cwd=root,timeout=35000,env={NVIM_LOG_FILE=dir..'/foreign.log'}})
      wait('чужой worker открыл файл',function() return vim.fn.filereadable(foreign..'/ready.json')==1 end)
      foreign_pid=read(foreign..'/ready.json').pid
      local target=dir..'/held.txt'
      if real_editor then
        e=require('editor').start(root);rpc=e.rpc
        local marker=read(e.runtime..'/.forge-e2e-owner.json')
        profile={path=e.runtime,canonical=marker.path,root=marker.root,token=marker.token,parent=assert(uv.fs_realpath(vim.fs.dirname(e.runtime)))}
        target=e.runtime..'/state/owned-worker-held.txt'
        e:lua(launch,{python,fixture,target,own,native_job or false})
      else
        local bootstrap=dir..'/launch.lua'
        vim.fn.writefile({'assert(loadstring('..vim.inspect(launch)..'))('..vim.inspect(python)..','..
          vim.inspect(fixture)..','..vim.inspect(target)..','..vim.inspect(own)..','..tostring(native_job or false)..')'},bootstrap)
        rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE',
          '--cmd','lua dofile('..vim.inspect(bootstrap)..')'},
          {cwd=root,timeout=30000,artifacts=dir,env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/nvim.log'})})
      end
      local spawn_failure=rpc:request('nvim_exec_lua',{[[
        local function pack(...) return {n=select('#',...),...} end
        local out=pack(vim.uv.spawn('__forge_e2e_missing_executable_077__',{},function() end))
        return {n=out.n,missing=out[1]==nil,code=out[3]}
      ]],{}})
      T.eq(spawn_failure,{n=3,missing=true,code='ENOENT'},'native spawn failure tuple сохранён')
      wait('intermediate parent завершён до editor',function()
        local data=rpc:request('nvim_exec_lua',{'return _G.forge_worker_parent_exit',{}})
        return type(data)=='table' and data.code==0
      end)
      wait('own orphan действительно держит файл',function() return vim.fn.filereadable(own..'/ready.json')==1 end)
      worker=read(own..'/ready.json').pid
      T.eq(read(own..'/parent.json').worker,worker)
      assert(alive(worker),'worker жив до stop')
      assert(not alive(read(own..'/parent.json').pid),'intermediate parent уже завершён')
      if vim.fn.has('win32')==1 then
        local removed=uv.fs_unlink(target)
        assert(not removed,'настоящий file lock запрещает удаление до stop')
      end
      if exit_mode=='early' then
        rpc.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}}))
        wait('editor вышел до вызова stop',function() return rpc.exited end)
      elseif exit_mode=='killed' then
        rpc.process:kill('sigkill')
        wait('own root завершён принудительно',function() return rpc.exited end)
      end
      if e then
        e:stop();T.eq(vim.fn.isdirectory(e.runtime),0,'реальный private runtime удалён')
        result=rpc.shutdown_result
      else
        result=require('editor_process').stop(rpc,dir,exit_mode=='killed' and 'EXPECTED ROOT FAILURE' or nil)
        assert(result.ok,result.error)
      end
      wait('orphan worker не переживает editor stop',function() return not alive(worker) end,2000)
      assert(alive(foreign_pid),'чужой параллельный worker должен продолжать работу')
      if not e then assert(uv.fs_unlink(target),'file lock освобождён после stop') end
      T.eq(require('editor_process').stop(rpc,e and e.dir or dir),result,'stop идемпотентен')
      if exit_mode=='killed' then T.eq(result.primary_error,'EXPECTED ROOT FAILURE') end
      assert(result.scope and result.scope.ok,'scope lifecycle evidence сохранено')
      if e then
        assert(vim.fn.filereadable(e.dir..'/snapshot.json')==1)
        vim.fn.writefile({e.dir},dir..'/editor-artifacts.txt')
      end
    end,debug.traceback)
    -- Baseline RED обязан убрать свой worker без поиска/kill по PID: только
    -- уникальный control этого fixture, который он сам читает с момента spawn.
    vim.fn.writefile({},own..'/release');vim.fn.writefile({},foreign..'/release')
    local cleaned=true
    if worker then cleaned=vim.wait(4000,function() return not alive(worker) end,20) end
    if other then
      local exited=other:wait(4000)
      cleaned=cleaned and exited.code==0 and (not foreign_pid or not alive(foreign_pid))
    end
    if rpc then pcall(require('editor_process').stop,rpc,e and e.dir or dir,tostring(err)) end
    if profile and vim.fn.isdirectory(profile.path)==1 and (not rpc or rpc.exited) then
      local removed,why=pcall(require('editor_runtime').remove,profile)
      cleaned=cleaned and removed
      if not removed then err=tostring(err)..'\nBaseline runtime cleanup: '..tostring(why) end
    end
    vim.fn.writefile({vim.json.encode({ok=ok,error=not ok and tostring(err) or nil,worker=worker,
      foreign_pid=foreign_pid,cleaned=cleaned,shutdown=result or (rpc and rpc.shutdown_result),
      source=source,sources=code_sources})},dir..'/test.json')
    if rpc then vim.fn.writefile(vim.split(table.concat(rpc.stderr),'\n'),dir..'/stderr.log') end
    io.stdout:write('  artifacts: '..dir..'\n')
    assert(cleaned,'fixture не освободил собственные ресурсы; '..dir)
    assert(ok,err)
  end)
end
check('orphan из startup, обычный qa и чужой child',false,'normal')
check('orphan из native jobstart, обычный qa и чужой child',false,'normal',true)
check('orphan после уже завершившегося root',false,'early')
check('orphan после принудительного root exit сохраняет primary error',false,'killed')
check('реальный editor очищает runtime после orphan file lock',true,'normal')
local rejection='native attach failure не запускает init и убирает child'
if not vim.env.FORGE_DESCENDANT_CASE or rejection:find(vim.env.FORGE_DESCENDANT_CASE,1,true) then
  if vim.fn.has('win32')~=1 then
    T.skip('SELF: EDITOR-DESCENDANTS '..rejection,'отказ OpenProcess проверяет Windows backend')
  else
    T.check('SELF: EDITOR-DESCENDANTS '..rejection,function()
      local dir=root..'/.tests/editor-descendants-e2e/'..tostring(uv.hrtime())
      vim.fn.mkdir(dir,'p')
      local module=require('process_scope')
      local create=module.new
      module.new=function()
        local scope=create()
        local attach=scope.attach
        -- Native OpenProcess(0) действительно отказывает. Только argument
        -- fault injection; успешных fake replies или fake child нет.
        scope.attach=function(self) return attach(self,0) end
        return scope
      end
      local ok,result=pcall(require('editor_rpc').start,
        {vim.v.progpath,'--headless','--embed','-u','NONE','-i','NONE','--cmd',
          'lua vim.fn.writefile({"unexpected"},'..vim.inspect(dir..'/init-entered')..')'},
        {cwd=root,timeout=15000,artifacts=dir,env=vim.tbl_extend('force',vim.fn.environ(),{NVIM_LOG_FILE=dir..'/nvim.log'})})
      module.new=create
      if ok then require('editor_process').stop(result,dir) end
      assert(not ok and tostring(result):find('OpenProcess: Windows error',1,true),tostring(result))
      local failure=read(dir..'/process-scope-start.json')
      T.eq(failure.exited,true);assert(not alive(failure.pid),'не осталось own startup child')
      T.eq(failure.scope.ok,true);T.eq(failure.scope.active_after,0)
      T.eq(failure.scope.gate_released,false);T.eq(vim.fn.filereadable(dir..'/init-entered'),0)
      io.stdout:write('  artifacts: '..dir..'\n')
    end)
  end
end
T.finish()
