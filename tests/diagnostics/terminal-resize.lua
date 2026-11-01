-- CLI repro native terminal lifecycle. Использует --clean, без Forge/плагинов.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local cycles,resize,executable=50,true,vim.v.progpath
local i=1
while i<=#arg do
  if arg[i]=='--passive' then resize=false
  elseif arg[i]=='--cycles' then i=i+1;cycles=tonumber(arg[i])
  elseif arg[i]=='--nvim' then i=i+1;executable=arg[i]
  else io.stderr:write('Неизвестный аргумент: '..tostring(arg[i])..'\n');os.exit(2) end
  i=i+1
end
if not cycles or cycles%1~=0 or cycles<1 or cycles>200 or not executable or executable=='' then
  io.stderr:write('Использование: nvim -l tests/diagnostics/terminal-resize.lua [--passive] [--cycles 1..200] [--nvim EXE]\n')
  os.exit(2)
end
local R=require('editor_runtime')
local profile=R.create(root)
local dir=root..'/.tests/native-terminal/'..tostring(vim.uv.hrtime())
vim.fn.mkdir(dir,'p')
local env=vim.fn.environ()
for _,key in ipairs({'HOME','USERPROFILE','LOCALAPPDATA','APPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME','XDG_STATE_HOME','TEMP','TMP','TMPDIR'}) do
  env[key]=profile.path..'/'..key;vim.fn.mkdir(env[key],'p')
end
env.NVIM_LOG_FILE=profile.path..'/nvim.log';env.NVIM_APPNAME='nvim_forge'
vim.fn.writefile({'native terminal fixture'},profile.path..'/sample.txt')
local rpc,cycle,completed,stage= nil,0,0,'start'
local metadata={os=vim.uv.os_uname(),executable=executable,resize=resize,cycles=cycles,runtime=profile.path,artifacts=dir}
local function lua(s,args) return rpc:request('nvim_exec_lua',{s,args or {}}) end
local function input(s) rpc:request('nvim_input',{s}) end
local function wait(label,fn)
  stage=label
  local deadline=vim.uv.hrtime()+5000000000
  repeat if fn() then return end;vim.wait(5) until vim.uv.hrtime()>=deadline
  error('Не завершён этап: '..label)
end
local ok,err=xpcall(function()
  rpc=require('editor_rpc').start({executable,'--clean','--headless','--embed','-i','NONE'},{cwd=profile.path,env=env,timeout=120000})
  metadata.pid=rpc.process.pid
  rpc:request('nvim_ui_attach',{140,45,{rgb=true,ext_linegrid=true}})
  metadata.version=lua('return vim.version()')
  input(':edit sample.txt<CR>')
  wait('source',function() return lua([[return vim.api.nvim_buf_get_name(0):match('sample%.txt$')~=nil]]) end)
  local source=lua('return vim.api.nvim_get_current_win()')
  if resize then
    lua([[vim.api.nvim_create_autocmd('TermOpen',{callback=function()
      local win=vim.api.nvim_get_current_win()
      for step=1,50 do vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_set_height(win,5+step%2) end
      end,step) end
    end})]])
  end
  for n=1,cycles do
    cycle=n
    input(':botright split<CR>:terminal echo NATIVE_TERMINAL_'..n..'<CR>')
    wait('terminal',function() return lua('return vim.bo.buftype')=='terminal' end)
    local buf=lua('return vim.api.nvim_get_current_buf()')
    wait('process-exit',function() return lua('return vim.fn.jobwait({vim.b.terminal_job_id},0)[1]~=-1') end)
    input('<C-\\><C-n><C-w>p')
    wait('source-focus',function() return lua('return vim.api.nvim_get_current_win()')==source end)
    input(':bwipeout! '..buf..'<CR>')
    wait('terminal-closed',function() return not lua('return vim.api.nvim_buf_is_valid(...)',{buf}) end)
    completed=n
  end
end,debug.traceback)
if rpc then
  vim.fn.writefile(rpc:screen_lines(),dir..'/screen.txt')
  vim.fn.writefile(vim.split(table.concat(rpc.stderr),'\n'),dir..'/stderr.log')
  if not rpc.exited then
    pcall(function() rpc.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}})) end)
    if not vim.wait(2000,function() return rpc.exited end,10) then
      rpc.process:kill(15);vim.wait(2000,function() return rpc.exited end,10)
    end
  end
  metadata.child_exit=rpc.exit_code
  if ok and (not rpc.exited or rpc.exit_code~=0) then
    ok=false;err='Неуспешное завершение child: '..tostring(rpc.exit_code)
  end
end
if vim.fn.filereadable(env.NVIM_LOG_FILE)==1 then vim.uv.fs_copyfile(env.NVIM_LOG_FILE,dir..'/nvim.log') end
metadata.cycle=cycle;metadata.completed=completed;metadata.stage=stage
local removed,remove_error=pcall(R.remove,profile)
metadata.cleaned=removed
if not removed then metadata.cleanup_error=tostring(remove_error);ok=false end
metadata.ok=ok;metadata.error=err and tostring(err) or nil
vim.fn.writefile({vim.json.encode(metadata)},dir..'/result.json')
io.stdout:write(vim.json.encode(metadata),'\n');io.stdout:flush()
os.exit(ok and 0 or 1)
