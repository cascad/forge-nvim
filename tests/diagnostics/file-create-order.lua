-- IDE-104: actual FS watcher/create с управляемым порядком native IO, без fake scan.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local e
local result={renders={}}
local function state()
  return e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window()
    local u=require('neo-tree.utils');local parent=u.path_join(vim.fn.getcwd(),'создано space');local child=u.path_join(parent,'новый файл.txt')
    local function info(n) return n and {name=n.name,path=n.path,loaded=n.loaded,expanded=n:is_expanded(),
      children=n:get_child_ids(),filtered_by=n.filtered_by} or false end
    return {ready=s and s._ready,parent=s and s.tree and info(s.tree:get_node(parent)),
      child=s and s.tree and info(s.tree:get_node(child)),lines=vim.api.nvim_buf_get_lines(0,0,-1,false)}]])
end
local function choose(name)
  e:wait('actual node '..name,function()
    local found=e:lua([[local name=...;local s=require('neo-tree.sources.manager').get_state_for_window()
      if not(s and s._ready and s.tree) then return {} end
      if s.tree:get_node().name==name then return {selected=true} end
      for i=1,vim.api.nvim_buf_line_count(0) do local n=s.tree:get_node(i)
        if n and n.name==name then return {row=i} end end
      return {}]],{name})
    if found.selected then return true end
    if found.row then e:input(found.row..'G') end
  end)
end
local ok,err=xpcall(function()
  e=require('editor').start(root,{prepare=function(project) vim.fn.mkdir(project..'/создано space','p') end})
  for _,name in ipairs({'file-create-order.lua','file-scan-delay.lua'}) do
    assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/'..name,e.dir..'/'..name))
  end
  e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
  e:input(':edit file_one.txt<CR>');e:wait('code',function() return e:current_ft()=='text' end)
  e:input(' E');e:wait('Files ready',function() return e:current_ft()=='neo-tree' and state().ready end)
  choose('создано space')
  assert(e:lua('return require("neo-tree").config.filesystem.scan_mode')=='shallow','Probe requires native shallow scan pipeline')
  result.before=state();assert(result.before.parent and not result.before.parent.expanded,'Initial folder must be collapsed')
  -- Libuv wrappers только в private child; original entries не меняются.
  e:lua([[local source=...;_G.forge_scan_delay=dofile(source).arm(vim.fn.getcwd())]],{root..'/tests/diagnostics/file-scan-delay.lua'})
  -- Настоящая внешняя запись вызывает штатный FS_EVENT, не synthetic refresh.
  local owned=assert(vim.uv.fs_realpath(e.project))
  assert(owned==assert(vim.uv.fs_realpath(e.project..'/создано space/..')))
  vim.fn.writefile({'watcher marker'},e.project..'/watcher-marker.txt')
  e:wait('one actual old root read held',function() return e:lua('return _G.forge_scan_delay.report().held') end)
  result.held=e:lua('return _G.forge_scan_delay.report()')
  assert(result.held.request_stack:find('fs_scan.lua',1,true),'Delayed IO must originate in native Neo-tree scanner')
  e:input('a');e:wait('native create input',function() return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i' end)
  e:input('<C-u>'..e.project..'/создано space/новый файл.txt<CR>')
  e:wait('native create popup closed',function() return e:current_ft()=='neo-tree' and not e:has_window('neo-tree-popup') end)
  e:wait('new child actually visible',function() local s=state();return s.ready and s.child and s.parent.expanded and table.concat(s.lines,'\n'):find('новый файл.txt',1,true) end)
  result.newer=state()
  -- Наблюдаем завершённые render после уже видимого child, без refresh.
  e:lua([[local events=require('neo-tree.events');_G.forge_order_renders={}
    events.subscribe({event=events.AFTER_RENDER,id='forge-create-order',handler=function(s)
      if s.name~='filesystem' then return end
      if #_G.forge_order_renders>=64 then return end
      local u=require('neo-tree.utils');local path=u.path_join(vim.fn.getcwd(),'создано space');local p=s.tree and s.tree:get_node(path)
      local c=s.tree and s.tree:get_node(u.path_join(path,'новый файл.txt'))
      _G.forge_order_renders[#_G.forge_order_renders+1]={ready=s._ready,child=c and c.path or false,
        parent=p and {loaded=p.loaded,expanded=p:is_expanded(),children=p:get_child_ids()} or false}
    end})
    _G.forge_scan_delay.release()]])
  e:wait('final native read completion queue drained',function() return e:lua('return _G.forge_scan_delay.report().drained') end)
  result.after=state();result.renders=e:lua('return _G.forge_order_renders')
  result.released=e:lua('return _G.forge_scan_delay.report()')
  result.disk_child=vim.uv.fs_stat(e.project..'/создано space/новый файл.txt')~=nil
  result.stale=false
  for _,v in ipairs(result.renders) do if v.ready and v.parent and v.parent.expanded and not v.child then result.stale=true end end
  assert(result.disk_child,'Actual created file must exist')
  result.installs=e:lua('return vim.g.forge_e2e_installs');assert(result.installs==0)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
end,debug.traceback)
result.ok=ok;result.error=not ok and tostring(err) or nil
if e then
  pcall(function() e:lua('if _G.forge_scan_delay then _G.forge_scan_delay.release() end') end)
  e:snapshot('controlled-real-io-order')
  vim.fn.writefile({vim.json.encode(result)},e.dir..'/file-create-order.json')
  io.stdout:write('artifacts: '..e.dir..'\n')
  local stopped,issue=pcall(e.stop,e,not ok and err or nil)
  assert(stopped,issue)
  assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'native root/API failure')
end
assert(ok,err)
print('Controlled native IO; stale expanded folder observed: '..tostring(result.stale))
