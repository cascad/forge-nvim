local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
if vim.env.FORGE_E2E_DRIVER_SOURCE then package.path=vim.env.FORGE_E2E_DRIVER_SOURCE..'/?.lua;'..package.path end
local T=require('check')
local function check(name,fn)
  if vim.env.FORGE_RUNTIME_E2E_CASE and not name:find(vim.env.FORGE_RUNTIME_E2E_CASE,1,true) then return end
  T.check(name,fn)
end

check('SELF: EDITOR-RUNTIME остановка реального редактора удаляет профиль и сохраняет артефакты',function()
  local e=require('editor').start(root)
  local ok,err=pcall(function()
    e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    e:input(':edit file_one.txt<CR>gg0iRUNTIME_SAVED_<Esc>:w<CR>')
    e:wait('файл сохранён',function() return vim.fn.readfile(e.project..'/file_one.txt')[1]=='RUNTIME_SAVED_first file' end)
    e:stop()
    T.eq(vim.fn.isdirectory(e.runtime),0,'runtime не удалён')
    T.eq(e.rpc.exited,true,'дочерний процесс завершён')
    T.eq(vim.fn.readfile(e.dir..'/project/file_one.txt')[1],'RUNTIME_SAVED_first file')
    T.eq(vim.fn.filereadable(e.dir..'/config-source/init.lua'),1)
    T.eq(vim.fn.filereadable(e.dir..'/snapshot.json'),1)
    e:stop() -- повторная остановка безопасна
  end)
  if not e.stopped then pcall(function() e:stop() end) end
  io.stdout:write('  artifacts: '..e.dir..'; runtime: '..e.runtime..'\n')
  assert(ok,err)
end)

check('SELF: EDITOR-RUNTIME ошибка подготовки не оставляет копию плагинов',function()
  local runtime
  local ok,err=pcall(require('editor').start,root,{prepare=function(_,_,path)
    runtime=path;error('FORGE_EXPECTED_PREPARE_FAILURE')
  end})
  assert(not ok and tostring(err):find('FORGE_EXPECTED_PREPARE_FAILURE',1,true),tostring(err))
  assert(runtime,'prepare должен выполниться')
  T.eq(vim.fn.isdirectory(runtime),0,'частично подготовленный runtime удалён')
end)

check('SELF: EDITOR-RUNTIME чужой маркер запрещает удаление',function()
  local R=require('editor_runtime')
  local p=R.create(root)
  local marker=p.path..'/.forge-e2e-owner.json'
  local original=vim.fn.readfile(marker)
  vim.fn.writefile({'valuable fixture'},p.path..'/keep.txt')
  vim.fn.writefile({vim.json.encode({root=p.root,path=p.canonical,token='foreign'})},marker)
  local ok,err=pcall(R.remove,p)
  local retained=vim.fn.readfile(p.path..'/keep.txt')
  vim.fn.writefile(original,marker);R.remove(p)
  assert(not ok and tostring(err):find('Маркер',1,true),tostring(err))
  T.eq(retained,{'valuable fixture'})
end)

check('SELF: EDITOR-RUNTIME временная блокировка файла не оставляет профиль',function()
  local R=require('editor_runtime');local p=R.create(root)
  local control=root..'/.tests/runtime-lock-'..tostring(vim.uv.hrtime())
  vim.fn.mkdir(control,'p')
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
  local child=vim.system({python,'-B',root..'/tests/e2e/hold_file.py',p.path..'/held.txt',control..'/ready',control..'/release'},{text=true})
  assert(vim.wait(3000,function() return vim.fn.filereadable(control..'/ready')==1 end,10),'holder готов')
  vim.defer_fn(function() vim.fn.writefile({},control..'/release') end,150)
  local ok,err=pcall(R.remove,p)
  vim.fn.writefile({},control..'/release')
  local result=child:wait(2000)
  assert(ok,err);T.eq(result.code,0);T.eq(vim.fn.isdirectory(p.path),0)
end)
local forced='SELF: EDITOR-RUNTIME зависший RPC сохраняет причину, завершает child и удаляет профиль'
if vim.fn.has('win32')==1 then
  if not vim.env.FORGE_RUNTIME_E2E_CASE or forced:find(vim.env.FORGE_RUNTIME_E2E_CASE,1,true) then
    T.skip(forced,'POSIX SIGSTOP отсутствует на Windows')
  end
else
  check(forced,function()
    local e=require('editor').start(root)
    local ok,err=pcall(function()
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e.rpc.process:kill('sigstop')
      assert(vim.wait(2000,function()
        local state=vim.system({'ps','-o','stat=','-p',tostring(e.rpc.process.pid)},{text=true,timeout=1000}):wait()
        return state.code==0 and state.stdout:match('^%s*T')~=nil
      end,25),'Child не остановлен')
      local answered,primary=pcall(e.lua,e,'return 1')
      assert(not answered and tostring(primary):find('RPC timeout: nvim_get_mode',1,true),tostring(primary))
      local stopped,cleanup=pcall(e.stop,e,tostring(primary))
      assert(not stopped and tostring(cleanup):find(tostring(primary),1,true),tostring(cleanup))
      assert(tostring(cleanup):find('SIGKILL',1,true),tostring(cleanup))
      T.eq(e.rpc.exited,true);T.eq(e.stopped,true);T.eq(vim.fn.isdirectory(e.runtime),0)
      local data=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/shutdown.json'),'\n'))
      T.eq(data.hard_kill,true);T.eq(data.ok,false);T.eq(data.exit_signal,9)
      T.eq(data.primary_error,tostring(primary));T.eq(data.rpc_failure.method,'nvim_get_mode')
      local snapshot=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/snapshot.json'),'\n'))
      assert(snapshot.error:find('RPC timeout: nvim_get_mode',1,true),snapshot.error)
      T.eq(vim.fn.filereadable(e.dir..'/config-source/init.lua'),1)
    end)
    if not e.rpc.exited then pcall(function() e.rpc.process:kill('sigkill') end);vim.wait(2000,function() return e.rpc.exited end,10) end
    if not e.stopped then pcall(e.stop,e,tostring(err)) end
    io.stdout:write('  artifacts: '..e.dir..'; runtime: '..e.runtime..'\n')
    assert(ok,err)
  end)
end
T.finish()
