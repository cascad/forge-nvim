-- Observer only: actual TUI owns restart/reconnect, this file never starts it.
local base=assert(vim.env.FORGE_SESSION_PROBE)
_G.forge_session_notices={};_G.forge_session_installs=0
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
  callback=function(ev) record(ev.match) end,
})
vim.api.nvim_create_autocmd('User',{pattern='VeryLazy',once=true,callback=function()
  vim.schedule(function()
    assert(vim.fn.writefile({vim.json.encode(record('ready'))},base..'/ready.json')==0)
  end)
end})
