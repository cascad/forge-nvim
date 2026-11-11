-- Bounded repeat of the real Rust/CodeLLDB output case, optional in-memory trace.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local cycles,resize=1,false
vim.env.FORGE_OUTPUT_TRACE=nil
local i=1
while i<=#arg do
  if arg[i]=='--trace' then vim.env.FORGE_OUTPUT_TRACE='1'
  elseif arg[i]=='--resize' then resize=true
  elseif arg[i]=='--cycles' then i=i+1;cycles=tonumber(arg[i])
  else error('Usage: output-toggle.lua [--trace] [--resize] [--cycles 1..10]') end
  i=i+1
end
assert(cycles and cycles>=1 and cycles<=10 and cycles%1==0,'--cycles must be 1..10')
vim.env.FORGE_OUTPUT_CASE='Rust PTY'
local P=require('output_policy')
local reopen=P.reopen
local resized=false
P.reopen=function(e,ft,keys)
  local input=e.input
  if resize then
    e.input=function(self,keys)
      if not resized and keys=='q' then
        resized=true
        local function geometry()
          return self:lua([[local w=vim.api.nvim_get_current_win();local b=vim.api.nvim_win_get_buf(w)
            local view=vim.fn.getwininfo(w)[1]
            return {win=w,buf=b,ft=vim.bo[b].filetype,buftype=vim.bo[b].buftype,
              height=vim.api.nvim_win_get_height(w),rows=vim.api.nvim_buf_line_count(b),lines=vim.o.lines,
              first=view.topline,view=view.botline-view.topline+1,winbar=vim.wo[w].winbar~=''}]])
        end
        local before=geometry()
        assert(before.ft==ft and before.buftype=='terminal' and before.first==1,'Resize requires an unscrolled terminal viewport')
        self.rpc:request('nvim_ui_try_resize',{140,35})
        local after
        local ready,err=pcall(self.wait,self,'Native terminal buffer refreshed after viewport shrink',function()
          after=geometry()
          return after.win==before.win and after.buf==before.buf and after.lines==35
            and after.height<before.height and after.first==1 and after.rows==after.view and after.rows<before.rows
        end)
        assert(vim.fn.writefile({vim.json.encode({before=before,after=after,ready=ready,error=not ready and tostring(err) or nil})},self.dir..'/output-resize.json')==0)
        assert(ready,err)
        assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/output-toggle.lua',self.dir..'/output-toggle.lua'))
      end
      return input(self,keys)
    end
  end
  local ok,err=pcall(function() for _=1,(keys==' du' and cycles or 1) do reopen(e,ft,keys) end end)
  e.input=input
  if not ok then error(err,0) end
end
dofile(root..'/tests/e2e/dap-output-policy.test.lua')
