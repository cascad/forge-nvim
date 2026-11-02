-- Только собственный тестовый child handle; результат cleanup не подменяет причину теста.
local M={}
function M.stop(rpc,dir,primary_error)
  if rpc and rpc.shutdown_result then return rpc.shutdown_result end
  local start=vim.uv.hrtime()
  local data={pid=rpc and rpc.process.pid,stages={},hard_kill=false,
    rpc_failure=rpc and rpc.failure,primary_error=primary_error or (rpc and rpc.failure and rpc.failure.message)}
  local function save()
    if not dir then return end
    local ok,err=pcall(vim.fn.writefile,{vim.json.encode(data)},dir..'/shutdown.json')
    if not ok then data.artifact_error=tostring(err) end
  end
  local function stage(name,err)
    data.stages[#data.stages+1]={stage=name,elapsed_ms=(vim.uv.hrtime()-start)/1e6,error=err}
    save()
  end
  local function exited() return not rpc or rpc.exited end
  local function signal(name)
    stage(name)
    local ok,err=pcall(function() rpc.process:kill(name) end)
    if not ok then data.stages[#data.stages].error=tostring(err);save() end
    return vim.wait(2000,exited,10)
  end
  if not exited() then
    stage('quit')
    local ok,err=pcall(function() rpc.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}})) end)
    if not ok then data.stages[#data.stages].error=tostring(err);save() end
    if not vim.wait(2000,exited,10) and not signal('sigterm') then
      data.hard_kill=true
      signal('sigkill')
    end
  end
  data.exited=not not exited();data.exit_code=rpc and rpc.exit_code;data.exit_signal=rpc and rpc.exit_signal
  stage(data.exited and 'exited' or 'still_running')
  data.ok=data.exited and not data.hard_kill and not data.artifact_error
  if not data.ok then
    data.error=not data.exited and 'Дочерний Neovim не завершился после SIGKILL'
      or data.hard_kill and 'Дочерний Neovim потребовал SIGKILL; cleanup остаётся FAIL'
      or 'Не сохранён журнал shutdown: '..data.artifact_error
    if data.primary_error then data.error=data.primary_error..'\nCleanup: '..data.error end
  end
  save()
  if rpc then rpc.shutdown_result=data end
  return data
end
return M
