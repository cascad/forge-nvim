-- IDE-104: test-only задержка ОДНОГО настоящего async readdir private root.
-- Данные/ошибки native IO не заменяются; продукт этот модуль не загружает.
local M={}
function M.arm(project)
  local uv=vim.uv
  local root=assert(uv.fs_realpath(project))
  assert(root==assert(uv.fs_realpath(vim.fn.getcwd())),'Private project must be current cwd')
  local opendir,readdir=uv.fs_opendir,uv.fs_readdir
  local target_dir
  local held
  local report={root=root,held=false,released=false,drained=false,entries={},batches=0}
  local function same(path) return uv.fs_realpath(path)==root end
  uv.fs_opendir=function(path,callback,entries)
    if type(callback)~='function' or not same(path) then return opendir(path,callback,entries) end
    return opendir(path,function(err,dir)
      if dir and not target_dir then target_dir=dir end
      callback(err,dir)
    end,entries)
  end
  uv.fs_readdir=function(dir,callback)
    if dir~=target_dir or held or report.released or type(callback)~='function' then return readdir(dir,callback) end
    report.request_stack=report.request_stack or debug.traceback('Native root readdir request',2)
    return readdir(dir,function(err,entries)
      if not report.restored and not err and not entries and not held then
        held=function() callback(err,entries) end
        report.held=true
      else
        report.batches=report.batches+1
        for _,entry in ipairs(entries or {}) do report.entries[#report.entries+1]={name=entry.name,type=entry.type} end
        callback(err,entries)
      end
    end)
  end
  local function release()
    report.restored=true
    uv.fs_opendir,uv.fs_readdir=opendir,readdir
    if held and not report.released then
      report.released=true;held()
      -- Удержан последний shallow root read: on_exit→job_complete→render
      -- →AFTER_RENDER планируются именно так. Наблюдаем четыре оборота очереди.
      local function drain(turns)
        vim.schedule(function() if turns==1 then report.drained=true else drain(turns-1) end end)
      end
      drain(4)
    end
  end
  return {report=function() return report end,release=release}
end
return M
