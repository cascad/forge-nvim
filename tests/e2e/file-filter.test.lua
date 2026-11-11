-- spec: IDE-FILE-5. Отфильтрованное дерево намеренно не содержит прежних папок.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e
local function state()
  return e:lua([[local s=require('neo-tree.sources.manager').get_state('filesystem');local rows={}
    if s and s.tree and vim.api.nvim_buf_is_valid(s.tree.bufnr) then
      for i=1,vim.api.nvim_buf_line_count(s.tree.bufnr) do local n=s.tree:get_node(i)
        if n then rows[#rows+1]={name=n.name,path=n.path,expanded=n:is_expanded()} end end
    end
    return {rows=rows,ready=s and s._ready,pattern=s and s.search_pattern,force=s and s.force_open_folders}]])
end
local function visible(name)
  for _,n in ipairs(state().rows) do if n.name==name then return true end end
  return false
end
local function check(name,expanded)
T.check(name,function()
  local report={case=name,states={}}
  local ok,err=xpcall(function()
    e=require('editor').start(root,{prepare=function(project)
      for _,dir in ipairs({'expanded','matches'}) do vim.fn.mkdir(project..'/'..dir,'p') end
      vim.fn.writefile({'alpha'},project..'/expanded/alpha.txt');vim.fn.writefile({'beta'},project..'/matches/beta.txt')
    end})
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/file-filter.test.lua',e.dir..'/file-filter.test.lua'))
    e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    e:input(' we');e:wait('Files ready',function() return e:current_ft()=='neo-tree' and state().ready end)
    for _,item in ipairs({{'neo-tree-fs_scan.lua','neo-tree.sources.filesystem.lib.fs_scan','get_items'},
      {'neo-tree-filesystem-init.lua','neo-tree.sources.filesystem','show_new_children'}}) do
      local source=e:lua([[local module,key=...;local path=debug.getinfo(require(module)[key],'S').source:sub(2)
        local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close();return raw]],{item[2],item[3]})
      local f=assert(io.open(e.dir..'/'..item[1],'wb'));assert(f:write(source));assert(f:close())
    end
    if expanded then e:wait('select expanded folder',function()
      local found=e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window()
        if s.tree:get_node().name=='expanded' then return {selected=true} end
        for i=1,vim.api.nvim_buf_line_count(0) do local n=s.tree:get_node(i)
          if n and n.name=='expanded' then return {row=i} end end;return {}]])
      if found.selected then return true end;if found.row then e:input(found.row..'G') end
    end)
    e:input('l');e:wait('alpha actually visible',function() return visible('alpha.txt') end)
    end
    report.states[#report.states+1]=state()
    e:input('f');e:wait('native filter input',function() return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i' end)
    e:input('<C-u>beta<CR>')
    e:wait('native filtered snapshot excludes alpha',function()
      return state().pattern=='beta' and visible('beta.txt') and not visible('alpha.txt')
    end)
    report.states[#report.states+1]=state()
    e:input('<C-x>');e:wait('clear restores explicit pre-search expansion',function()
      return not state().pattern and not visible('beta.txt') and visible('alpha.txt')==expanded
    end)
    report.states[#report.states+1]=state()
    assert(vim.fn.readfile(e.project..'/expanded/alpha.txt')[1]=='alpha')
    assert(vim.fn.readfile(e.project..'/matches/beta.txt')[1]=='beta')
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    assert(e:lua('return vim.g.forge_e2e_installs')==0)
    assert(e:lua('return require("dap").session()~=nil')==false)
  end,debug.traceback)
  if e then
    pcall(function() report.last=state() end)
    report.ok=ok;report.error=not ok and tostring(err) or nil
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-filter.json');e:snapshot('native-filter')
    io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,issue=pcall(e.stop,e,not ok and err or nil);assert(stopped,issue)
    assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'Native root/API failure')
  end
  e=nil;assert(ok,err)
end)
end
check('IDE-FILE-5 native filter excludes a previously expanded folder',true)
check('IDE-FILE-5 clear native filter restores a collapsed pre-search view',false)
T.finish()
