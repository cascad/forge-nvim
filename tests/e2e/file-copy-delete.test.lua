-- spec: IDE-FILE-3/4. Настоящие Files/Neo-tree, native input и filesystem.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e,report
local function path(name) return e.project..'/'..name end
local function exists(name) return vim.uv.fs_stat(path(name))~=nil end
local function lines(name) return vim.fn.readfile(path(name)) end
local function mode() return e.rpc:request('nvim_get_mode',{}).mode end
local function observe(label)
  local data=e:lua([[local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype=='' then out[#out+1]={buf=b,name=vim.api.nvim_buf_get_name(b),
      modified=vim.bo[b].modified,text=vim.api.nvim_buf_get_lines(b,0,-1,false),visible=vim.fn.bufwinid(b)} end end
    return {buffers=out,current=vim.api.nvim_get_current_win(),ft=vim.bo.filetype,installs=vim.g.forge_e2e_installs,
      dap=package.loaded.dap and package.loaded.dap.session()~=nil or false} ]])
  data.label=label;report.states[#report.states+1]=data
  vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-copy-delete.json')
  return data
end
local function own(name)
  local base=assert(vim.uv.fs_realpath(e.project)):gsub('\\','/')
  local target=assert(vim.uv.fs_realpath(path(name))):gsub('\\','/')
  if vim.fn.has('win32')==1 then base=base:lower();target=target:lower() end
  assert(target:sub(1,#base+1)==base..'/','destructive target outside owned project: '..target)
  report.owned[#report.owned+1]={name=name,resolved=target,project=base}
end
local function locator()
  return e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window();if not(s and s._ready and s.tree) then return {} end
    local row=vim.api.nvim_win_get_cursor(0)[1];local selected=s.tree:get_node(row);local nodes={}
    for i=1,vim.api.nvim_buf_line_count(0) do local n=s.tree:get_node(i)
      if n then nodes[#nodes+1]={row=i,name=n.name,path=n.path,expanded=n:is_expanded()} end end
    return {selected=selected and selected.name,selected_path=selected and selected.path,nodes=nodes}]])
end
local function tree()
  e:input(' we');e:wait('Files focus',function() return e:current_ft()=='neo-tree' end)
  e:wait('native tree ready',function() return #((locator()).nodes or {})>0 end)
end
local function choose(name,parent)
  e:wait('exact tree node '..name,function()
    local data=locator();if data.selected==name then return true end
    for _,n in ipairs(data.nodes or {}) do if n.name==name then e:input(n.row..'G');return false end end
    if parent then for _,n in ipairs(data.nodes or {}) do if n.name==parent then
      if data.selected~=parent then e:input(n.row..'G') elseif not n.expanded then e:input('l') end
      return false
    end end end
  end)
end
local function popup(key)
  e:input(key);e:wait('native input '..key,function() return e:current_ft()=='neo-tree-popup' and mode():sub(1,1)=='i' end)
end
local function warning()
  if e.rpc:request('nvim_get_mode',{}).blocking then return e:ack_warning('несохранён') end
  return false
end
local function finish_popup(answer)
  e:input(answer=='esc' and '<Esc>' or '<C-u>'..answer..'<CR>')
  e:wait('native popup closed',function()
    if warning() then return false end
    return not e:has_window('neo-tree-popup') and e:current_ft()=='neo-tree'
  end)
end
local function delete(name,answer)
  own(name)
  local count=#e.rpc.notifications
  e:input('d')
  local outcome
  e:wait('delete confirmation or unsaved guard',function()
    if warning() then return false end
    if e:current_ft()=='neo-tree-popup' and mode():sub(1,1)=='i' then outcome='confirm';return true end
    for i=count+1,#e.rpc.notifications do
      local n=e.rpc.notifications[i]
      if n.level==vim.log.levels.WARN and n.message:find('несохранён',1,true) then outcome='guard';return true end
    end
  end)
  report.decisions[#report.decisions+1]={name=name,outcome=outcome,answer=answer}
  if outcome=='confirm' then finish_popup(answer) end
end
local function at_file(name)
  local value=e:current_file()
  local current=vim.fs.normalize(value):gsub('\\','/')
  local target=vim.fs.normalize(path(name)):gsub('\\','/')
  if vim.fn.has('win32')==1 then current=current:lower();target=target:lower() end
  return current==target
end
local function open(name,hide)
  if e:current_ft()=='neo-tree' then e:input(' w0');e:wait('code focus',function() return e:current_ft()~='neo-tree' end) end
  if at_file(name) then return e:lua('return vim.api.nvim_get_current_buf()') end
  e:input(':'..(hide and 'hide ' or '')..'edit '..vim.fn.fnameescape(name)..'<CR>')
  e:wait('open '..name,function() return at_file(name) end)
  return e:lua('return vim.api.nvim_get_current_buf()')
end
local function changed(name,text)
  local buf=open(name);e:input('gg0i'..text..'<Esc>')
  e:wait('real modified buffer',function() return e:lua('return vim.bo[...].modified',{buf}) end)
  return buf,e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf})
end
local function retained(name,buf,text)
  T.eq(exists(name),true,'unsaved target was deleted: '..name)
  T.eq(e:lua('local b=...;return vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_is_loaded(b)',{buf}),true,'unsaved buffer was wiped')
  T.eq(e:lua('return vim.bo[...].modified',{buf}),true)
  T.eq(e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf}),text)
end
local function check(name,fn)
  if vim.env.FORGE_FILE_CASE and not name:find(vim.env.FORGE_FILE_CASE,1,true) then return end
  T.check(name,function()
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=150000,prepare=function(project)
        for _,dir in ipairs({'destination','папка источник','remove dir space/nested','edit-dir','edit-dir-neighbor'}) do vim.fn.mkdir(project..'/'..dir,'p') end
        for file,data in pairs({['исходник space.txt']='source disk payload',['папка источник/дочерний.txt']='directory payload',
          ['copy-me.txt']='typed payload',['occupied.txt']='occupied payload',['delete-me.txt']='delete payload',
          ['remove dir space/leaf.txt']='leaf payload',['remove dir space/nested/inside.txt']='nested payload',
          ['dirty.txt']='dirty disk payload',['edit-dir/child.txt']='child disk payload',
          ['edit-dir-neighbor/leaf.txt']='neighbor payload',['late.txt']='late disk payload'}) do vim.fn.writefile({data},project..'/'..file) end
      end})
      report={case=name,states={},owned={},decisions={}}
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/file-copy-delete.test.lua',e.dir..'/file-copy-delete.test.lua'))
      e:wait('real config ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':ASToggle<CR>');e:wait('autosave explicitly disabled',function() return e:lua('return require("auto-save").enabled()==false') end)
      open('file_one.txt');observe('initial');fn();local final=observe('final')
      T.eq(final.installs,0);T.eq(final.dap,false)
      for _,n in ipairs(e.rpc.notifications) do
        assert(n.level<vim.log.levels.ERROR or (report.allowed_error and n.message:find(report.allowed_error,1,true)),n.message)
      end
    end,debug.traceback)
    if e then
      report=report or {case=name};report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-copy-delete.json')
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
      local native,issue=pcall(function()
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result and e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
      end)
      if not native then ok=false;err=(err and tostring(err)..'\n' or '')..'Native cleanup: '..tostring(issue) end
      report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-copy-delete.json')
    end
    e=nil;assert(ok,err)
  end)
end

check('IDE-FILE-4 clipboard copy Unicode file preserves dirty source and edits independently',function()
  local buf,text=changed('исходник space.txt','UNSAVED_');tree();choose('исходник space.txt');e:input('y')
  e:wait('native clipboard populated',function() return e:lua('return vim.tbl_count(require("neo-tree.sources.manager").get_state_for_window().clipboard)>0') end)
  choose('destination');e:input('p');e:wait('real copy created',function() return exists('destination/исходник space.txt') end)
  T.eq(lines('destination/исходник space.txt'),{'source disk payload'});retained('исходник space.txt',buf,text)
  open('destination/исходник space.txt');e:input('GoCOPY_DESTINATION_EDIT<Esc>:write<CR>')
  e:wait('copy independently written',function() return lines('destination/исходник space.txt')[2]=='COPY_DESTINATION_EDIT' end)
  T.eq(lines('исходник space.txt'),{'source disk payload'});retained('исходник space.txt',buf,text)
end)
check('IDE-FILE-4 clipboard recursively copies Unicode directory',function()
  tree();choose('папка источник');e:input('y')
  e:wait('directory on clipboard',function() return e:lua('return vim.tbl_count(require("neo-tree.sources.manager").get_state_for_window().clipboard)>0') end)
  choose('destination');e:input('p');e:wait('real directory copy',function() return exists('destination/папка источник/дочерний.txt') end)
  T.eq(lines('destination/папка источник/дочерний.txt'),{'directory payload'})
  T.eq(lines('папка источник/дочерний.txt'),{'directory payload'});T.eq(lines('occupied.txt'),{'occupied payload'})
end)
check('IDE-FILE-4 typed copy Unicode name conflict and cancel preserve files',function()
  tree();choose('copy-me.txt');popup('c');finish_popup('копия name.txt')
  e:wait('typed copy created',function() return exists('копия name.txt') end)
  T.eq(lines('копия name.txt'),{'typed payload'});T.eq(lines('copy-me.txt'),{'typed payload'})
  choose('copy-me.txt');popup('c');finish_popup('esc')
  choose('copy-me.txt');popup('c');e:input('<C-u>occupied.txt<CR>')
  e:wait('native conflict asks another name',function() return e:current_ft()=='neo-tree-popup' and table.concat(e.rpc:screen_lines(),'\n'):find('already exists',1,true) end)
  finish_popup('esc');T.eq(lines('occupied.txt'),{'occupied payload'});T.eq(lines('copy-me.txt'),{'typed payload'})
end)
check('IDE-FILE-3 clean file cancel No and confirmed zoom selection',function()
  tree();choose('delete-me.txt');delete('delete-me.txt','esc');T.eq(exists('delete-me.txt'),true)
  choose('delete-me.txt');delete('delete-me.txt','n');T.eq(exists('delete-me.txt'),true)
  choose('file_one.txt');e:input(' wz');e:wait('actual tree zoom',function() return e:lua('return vim.api.nvim_win_get_config(0).relative')=='editor' end)
  choose('delete-me.txt');delete('delete-me.txt','y')
  e:wait('selected file deleted',function() return not exists('delete-me.txt') end)
  T.eq(lines('file_one.txt'),{'first file','NEEDLE_FORGE_E2E'});T.eq(lines('file_two.txt'),{'second file'})
  T.eq(e:lua('return vim.api.nvim_win_get_config(0).relative'),'')
end)
check('IDE-FILE-3 recursive directory cancel and confirmed delete stay owned',function()
  tree();choose('remove dir space');own('remove dir space/leaf.txt');own('remove dir space/nested/inside.txt')
  delete('remove dir space','n');T.eq(lines('remove dir space/nested/inside.txt'),{'nested payload'})
  choose('remove dir space');delete('remove dir space','y');e:wait('owned directory deleted',function() return not exists('remove dir space') end)
  T.eq(lines('occupied.txt'),{'occupied payload'});T.eq(exists('destination'),true)
end)
check('IDE-FILE-3 native root refusal preserves private project',function()
  tree();e:input('gg');e:wait('native root selected',function()
    local selected=locator().selected_path
    return selected and vim.fs.normalize(selected)==vim.fs.normalize(e.project)
  end)
  local selected=e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window();return s.tree:get_node().path]])
  T.eq(vim.fs.normalize(selected),vim.fs.normalize(e.project))
  report.allowed_error='Will not delete root node';local count=#e.rpc.notifications;e:input('d')
  e:wait('native root refusal',function()
    for i=count+1,#e.rpc.notifications do local n=e.rpc.notifications[i]
      if n.level==vim.log.levels.ERROR and n.message:find(report.allowed_error,1,true) then
        if e.rpc:request('nvim_get_mode',{}).blocking then e:input('<CR>');return false end
        return true
      end
    end
  end)
  T.eq(e:has_window('neo-tree-popup'),false);T.eq(lines('file_one.txt'),{'first file','NEEDLE_FORGE_E2E'})
  T.eq(lines('occupied.txt'),{'occupied payload'});T.eq(exists('edit-dir/child.txt'),true)
end)
check('IDE-FILE-3 dirty file is retained then saved native retry deletes it',function()
  local buf,text=changed('dirty.txt','UNSAVED_');report.target_buf=buf;observe('dirty-before')
  tree();choose('dirty.txt');delete('dirty.txt','y');observe('dirty-after-attempt');retained('dirty.txt',buf,text)
  T.eq(lines('dirty.txt'),{'dirty disk payload'});open('dirty.txt');e:input(':write<CR>')
  e:wait('explicit save complete',function() return not e:lua('return vim.bo[...].modified',{buf}) end)
  T.eq(lines('dirty.txt'),text);tree();choose('dirty.txt');delete('dirty.txt','y')
  e:wait('saved retry deletes',function() return not exists('dirty.txt') end)
end)
check('IDE-FILE-3 hidden dirty descendant blocks parent but not sibling prefix',function()
  local buf,text=changed('edit-dir/child.txt','HIDDEN_');report.target_buf=buf;open('file_one.txt',true)
  T.eq(e:lua('return vim.fn.bufwinid(...)',{buf}),-1);tree();choose('edit-dir');own('edit-dir/child.txt')
  delete('edit-dir','y');observe('hidden-after-attempt');retained('edit-dir/child.txt',buf,text)
  T.eq(lines('edit-dir/child.txt'),{'child disk payload'});choose('edit-dir-neighbor');own('edit-dir-neighbor/leaf.txt')
  delete('edit-dir-neighbor','y');e:wait('sibling prefix independently deleted',function() return not exists('edit-dir-neighbor') end)
  retained('edit-dir/child.txt',buf,text)
end)
check('IDE-FILE-3 modification during confirmation survives Yes',function()
  local buf=open('late.txt');report.target_buf=buf;tree();choose('late.txt');own('late.txt');popup('d')
  -- Реальная background правка через native buffer API, без подмены plugin.
  e:lua('vim.api.nvim_buf_set_lines(...,0,0,false,{"LATE_DIRTY"})',{buf})
  local text=e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf});observe('modified-during-confirmation')
  finish_popup('y');observe('late-after-yes');retained('late.txt',buf,text);T.eq(lines('late.txt'),{'late disk payload'})
end)
T.finish()
