-- Только наблюдение: native Lazy profiler и события первого открытия файла.
local root=vim.fn.getcwd():gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local project=require('rust_project')
local start=project.start
project.start=function(root,on_create,before_enter)
  return start(root,on_create,function(e)
    if before_enter then before_enter(e) end
    e:lua([[local t0=vim.uv.hrtime();_G.forge_open_trace={events={},profiles={}}
      local function record(kind,path)
        table.insert(_G.forge_open_trace.events,{ms=(vim.uv.hrtime()-t0)/1e6,kind=kind,path=path})
      end
      local util=require('lazy.core.util');local track=util.track
      util.track=function(...)
        local entry=track(...)
        if select('#',...)==0 and entry then
          table.insert(_G.forge_open_trace.profiles,{ms=(vim.uv.hrtime()-t0)/1e6,time_ms=entry.time/1e6,data=entry.data})
        end
        return entry
      end
      vim.api.nvim_create_autocmd({'BufReadPre','BufReadPost','BufEnter','BufWinEnter','FileType','LspAttach'},
        {callback=function(ev) record(ev.event,vim.api.nvim_buf_get_name(ev.buf)) end})
      vim.on_key(function(key) if key==':' or key=='\r' or key=='\27' then record('key',key) end end)
    ]])
    local snapshot=e.snapshot
    e.snapshot=function(self,...)
      local ok,result=pcall(self.lua,self,'return _G.forge_open_trace')
      vim.fn.writefile({vim.json.encode(ok and result or {error=tostring(result)})},self.dir..'/open-trace.json')
      return snapshot(self,...)
    end
  end)
end
vim.env.FORGE_RUST_CASE='IDE-RUST-2'
dofile(root..'/tests/e2e/rust-language.test.lua')
