-- IDE-106: отвергнутый observer prototype; history/cmdheight не доказывают visual forwarding.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local e
local ok,err=xpcall(function()
  e=require('editor').start(root)
  e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
  e:lua([[
    _G.forge_log_probe={cmdheight=vim.o.cmdheight,events={}}
    local ns=vim.api.nvim_create_namespace('forge-log-probe')
    vim.ui_attach(ns,{ext_messages=true,set_cmdheight=false},function(event,...)
      if event=='msg_show' then
        local args={...};vim.schedule(function()
          _G.forge_log_probe.events[#_G.forge_log_probe.events+1]=args
        end)
      end
      return false
    end)
    vim.notify('IDE106_NATIVE_NOTIFY',vim.log.levels.WARN,{title='Probe'})
    vim.api.nvim_echo({{'IDE106_NATIVE_ECHO','WarningMsg'}},true,{})
  ]])
  e:wait('native events',function() return #e:lua('return _G.forge_log_probe.events')>=2 end)
  local data=e:lua('return {probe=_G.forge_log_probe,cmdheight=vim.o.cmdheight,messages=vim.fn.execute("messages")}')
  assert(data.cmdheight==data.probe.cmdheight,'Subscription changed cmdheight')
  assert(data.messages:find('IDE106_NATIVE_NOTIFY',1,true) and data.messages:find('IDE106_NATIVE_ECHO',1,true),'Native history swallowed')
  vim.fn.writefile({vim.json.encode(data)},e.dir..'/ide-log-events.json')
  e:snapshot('ide-log-events');io.stdout:write('artifacts: '..e.dir..'\n')
end,debug.traceback)
if e then local stopped,issue=pcall(e.stop,e,not ok and err or nil);assert(stopped,issue) end
assert(ok,err)
print('Native observer receives events; history/cmdheight retained; visual forwarding NOT verified')
