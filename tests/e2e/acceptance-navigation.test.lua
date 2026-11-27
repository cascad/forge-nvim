local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local e
local function normalize(p) return p:gsub('\\','/'):lower() end
local function tree_state()
  return e:lua([[local s=require('neo-tree.sources.manager').get_state('filesystem');
    local out={path=s.path,ready=s._ready,nodes={},expanded={}}
    if s.tree then
      local function walk(p) for _,n in ipairs(s.tree:get_nodes(p)) do
        if n.path then out.nodes[#out.nodes+1]=n.path;if n:is_expanded() then out.expanded[#out.expanded+1]=n.path end end
        if n:has_children() then walk(n:get_id()) end
      end end;walk()
      local n=s.tree:get_node();out.selected=n and n.path
    end;return out]])
end
local function choose(name)
  e:wait('visible node '..name,function()
    local row=e:lua([[local name=...;local s=require('neo-tree.sources.manager').get_state_for_window()
      for i=1,vim.api.nvim_buf_line_count(0) do local n=s and s.tree and s.tree:get_node(i)
        if n and n.name==name then return i end end;return false]],{name})
    if type(row)=='number' then e:input(row..'G');return e:lua('return vim.api.nvim_get_current_line()'):find(name,1,true) end
  end)
end
local function tree()
  e:input(' we');e:wait('Files focused',function() return e:current_ft()=='neo-tree' and tree_state().ready end)
end
local function prompt(key,value)
  e:input(key);e:wait('native filesystem prompt',function()
    return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i'
  end)
  e:input('<C-u>'..value..'<CR>');e:wait('native prompt returned',function() return e:current_ft()=='neo-tree' end)
end
local function visible(relative,expected)
  local target=normalize(e.project..'/'..relative)
  e:wait('Files disk truth '..relative..' '..tostring(expected),function()
    if not tree_state().ready then return false end
    local found=false;for _,p in ipairs(tree_state().nodes) do if normalize(p)==target then found=true end end
    return found==expected
  end)
end
local function expand(name)
  choose(name)
  for _,p in ipairs(tree_state().expanded) do if normalize(p)==normalize(e.project..'/'..name) then return end end
  e:input('l');e:wait('expanded '..name,function()
    for _,p in ipairs(tree_state().expanded) do if normalize(p)==normalize(e.project..'/'..name) then return true end end
  end)
end
local function focus_code()
  e:input('<F7>');e:wait('code focused',function() return e:current_ft()=='text' end)
end
local function open(relative)
  focus_code();e:input(':edit '..relative..'<CR>')
  e:wait('active file '..relative,function() return normalize(e:current_file())==normalize(e.project..'/'..relative) end)
end
local function check(name,fn)
  T.check(name,function()
    local ok,err=xpcall(function()
      e=require('editor').start(root,{prepare=function(project)
        for _,d in ipairs({'destination','sibling','branch/deep'}) do vim.fn.mkdir(project..'/'..d,'p') end
        for path,value in pairs({['tracked.txt']='tracked payload',['sibling/keep.txt']='keep',['branch/deep/reveal.txt']='reveal'}) do
          vim.fn.writefile({value},project..'/'..path)
        end
        vim.fn.writefile({'reveal','FORGE_FILES_MATCH_ON_LINE_TWO'},project..'/branch/deep/reveal.txt')
        for _,args in ipairs({{'add','.'},{'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','fixture'}}) do
          local argv={'git','-C',project};vim.list_extend(argv,args);local r=vim.system(argv,{text=true}):wait();assert(r.code==0,r.stderr)
        end
      end})
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':edit file_one.txt<CR>');e:wait('initial text file',function() return e:current_ft()=='text' end)
      fn()
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      if not ok then local captured,data=pcall(tree_state)
        vim.fn.writefile({vim.json.encode(captured and data or {error=tostring(data)})},e.dir..'/tree-debug.json') end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop();e=nil
    end
    assert(ok,err)
  end)
end

check('IDE-PANEL-31 palette repeated CtrlJ K retains row indentation',function()
  e:input('<C-S-p>');e:wait('command palette loaded',function()
    return e:current_ft()=='TelescopePrompt' and e:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf());return p and p.manager and p.manager:num_results()>5]])
  end)
  local function rows() return e:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
    local out={};for _,s in ipairs(vim.api.nvim_buf_get_lines(p.results_bufnr,0,-1,false)) do out[#out+1]=s:sub(3) end;return out]]) end
  local before=rows()
  for _=1,12 do e:input('<C-j>');e:lua('return true');e:input('<C-k>');e:lua('return true') end
  T.eq(rows(),before,'selection marker must not accumulate whitespace')
  e:input('<Esc>');e:wait('palette cancelled',function() return e:current_ft()=='text' end)
  e:input('gg0iAFTER_PALETTE<Esc>:write<CR>')
  e:wait('normal input restored',function() return vim.fn.readfile(e.project..'/file_one.txt')[1]:find('AFTER_PALETTE',1,true) end)
end)

check('IDE-PANEL-31 Ctrl+Shift+P executes ForgeLogs from Files',function()
  tree()
  local files_win=e:lua('return vim.api.nvim_get_current_win()')
  e:input('<C-S-p>')
  e:wait('command palette accepts input',function()
    return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i'
  end)
  e:input('ForgeLogs')
  e:wait('ForgeLogs is selected',function()
    return e:lua([[local entry=require('telescope.actions.state').get_selected_entry()
      return entry and entry.name=='ForgeLogs']])
  end)
  e:input('<CR>')
  e:wait('ForgeLogs command line allows optional source',function()
    return e:lua([[return vim.fn.getcmdtype()==':' and vim.trim(vim.fn.getcmdline())=='ForgeLogs']])
  end)
  e:input('<CR>')
  e:wait('selected command opened and focused Logs',function() return e:current_ft()=='forge-logs' end)
  T.eq(e:lua([[local win=...;return vim.api.nvim_win_is_valid(win)
    and vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='neo-tree']],{files_win}),true)
  focus_code()
  T.eq(normalize(e:current_file()),normalize(e.project..'/file_one.txt'))
end)

check('IDE-FILE-8 Unicode create copy cut with tracked source after navigate up',function()
  tree();e:input('u');e:wait('above working folder',function() return normalize(tree_state().path)~=normalize(e.project) and tree_state().ready end)
  choose(vim.fs.basename(e.project));e:input('l');visible('tracked.txt',true)
  choose(vim.fs.basename(e.project));prompt('a',e.project..'/новый файл.txt');visible('новый файл.txt',true)
  choose('tracked.txt');prompt('c','destination/копия файл.txt')
  expand('destination');visible('destination/копия файл.txt',true);visible('tracked.txt',true)
  choose('tracked.txt');e:input('x');choose('destination');e:input('p')
  visible('destination/tracked.txt',true);visible('tracked.txt',false)
  T.eq(vim.uv.fs_stat(e.project..'/tracked.txt'),nil)
  T.eq(vim.fn.readfile(e.project..'/destination/tracked.txt'),{'tracked payload'})
  -- Files has no Git decorations; Git source retains the deletion independently.
  T.eq(e:lua([[local function clean(c) for _,v in ipairs(c) do if v[1]=='git_status' then return false end
    if v.content and not clean(v.content) then return false end end;return true end
    return clean(require('neo-tree').config.filesystem.renderers.file)]]),true)
  e:input('bg');e:wait('Git source selected',function() return e:lua('return vim.b.neo_tree_source')=='git_status' end)
  e:wait('Git retains deleted tracked path',function()
    return e:lua([[local s=require('neo-tree.sources.manager').get_state_for_window();if not(s and s.tree) then return false end
      local name=require('neo-tree.utils').normalize_path(...);local n=s.tree:get_node(name);return n and n.path==name]],{e.project..'/tracked.txt'})
  end)
end)

check('IDE-FILE-9 tree root return preserves project and reveal sibling expansion',function()
  tree();expand('sibling');e:input('u')
  e:wait('tree above project',function() return normalize(tree_state().path)~=normalize(e.project) and tree_state().ready end)
  e:input('gR');e:wait('working root restored',function() return normalize(tree_state().path)==normalize(e.project) and tree_state().ready end)
  e:input('u');e:wait('above root for Russian shortcut',function() return normalize(tree_state().path)~=normalize(e.project) and tree_state().ready end)
  e:input('пК');e:wait('Russian physical gR restored root',function() return normalize(tree_state().path)==normalize(e.project) and tree_state().ready end)
  e:input('u');e:wait('above root for modified Cyrillic',function() return normalize(tree_state().path)~=normalize(e.project) and tree_state().ready end)
  e:input('п<S-К>');e:wait('Russian Shift event restored root',function() return normalize(tree_state().path)==normalize(e.project) and tree_state().ready end)
  T.eq(normalize(e:lua('return vim.fn.getcwd()')),normalize(e.project))
  -- Reveal previously opened paths twice: auto-follow may not collapse older ancestors.
  open('nested/file_three.txt');e:input(' E');e:wait('first reveal',function() return e:current_ft()=='neo-tree' and normalize(tree_state().selected or '')==normalize(e.project..'/nested/file_three.txt') end)
  expand('sibling');open('branch/deep/reveal.txt')
  -- Follow runs after a debounce while the user is still editing the second file.
  e:wait('background follow reached second file',function()
    return normalize(tree_state().selected or '')==normalize(e.project..'/branch/deep/reveal.txt')
  end)
  e:input(' <S-У>')
  e:wait('deep file revealed',function() return e:current_ft()=='neo-tree' and normalize(tree_state().selected or '')==normalize(e.project..'/branch/deep/reveal.txt') end)
  local expanded={};for _,p in ipairs(tree_state().expanded) do expanded[normalize(p)]=true end
  T.eq(expanded[normalize(e.project..'/sibling')],true,'unrelated explicit expansion retained')
  T.eq(expanded[normalize(e.project..'/nested')],true,'unrelated earlier reveal retained')
  local parent_visible=false
  for _,p in ipairs(tree_state().nodes) do if normalize(p)==normalize(e.project..'/branch/deep/reveal.txt') then parent_visible=true end end
  T.eq(parent_visible,true,'required ancestors expanded (including grouped native directories)')
end)

check('IDE-PANEL-31 searchable F1 and quick AltB preserve file target',function()
  open('file_two.txt');tree()
  e:input('<F1>');e:wait('searchable keymaps',function() return e:current_ft()=='TelescopePrompt' end)
  e:input('Explorer: reveal');e:wait('reveal shortcut discoverable',function()
    return e:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
      if not p.manager then return false end;for v in p.manager:iter() do if v.ordinal:find('Explorer: reveal',1,true) then return true end end;return false]])
  end)
  e:input('<Esc>');e:wait('first key search closed',function() return e:current_ft()=='neo-tree' end)
  e:input('<F1>');e:wait('key search reopened',function() return e:current_ft()=='TelescopePrompt' end)
  e:input('Explorer: return to project root');e:wait('local tree shortcut discoverable',function()
    return e:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
      if not p.manager then return false end;for v in p.manager:iter() do if v.ordinal:find('Explorer: return to project root',1,true) then return true end end;return false]])
  end)
  e:input('<Esc>');e:wait('keys cancelled to Files',function() return e:current_ft()=='neo-tree' end)
  e:input('<A-b>');e:wait('quick buffer picker',function() return e:current_ft()=='TelescopePrompt' end)
  e:input('file_one');e:wait('buffer search ready',function()
    return e:lua([[local v=require('telescope.actions.state').get_selected_entry();return v and v.bufnr and vim.api.nvim_buf_get_name(v.bufnr):find('file_one.txt',1,true)~=nil]])
  end)
  e:input('<CR>');e:wait('picked buffer in code',function() return e:current_ft()=='text' and e:current_file():find('file_one.txt',1,true) end)
  T.eq(e:has_window('neo-tree'),true)
end)

local function select_search_file(key,query,relative)
  e:input(key);e:wait('Telescope accepts input',function()
    return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i'
  end)
  e:input(query);e:wait('exact file is selected in search',function()
    return e:lua([[local entry=require('telescope.actions.state').get_selected_entry()
      local path=entry and (entry.path or entry.filename or entry.value)
      local function normalized(p) return vim.fs.normalize(p):lower() end
      return type(path)=='string' and normalized(vim.fn.fnamemodify(path,':p'))==normalized(...)]],{e.project..'/'..relative})
  end)
  e:input('<CR>');e:wait('selected file opens in code after Enter',function()
    return e:current_ft()=='text' and normalize(e:current_file())==normalize(e.project..'/'..relative)
  end)
end

local function find_file(relative) select_search_file('<C-p>',vim.fs.basename(relative),relative) end

check('IDE-FILE-11 Ctrl+P opens a different file in the focused code split',function()
  e:input(':vsplit file_two.txt<CR>')
  e:wait('second editor split focused',function() return normalize(e:current_file()):find('/file_two.txt',1,true)~=nil end)
  local win=e:lua('return vim.api.nvim_get_current_win()')
  find_file('branch/deep/reveal.txt')
  T.eq(e:lua('return vim.api.nvim_get_current_win()'),win)
  T.eq(e:lua([[return vim.fn.bufwinid(vim.fn.bufnr('file_one.txt'))>0]]),true)
end)

check('IDE-FILE-11 Ctrl+P from Files opens code and preserves the guarded panel',function()
  tree();e:wait('owner guard active in Files',function() return e:lua('return vim.wo.winfixbuf') end)
  local panel=e:lua('return {vim.api.nvim_get_current_win(),vim.api.nvim_get_current_buf()}')
  find_file('branch/deep/reveal.txt')
  T.eq(e:lua([[local w,b=...;return vim.api.nvim_win_is_valid(w)
    and vim.api.nvim_win_get_buf(w)==b and vim.wo[w].winfixbuf]],panel),true)
end)

check('IDE-FILE-11 text search from Logs opens the matching line in code',function()
  e:input(' wi');e:wait('Logs focused',function()
    return e:current_ft()=='forge-logs' and e:lua('return vim.wo.winfixbuf')
  end)
  select_search_file(' fg','FORGE_FILES_MATCH_ON_LINE_TWO','branch/deep/reveal.txt')
  T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)[1]'),2)
  T.eq(e:has_window('forge-logs'),true)
end)

check('IDE-FILE-9 late reveal cannot steal an active filesystem input',function()
  tree();open('nested/file_three.txt')
  local helper=root..'/tests/diagnostics/file-scan-delay.lua'
  assert(vim.uv.fs_copyfile(helper,e.dir..'/file-scan-delay.lua'))
  e:lua([[local helper=...;_G.forge_scan_delay=dofile(helper).arm(vim.fn.getcwd())]],{helper})
  e:input(' E');e:wait('actual reveal scan held',function() return e:lua('return _G.forge_scan_delay.report().held') end)
  e:input('a');e:wait('create input during pending reveal',function()
    return e:current_ft()=='neo-tree-popup' and e.rpc:request('nvim_get_mode',{}).mode:sub(1,1)=='i'
  end)
  e:lua('_G.forge_scan_delay.release()')
  e:wait('native reveal drained',function() return e:lua('return _G.forge_scan_delay.report().drained') end)
  T.eq(e:current_ft(),'neo-tree-popup','background reveal must not capture focus')
  T.eq(e.rpc:request('nvim_get_mode',{}).mode:sub(1,1),'i')
  e:input('<C-u>'..e.project..'/ввод сохранён.txt<CR>')
  e:wait('create completes after delayed reveal',function() return vim.uv.fs_stat(e.project..'/ввод сохранён.txt')~=nil end)
  e:wait('input returned to Files',function() return e:current_ft()=='neo-tree' end)
  visible('ввод сохранён.txt',true)
end)
T.finish()
