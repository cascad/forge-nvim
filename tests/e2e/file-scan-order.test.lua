-- spec: IDE-FILE-5. Настоящие native Files, IO и ввод; helper меняет только порядок ответа.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e,report
local helper=root..'/tests/diagnostics/file-scan-delay.lua'
local function state()
  return e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window();local nodes={};local rows={}
    local function info(n) return {name=n.name,path=n.path,loaded=n.loaded,expanded=n:is_expanded(),children=n:get_child_ids()} end
    if s and s.tree then
      local function collect(parent) for _,n in ipairs(s.tree:get_nodes(parent)) do nodes[#nodes+1]=info(n);collect(n:get_id()) end end;collect()
      for i=1,vim.api.nvim_buf_line_count(0) do local n=s.tree:get_node(i);if n then rows[#rows+1]={row=i,node=info(n)} end end
    end
    local selected=s and s.tree and s.tree:get_node()
    return {path=s and s.path,ready=s and s._ready,nodes=nodes,rows=rows,ft=vim.bo.filetype,
      selected=selected and selected.name,lines=vim.api.nvim_buf_get_lines(0,0,-1,false)}]])
end
local function node(name,s)
  for _,n in ipairs((s or state()).nodes) do if n.name==name then return n end end
end
local function checkpoint(label)
  local value=state();value.label=label;report.states[#report.states+1]=value
  vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-scan-order.json')
  return value
end
local function choose(name)
  e:wait('actual selected node '..name,function()
    local s=state();if s.selected==name then return true end
    for _,v in ipairs(s.rows) do if v.node.name==name then e:input(v.row..'G');break end end
  end)
end
local function visible(name,s)
  s=s or state();for _,r in ipairs(s.rows) do if r.node.name==name then return true end end
  return false
end
local function tree()
  e:input(' we');e:wait('Files ready',function() return e:current_ft()=='neo-tree' and state().ready end)
end
local function create(key,name)
  e:input(key);e:wait('native create input',function()
    return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i'
  end)
  e:input('<C-u>'..e.project..'/'..name..'<CR>')
  e:wait('native create returned',function() return e:current_ft()=='neo-tree' and not e:has_window('neo-tree-popup') end)
  e:wait('actual created disk path',function() return vim.uv.fs_stat(e.project..'/'..name)~=nil end)
end
local function arm(relative)
  local target=assert(vim.uv.fs_realpath(e.project..(relative and '/'..relative or '')))
  local project=assert(vim.uv.fs_realpath(e.project))
  assert(target==project or target:sub(1,#project+1)==project..(vim.fn.has('win32')==1 and '\\' or '/'),'Unowned IO target')
  e:lua([[local source,relative=...;_G.forge_scan_delay=dofile(source).arm(vim.fn.getcwd(),relative~='' and relative or nil)]],{helper,relative or ''})
end
local function held()
  e:wait('actual native final readdir held',function() return e:lua('return _G.forge_scan_delay.report().held') end)
  report.held=e:lua('return _G.forge_scan_delay.report()')
  assert(report.held.request_stack:find('fs_scan.lua',1,true),'Wrong native IO producer')
end
local function release()
  e:lua('_G.forge_scan_delay.release()')
  e:wait('native completion queue drained',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then
      report.prompts[#report.prompts+1]=table.concat(e.rpc:screen_lines(),'\n');e:input('<CR>');return false
    end
    return e:lua('return _G.forge_scan_delay.report().drained')
  end)
  report.released=e:lua('return _G.forge_scan_delay.report()')
  assert(report.released.restored and report.released.released)
end
local function edit_selected(name,text)
  choose(vim.fs.basename(name));e:input('<CR>');e:wait('native Enter opened child',function() return e:current_ft()=='text' end)
  e:input('gg0i'..text..'<Esc>:write<CR>')
  e:wait('native write reached disk',function() return vim.fn.readfile(e.project..'/'..name)[1]==text end)
end
local function check(name,fn,initial_file)
  T.check(name,function()
    local ok,err=xpcall(function()
      e=require('editor').start(root,{prepare=function(project)
        for _,dir in ipairs({'создано space','folder-A','folder-B','next-root'}) do vim.fn.mkdir(project..'/'..dir,'p') end
        for path,text in pairs({['folder-A/alpha.txt']='alpha',['folder-B/beta.txt']='beta',['next-root/inside.txt']='inside'}) do vim.fn.writefile({text},project..'/'..path) end
      end})
      report={case=name,states={},prompts={}}
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/file-scan-order.test.lua',e.dir..'/file-scan-order.test.lua'))
      assert(vim.uv.fs_copyfile(helper,e.dir..'/file-scan-delay.lua'))
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      if initial_file then e:input(':edit file_one.txt<CR>');e:wait('code before Files',function() return e:current_ft()=='text' end) end
      tree()
      local scanner=e:lua([[local p=debug.getinfo(require('neo-tree.sources.filesystem.lib.fs_scan').get_items,'S').source:sub(2)
        local f=assert(io.open(p,'rb'));local text=f:read('*a');f:close();return text]])
      local saved=assert(io.open(e.dir..'/neo-tree-fs_scan.lua','wb'));assert(saved:write(scanner));assert(saved:close())
      report.scanner_sha256=vim.fn.sha256((scanner:gsub('\r\n','\n')))
      checkpoint('initial');fn();checkpoint('final')
      T.eq(report.prompts,{},'unexpected blocking native error')
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      T.eq(e:lua('return require("dap").session()~=nil'),false)
    end,debug.traceback)
    if e then
      pcall(function() e:lua('if _G.forge_scan_delay then _G.forge_scan_delay.release() end') end)
      report=report or {case=name};report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-scan-order.json');e:snapshot(name)
      io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,issue=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\n'..tostring(issue) end
      if e.rpc.exit_code~=0 or e.rpc.exit_signal~=0 or #e.rpc.api_errors~=0 then ok=false;err=tostring(err or '')..'\nNative root/API error' end
      report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/file-scan-order.json')
    end
    e=nil;assert(ok,err)
  end)
end

check('IDE-FILE-5 ordinary Unicode A a Enter edit save',function()
  e:input('gg');create('A','новый каталог');choose('новый каталог');create('a','новый каталог/обычный.txt')
  e:wait('ordinary child visible',function() return visible('обычный.txt') end)
  edit_selected('новый каталог/обычный.txt','ORDINARY_WRITE')
end)
check('IDE-FILE-5 old full root cannot erase newer child and subsequent updates',function()
  choose('создано space');T.eq(node('создано space').expanded,false);arm()
  vim.fn.writefile({'real watcher'},e.project..'/watcher-marker.txt');held()
  create('a','создано space/новый файл.txt')
  e:wait('new full result visible',function() return visible('новый файл.txt') end);checkpoint('newer-before-old-release')
  release();local after=checkpoint('after-old-full-root')
  assert(visible('новый файл.txt',after),'stale full-root completion erased newer child')
  T.eq(node('создано space',after).loaded,true);T.eq(node('создано space',after).expanded,true)
  edit_selected('создано space/новый файл.txt','ORDER_WRITE')
  tree();choose('создано space');create('a','создано space/second.txt')
  e:wait('subsequent native create visible',function() return visible('second.txt') end)
  vim.fn.writefile({'external watcher'},e.project..'/создано space/watched.txt')
  e:wait('subsequent real watcher visible',function() return visible('watched.txt') end)
  T.eq(vim.fn.readfile(e.project..'/создано space/новый файл.txt'),{'ORDER_WRITE'})
end)
local function independent_partials()
  -- Публичная policy always только в этом control делает normal l асинхронным.
  e:lua('require("neo-tree.sources.manager").get_state_for_window().async_directory_scan="always"')
  choose('folder-A');arm('folder-A');e:input('l');held()
  choose('folder-B');e:input('l');e:wait('second folder rendered first',function() return visible('beta.txt') end)
  checkpoint('second-partial-before-first');release();local after=checkpoint('after-independent-partials')
  assert(visible('alpha.txt',after) and visible('beta.txt',after),'independent partial load discarded')
end
check('IDE-FILE-5 independent partial folders preserve both completed results',independent_partials)
check('IDE-FILE-5 old partial cannot overwrite a newer root',function()
  e:lua('require("neo-tree.sources.manager").get_state_for_window().async_directory_scan="always"')
  choose('folder-A');arm('folder-A');e:input('l');held()
  e:input(':Neotree filesystem dir='..e.project..'/next-root<CR>')
  e:wait('new root rendered',function() return visible('inside.txt') and not node('folder-A') end)
  checkpoint('new-root-before-old-partial');release();local after=checkpoint('after-obsolete-partial')
  assert(visible('inside.txt',after) and not node('alpha.txt',after),'old partial corrupted new root')
  assert(vim.uv.fs_stat(e.project..'/folder-A/alpha.txt'))
end)
check('IDE-FILE-5 partial folders also survive pending initial reveal',independent_partials,true)
T.finish()
