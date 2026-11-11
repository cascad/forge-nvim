-- IDE-104: opt-in native events, bounded memory; никакого refresh/scan override.
local M={}
function M.start(project)
  local events=require('neo-tree.events')
  local utils=require('neo-tree.utils')
  local base=utils.normalize_path(project)
  local state=require('neo-tree.sources.manager').get_state_for_window()
  assert(state and state.name=='filesystem','Trace requires focused Files')
  local parent=utils.path_join(base,'создано space')
  local child=utils.path_join(parent,'новый файл.txt')
  local started=vim.uv.hrtime()
  local result={records={},dropped=0,parent=parent,child=child}
  local function info(node)
    if not node then return false end
    return {name=node.name,path=node.path,loaded=node.loaded,expanded=node:is_expanded(),
      children=vim.deepcopy(node:get_child_ids())}
  end
  local function capture(kind,s,path)
    if not s or s.name~='filesystem' or utils.normalize_path(s.path or '')~=base then return end
    if #result.records>=128 then result.dropped=result.dropped+1;return end
    local ok,value=pcall(function()
      return {kind=kind,ms=(vim.uv.hrtime()-started)/1e6,path=path,ready=s._ready,
        parent=s.tree and info(s.tree:get_node(parent)),child=s.tree and info(s.tree:get_node(child)),
        disk_child=vim.uv.fs_stat(child)~=nil,expanded=vim.deepcopy(s.default_expanded_nodes),
        explicitly_opened=vim.deepcopy(s.explicitly_opened_nodes)}
    end)
    result.records[#result.records+1]=ok and value or {kind=kind,error=tostring(value)}
  end
  for _,kind in ipairs({'BEFORE_RENDER','AFTER_RENDER'}) do
    events.subscribe({event=events[kind],id='forge-file-create-'..kind,handler=function(s) capture(kind,s) end})
  end
  events.subscribe({event=events.FILE_ADDED,id='forge-file-create-added',handler=function(path) capture('FILE_ADDED',state,path) end})
  capture('attached',state)
  return {result=function() return result end}
end
return M
