-- Только измерение реальных функций private TUI; поведение и deadlines прежние.
local root=vim.fn.getcwd():gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local session=require('session_tui')
local start=session.start
session.start=function(...)
  local tui=start(...);local connect=tui.connect
  tui.connect=function(self,...)
    local ready=connect(self,...)
    self:lua([[local path=...;if _G.forge_save_probe then return end;_G.forge_save_probe=true
      local function record(stage)
        vim.fn.writefile({vim.json.encode({stage=stage,pid=vim.fn.getpid(),ms=vim.uv.hrtime()/1e6})},path,'a')
      end
      local function wrap(module,name)
        local original=module[name]
        module[name]=function(...)
          record(name..':start');local result={original(...)};record(name..':end');return unpack(result)
        end
      end
      wrap(require('forge.session_views'),'capture')
      wrap(require('ide'),'cleanup_for_session')
      wrap(require('persistence'),'save')
      record('probe:ready')]],{self.host.dir..'/save-phases.jsonl'})
    return ready
  end
  return tui
end
dofile(root..'/tests/e2e/session-logs-view.test.lua')
