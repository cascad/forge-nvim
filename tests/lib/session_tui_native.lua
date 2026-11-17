-- Observer only: actual TUI owns restart/reconnect, this file never starts it.
local base=assert(vim.env.FORGE_SESSION_PROBE)
_G.forge_session_notices={};_G.forge_session_installs=0
_G.forge_session_views_restored=0
local notify=vim.notify
vim.notify=function(message,level,opts)
  _G.forge_session_notices[#_G.forge_session_notices+1]={message=tostring(message),level=level or vim.log.levels.INFO}
  return notify(message,level,opts)
end
vim.api.nvim_create_autocmd('User',{pattern='MasonToolsStartingInstall',callback=function()
  _G.forge_session_installs=_G.forge_session_installs+1
end})
local function state(event)
  return {event=event,pid=vim.uv.os_getpid(),server=vim.v.servername,cwd=vim.fn.getcwd(),
    ms=vim.uv.hrtime()/1e6}
end
local function record(event)
  local row=state(event)
  assert(vim.fn.writefile({vim.json.encode(row)},base..'/lifecycle.jsonl','a')==0)
  return row
end
vim.api.nvim_create_autocmd({'VimEnter','VimLeavePre','VimLeave'},{callback=function(ev) record(ev.event) end})
vim.api.nvim_create_autocmd('User',{
  pattern={'PersistenceSavePre','PersistenceSavePost','PersistenceLoadPre','PersistenceLoadPost'},
  callback=function(ev)
    record(ev.match)
    if ev.match=='PersistenceLoadPre' and not _G.forge_session_views_observed then
      -- LoadPost precedes the async panel render. Observe its existing completion
      -- boundary; a file-count wait can send input while restore changes tabs.
      local lifecycle=require('forge.neo_tree_lifecycle')
      local loading=lifecycle.session_loading
      lifecycle.session_loading=function(value)
        loading(value)
        if not value then
          _G.forge_session_views_restored=_G.forge_session_views_restored+1
          record('ForgeSessionViewsRestored')
        end
      end
      _G.forge_session_views_observed=true
    end
  end,
})
vim.api.nvim_create_autocmd('User',{pattern='VeryLazy',once=true,callback=function()
  vim.schedule(function()
    assert(vim.fn.writefile({vim.json.encode(record('ready'))},base..'/ready.json')==0)
  end)
end})
