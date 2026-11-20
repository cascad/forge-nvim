-- spec: IDE-BOOT-34 IDE-SQL-10. Upstream binary, native LSP/Conform, no database SDK.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local filter=vim.env.FORGE_TEST_ID
if filter and filter~='' and not (T.matches('IDE-BOOT-34',filter) or T.matches(filter,'IDE-BOOT-34') or T.matches('IDE-SQL-10',filter)) then T.finish();return end
local deps=vim.env.FORGE_E2E_SQL_DEPS or root..'/.tests/sql-deps'
local win=vim.fn.has('win32')==1
local binary=deps..'/bin/sqruff'..(win and '.exe' or '')
assert(vim.fn.executable(binary)==1,'Prepare upstream Sqruff explicitly')
local function json(path,data)
  vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile({vim.json.encode(data)},path)==0)
end
local function check(name,fn)
  if vim.env.FORGE_SQL_BASIC_CASE and not name:find(vim.env.FORGE_SQL_BASIC_CASE,1,true) then return end
  T.check('IDE-BOOT-34 '..name,function()
    local e
    local ok,err=xpcall(function()
      e=require('editor').start(root,{site=deps..'/site',timeout=90000,prepare=function(project,env,runtime)
        local directory=project..'/upstream tools with spaces';vim.fn.mkdir(directory,'p')
        local copy=directory..'/sqruff'..(win and '.exe' or '')
        assert(vim.uv.fs_copyfile(binary,copy));if not win then assert(vim.uv.fs_chmod(copy,493)) end
        json(project..'/.fride/tools.json',{tools={sqruff='./upstream tools with spaces/'..vim.fs.basename(copy)}})
        env.FORGE_SQRUFF_EXECUTABLE=runtime..'/missing fallback sqruff'
        env.FORGE_SQLS_EXECUTABLE=runtime..'/absent sqls'
        vim.fn.writefile({'[sqruff]','dialect = ansi','[sqruff:rules:capitalisation.keywords]','capitalisation_policy = upper'},project..'/.sqruff')
        vim.fn.writefile({'select 1 as value;'},project..'/basic.sql')
        vim.fn.mkdir(project..'/other/.git','p')
        json(project..'/other/.fride/tools.json',{tools={sqruff='./absent other sqruff'}})
        vim.fn.writefile({'other project'},project..'/other/file.txt')
      end})
      e:wait('editor ready',function() return e:lua('return _G.forge_e2e_observed') end,12000)
      fn(e)
      local state=e:lua([[return {installs=vim.g.forge_e2e_installs,spawns=_G.forge_e2e_spawns,
        protocol=package.loaded['forge.sql_protocol']~=nil,connections=package.loaded['forge.sql']~=nil} ]])
      T.eq(state.installs,0);T.eq(state.protocol,false);T.eq(state.connections,false)
      for _,spawn in ipairs(state.spawns) do
        local name=vim.fs.basename(spawn.cmd):lower():gsub('%.exe$','')
        assert(not vim.tbl_contains({'sqls','forge-sqltest','go','cargo','rustc'},name),'Unexpected SQL prerequisite: '..spawn.cmd)
      end
      json(e.dir..'/sql-basic-state.json',state)
    end,debug.traceback)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local closed,why=pcall(e.stop,e,not ok and err or nil)
      if not closed then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
    end
    assert(ok,err)
  end)
end
local function open(e)
  e:input(':edit basic.sql<CR>')
  e:wait('native Sqruff attached',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='sqruff'})) do
    if c.initialized then return true end end;return false]]) end,15000)
end
local function formatted(e,buf)
  return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(...,0,-1,false),'\n')]],{buf or 0})
end
check('SQL lint and format without database',function(e)
  open(e)
  e:wait('upstream lint diagnostics',function() return e:lua([[return #vim.diagnostic.get(0)>0]]) end,15000)
  e:input(' lf')
  e:wait('upstream formatter',function() return formatted(e):find('SELECT 1 AS value;',1,true)~=nil end,10000)
  e:input(':ForgeToolPaths<CR>');e:wait('Sqruff path in logs',function() return e:current_ft()=='forge-logs' end)
  local body=formatted(e)
  assert(body:find('sqruff',1,true) and body:find('upstream tools with spaces',1,true),body)
end)
check('background formatter context and invalid explicit path',function(e)
  open(e)
  local buffer=e:lua([[return vim.api.nvim_get_current_buf()]])
  e:input(':edit other/file.txt<CR>');e:wait('other project',function() return e:current_ft()=='text' end)
  e:lua([[require('conform').format({bufnr=...,async=false,lsp_format='never'})]],{buffer})
  assert(formatted(e,buffer):find('SELECT 1 AS value;',1,true),formatted(e,buffer))
  local result=e:lua([[local ok,err=pcall(require('forge.sql_language').tool,'sqruff');return {ok=ok,error=tostring(err)}]])
  T.eq(result.ok,false);assert(result.error:find('project:',1,true),result.error)
end)
check('IDE-SQL-10 SQL extras are absent while native editing and Tests work',function(e)
  open(e)
  local removed=e:lua([[local modules={};for _,name in ipairs({'forge.sql','forge.sql_protocol',
    'forge.sql_diagnostics','forge.sql_tests','ide.sql','forge.native_tools'})do
    modules[name]=package.loaded[name]~=nil
  end;return {modules=modules,run=vim.fn.exists(':SQLRun'),connect=vim.fn.exists(':SQLConnect'),
    stop=vim.fn.exists(':SQLStop'),results=require('ide').registry.get('sql.results')~=nil,
    connect_map=vim.fn.maparg(' jc','n'),results_map=vim.fn.maparg(' jo','n')} ]])
  T.eq(removed.run,0);T.eq(removed.connect,0);T.eq(removed.stop,0);T.eq(removed.results,false)
  T.eq(removed.connect_map,'');T.eq(removed.results_map,'')
  for name,loaded in pairs(removed.modules)do T.eq(loaded,false,'Removed module loaded: '..name)end
  e:input(' wt');e:wait('native Tests panel',function()return e:current_ft()=='neotest-summary'end,12000)
  T.eq(e:lua([[return package.loaded['forge.sql_tests']~=nil]]),false)
  e:input('<F7>');e:wait('SQL code focus',function()return e:current_ft()=='sql'end)
  e:input('Go-- SQL_EDITOR_STILL_WORKS<Esc>:write<CR>')
  e:wait('native edit/save',function()return e:lua([[return not vim.bo.modified and
    table.concat(vim.fn.readfile('basic.sql'),'\n'):find('SQL_EDITOR_STILL_WORKS',1,true)~=nil]])end)
end)
T.finish()
