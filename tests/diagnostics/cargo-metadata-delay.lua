-- IDE-DAP-9/IDE-RUST-3: настоящий Cargo, задержка только готового ответа.
-- JSON/exit/stdout не подменяются; область — один manifest частного проекта.
local M={}
function M.arm(manifest,producer)
  producer=producer or 'plugins/dap.lua'
  local target=vim.fs.normalize(assert(vim.uv.fs_realpath(manifest)))
  local function same(path)
    local value=vim.fs.normalize(path)
    if vim.fn.has('win32')==1 then return value:lower()==target:lower() end
    return value==target
  end
  local function matches(args)
    if type(args)~='table' or args[2]~='metadata' then return false end
    -- Одинаковый command может исходить из DAP, warmup или native root detection.
    if not debug.traceback('',2):gsub('\\','/'):find(producer,1,true) then return false end
    for i,arg in ipairs(args) do if arg=='--manifest-path' then return same(args[i+1]) end end
    return false
  end
  local sync,async=vim.fn.system,vim.system
  local report={manifest=target,producer=producer,sync_calls=0,async_calls=0,held=false,released=false,drained=false}
  local delivery
  vim.fn.system=function(args,...)
    if matches(args) then
      report.sync_calls=report.sync_calls+1
      report.sync_stack=debug.traceback('Native synchronous Cargo metadata',2)
      report.argv=vim.deepcopy(args)
    end
    return sync(args,...)
  end
  vim.system=function(args,opts,callback)
    if not matches(args) or type(callback)~='function' then return async(args,opts,callback) end
    report.async_calls=report.async_calls+1;report.argv=vim.deepcopy(args)
    report.request_stack=debug.traceback('Native async Cargo metadata',2)
    return async(args,opts,function(result)
      if report.restored then callback(result);return end
      assert(not delivery,'Observer accepts one native metadata result')
      report.result=vim.deepcopy(result);report.held=true
      delivery=function() callback(result) end
    end)
  end
  local function release()
    vim.fn.system,vim.system=sync,async;report.restored=true
    if delivery and not report.released then
      report.released=true;delivery()
      local function drain(n)
        vim.schedule(function() if n==1 then report.drained=true else drain(n-1) end end)
      end
      drain(4)
    end
  end
  return {report=function() return report end,release=release}
end
return M
