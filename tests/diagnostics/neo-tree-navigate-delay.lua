-- IDE-PANEL-23: удерживается один настоящий callback после штатного debounce.
-- Сам navigate/renderer/IO исполняется без замены данных и ответов backend.
local M={}
function M.arm(project)
  local root=assert(vim.uv.fs_realpath(project))
  assert(root==assert(vim.uv.fs_realpath(vim.fn.getcwd())),'Private project must be current cwd')
  require('neo-tree').ensure_config()
  local utils=require('neo-tree.utils')
  local debounce=utils.debounce
  local held
  local report={root=root,held=false,released=false,restored=false,drained=false}
  utils.debounce=function(id,callback,...)
    local source=type(callback)=='function' and debug.getinfo(callback,'S').source:gsub('\\','/') or ''
    -- Native timer повторно вызывает M.debounce с уже обёрнутым callback.
    -- Его передаём без повторной обёртки, как и остальные producers.
    if id~='filesystem_navigate' or held or report.released
      or not source:find('neo-tree/sources/filesystem/init.lua',1,true) then
      return debounce(id,callback,...)
    end
    return debounce(id,function(...)
      if not held and not report.released then
        assert(vim.uv.fs_realpath(vim.fn.getcwd())==root,'Navigate left private project')
        report.callback_source=debug.getinfo(callback,'S').source:gsub('\\','/')
        assert(report.callback_source:find('neo-tree/sources/filesystem/init.lua',1,true),'Wrong callback producer')
        report.request_stack=debug.traceback('Native filesystem navigate callback',2)
        local args={n=select('#',...),...}
        held=function() return callback(unpack(args,1,args.n)) end
        report.held=true
        return
      end
      return callback(...)
    end,...)
  end
  local function release()
    utils.debounce=debounce;report.restored=true
    if held and not report.released then
      report.released=true;held()
      local function drain(turns)
        vim.schedule(function() if turns==1 then report.drained=true else drain(turns-1) end end)
      end
      drain(4)
    end
  end
  return {report=function() return report end,release=release}
end
return M
