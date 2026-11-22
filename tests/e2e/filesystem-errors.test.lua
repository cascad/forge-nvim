-- spec: IDE-FILE-7. Native Files/OS errors, retained history and responsive input.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function tree(e,name)
  e:input(' we');e:wait('Files focus',function() return e:current_ft()=='neo-tree' end)
  e:wait('selected '..name,function() return e:lua([[local name=...;local s=require('neo-tree.sources.manager').get_state_for_window()
    if not(s and s._ready and s.tree) then return false end
    for row=1,vim.api.nvim_buf_line_count(0) do local n=s.tree:get_node(row)
      if n and n.name==name then vim.api.nvim_win_set_cursor(0,{row,0});return true end end;return false]],{name}) end)
end
local function prompt(e,key)
  e:input(key);e:wait('native prompt',function() return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
end
local function closed(e)
  e:wait('prompt closed',function() return not e:has_window('neo-tree-popup') and e:current_ft()=='neo-tree' end)
end
local function edit(e,tag)
  e:input('<F7>Go'..tag..'<Esc>:write<CR>')
  e:wait('native edit/save '..tag,function()
    return table.concat(vim.fn.readfile(e.project..'/file_one.txt'),'\n'):find(tag,1,true)~=nil
  end)
  assert(not e.rpc:request('nvim_get_mode',{}).blocking,'Unexpected modal prompt')
end
local function exists(e,name)return vim.fn.isdirectory(e.project..'/'..name)==1 end
local function check(name,fn)
  if vim.env.FORGE_FILES_ERROR_CASE and not name:find(vim.env.FORGE_FILES_ERROR_CASE,1,true) then return end
  T.check('IDE-FILE-7 '..name,function()
    local e
    local ok,why=xpcall(function()
      e=require('editor').start(root,{more=true,prepare=function(project)
        vim.fn.mkdir(project..'/empty-dir','p');vim.fn.mkdir(project..'/denied-dir','p')
        vim.fn.writefile({'pending file payload'},project..'/pending.txt')
      end})
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/filesystem-errors.test.lua',e.dir..'/test.lua'))
      e:input(':edit file_one.txt<CR>iRECENT_CODE_EDIT<Esc>')
      e:wait('code editable',function() return e:current_ft()=='text' end)
      fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      assert(not e.rpc:request('nvim_get_mode',{}).blocking)
      local state=e:lua([[return {messages=vim.fn.execute('messages'),mode=vim.api.nvim_get_mode(),
        spawns=_G.forge_e2e_spawns,notifications=vim.g.forge_e2e_notifications,logs=require('forge.log_store').memory,
        prompt_sync=_G.forge_prompt_sync,held=_G.forge_delete_held,deleted_events=_G.forge_delete_events}]])
      assert(not state.messages:find('E21:',1,true),state.messages)
      vim.fn.writefile({vim.json.encode(state)},e.dir..'/filesystem-errors.json')
    end,debug.traceback)
    if e then
      -- Release an actual OS handle/permission even after a failed assertion.
      pcall(vim.fn.writefile,{'release'},e.runtime..'/deny-release')
      e:snapshot('filesystem-errors');print('  artifacts: '..e.dir)
      local stopped,issue=pcall(e.stop,e,not ok and why or nil)
      if not stopped then ok=false;why=tostring(why or '')..'\nCleanup: '..tostring(issue) end
    end
    assert(ok,why)
  end)
end
check('empty directory cancel and repeated native delete',function(e)
  tree(e,'empty-dir');prompt(e,'d');e:input('<Esc>');closed(e);assert(exists(e,'empty-dir'))
  prompt(e,'d');e:input('n<CR>');closed(e);assert(exists(e,'empty-dir'))
  prompt(e,'d');e:input('y<CR>');closed(e);e:wait('empty deleted',function() return not exists(e,'empty-dir') end)
  edit(e,'AFTER_EMPTY_DELETE')
end)
check('prompt Enter does not synchronize completion',function(e)
  e:lua([[local cmp=require('cmp');local sync=cmp.core.filter.sync;_G.forge_prompt_sync=0
    cmp.core.filter.sync=function(self,...)
      if vim.bo.buftype=='prompt' then _G.forge_prompt_sync=_G.forge_prompt_sync+1 end
      return sync(self,...)
    end]])
  tree(e,'empty-dir');prompt(e,'d');e:input('n<CR>');closed(e)
  T.eq(e:lua('return _G.forge_prompt_sync'),0,'Prompt Enter called synchronous completion')
  edit(e,'AFTER_PROMPT_CANCEL')
end)
check('native error and long notification retain history without modal',function(e)
  e:input(':DefinitelyMissingForgeCommand<CR>')
  e:wait('native E492 retained',function() return e:lua([[return vim.fn.execute('messages'):find('E492:',1,true)~=nil]]) end)
  e:input(':lua vim.notify(string.rep("FS_ERROR_DETAILS "..string.rep("x",120).."\\n",80),vim.log.levels.ERROR)<CR>')
  e:wait('full diagnostic retained',function() return e:lua([[return vim.fn.execute('messages'):find('FS_ERROR_DETAILS',1,true)~=nil]]) end)
  edit(e,'AFTER_NATIVE_ERROR')
  e:input(' wi');e:wait('Logs show native error',function() return e:current_ft()=='forge-logs' and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('FS_ERROR_DETAILS',1,true)~=nil]]) end)
end)
check('actual OS denial preserves target edit and explicit retry',function(e)
  local python=vim.fn.has('win32')==1 and vim.json.decode(table.concat(vim.fn.readfile(root..'/.tests/python-deps/manifest.json'),'\n')).host_python or vim.fn.exepath('python3')
  local ready,release=e.runtime..'/deny-ready',e.runtime..'/deny-release'
  e:lua([[local argv=...;_G.forge_deny_process=vim.system(argv,{text=true},function(r) _G.forge_deny_result=r end)]],
    {{python,'-B',root..'/tests/e2e/fixtures/filesystem-errors/deny_delete.py',e.runtime,e.project..'/denied-dir',ready,release}})
  e:wait('real OS denial ready',function() return vim.fn.filereadable(ready)==1 end)
  assert(vim.uv.fs_copyfile(ready,e.dir..'/native-denial.json'))
  tree(e,'denied-dir');prompt(e,'d');e:input('y<CR>');closed(e)
  e:wait('native OS failure in Logs',function() return e:lua([[for _,v in ipairs(require('forge.log_store').memory) do
    if v.message:find('Could not remove',1,true) then return true end end;return false]]) end)
  assert(exists(e,'denied-dir'));edit(e,'WHILE_OS_DENIES')
  vim.fn.writefile({'release'},release)
  e:wait('native handle/permissions released',function() return e:lua('return _G.forge_deny_result and _G.forge_deny_result.code==0') end)
  tree(e,'denied-dir');prompt(e,'d');e:input('y<CR>');closed(e)
  e:wait('explicit retry deletes',function() return not exists(e,'denied-dir') end)
  edit(e,'AFTER_NATIVE_RETRY')
end)
check('held real delete completion leaves code usable',function(e)
  e:lua([[local function key(path) local value=vim.fs.normalize(path):gsub('\\','/');return vim.fn.has('win32')==1 and value:lower() or value end
    local target=key(...);local a=require('plenary.async');local native=vim.uv.fs_rmdir;local sync=vim.fn.system
    _G.forge_delete_events=0;_G.forge_delete_sync=0
    vim.fn.system=function(argv,...)
      if type(argv)=='table' and (tostring(argv[1]):lower():find('cmd.exe',1,true) and argv[3]=='rmdir' or argv[1]=='rm') then
        _G.forge_delete_sync=_G.forge_delete_sync+1
      end
      return sync(argv,...)
    end
    require('neo-tree.events').subscribe({event=require('neo-tree.events').FILE_DELETED,handler=function(path)
      if key(path)==target then _G.forge_delete_events=_G.forge_delete_events+1 end end})
    a.uv.fs_rmdir=a.wrap(function(path,callback)
      return native(path,function(err,result)
        if key(path)==target then
          _G.forge_delete_held={error=err or false,result=result}
          _G.forge_delete_release=function() callback(err,result) end
        else callback(err,result) end
      end)
    end,2)]],{e.project..'/empty-dir'})
  tree(e,'empty-dir');prompt(e,'d');e:input('y<CR>');closed(e)
  e:wait('native callback held or source synchronous delete detected',function()
    return e:lua('return _G.forge_delete_held~=nil or _G.forge_delete_sync>0')
  end)
  T.eq(e:lua('return _G.forge_delete_sync'),0,'Delete waited synchronously for OS command')
  assert(e:lua('return _G.forge_delete_held~=nil'),'Actual asynchronous IO callback was not used')
  T.eq(e:lua('return _G.forge_delete_events'),0)
  edit(e,'WHILE_DELETE_PENDING')
  e:lua('_G.forge_delete_release()')
  e:wait('one native completion',function() return e:lua('return _G.forge_delete_events')==1 end)
  assert(not exists(e,'empty-dir'));edit(e,'AFTER_DELETE_COMPLETION')
end)
check('edits made during actual unlink completion remain recoverable',function(e)
  e:input(':ASToggle<CR>:edit pending.txt<CR>')
  e:wait('explicit autosave off',function() return e:lua([[return require('auto-save').enabled()==false and vim.fn.expand('%:t')=='pending.txt']]) end)
  local buf=e:lua('return vim.api.nvim_get_current_buf()')
  e:lua([[local a=require('plenary.async');local native=vim.uv.fs_unlink
    local function key(p) return vim.fs.normalize(p):gsub('\\','/'):lower() end
    local target=key(...);_G.forge_unlink_events=0
    require('neo-tree.events').subscribe({event=require('neo-tree.events').FILE_DELETED,handler=function(path)
      if key(path)==target then _G.forge_unlink_events=_G.forge_unlink_events+1 end end})
    a.uv.fs_unlink=a.wrap(function(path,callback)
      return native(path,function(err,result)
        if key(path)==target then _G.forge_unlink_held=true;_G.forge_unlink_release=function() callback(err,result) end
        else callback(err,result) end
      end)
    end,2)]],{e.project..'/pending.txt'})
  tree(e,'pending.txt');prompt(e,'d');e:input('y<CR>');closed(e)
  e:wait('actual unlink completion held',function() return e:lua('return _G.forge_unlink_held==true') end)
  e:input('<F7>GoRECOVERABLE_PENDING_EDIT<Esc>')
  e:wait('new unsaved edit',function() return e:lua([[local b=...;return vim.bo[b].modified and
    table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n'):find('RECOVERABLE_PENDING_EDIT',1,true)~=nil]],{buf}) end)
  e:lua('_G.forge_unlink_release()')
  e:wait('one native unlink event',function() return e:lua('return _G.forge_unlink_events')==1 end)
  assert(e:lua('return vim.api.nvim_buf_is_valid(...) and vim.bo[...].modified',{buf}))
  T.eq(vim.fn.filereadable(e.project..'/pending.txt'),0)
  e:input(':write<CR>')
  e:wait('explicit save restores pending text',function() return vim.fn.filereadable(e.project..'/pending.txt')==1
    and table.concat(vim.fn.readfile(e.project..'/pending.txt'),'\n'):find('RECOVERABLE_PENDING_EDIT',1,true)~=nil end)
end)
T.finish()
