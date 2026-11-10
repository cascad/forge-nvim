-- spec: IDE-SQL-9. Настоящие SQLS/schema/keyboard references, без mock locations.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function save(path,value) vim.fn.writefile({vim.json.encode(value)},path) end
local function state(e)
  return e:lua([[return {mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
    notifications=vim.g.forge_e2e_notifications,installs=vim.g.forge_e2e_installs,
    sql_spawns=_G.forge_sql_spawns,requests=_G.forge_reference_requests,raw=_G.forge_reference_raw,
    clients=vim.tbl_map(function(c) return {name=c.name,root=c.root_dir,encoding=c.offset_encoding,
      initialized=c.initialized,references=c.server_capabilities.referencesProvider or false} end,vim.lsp.get_clients())} ]])
end
local function check(name,fn)
  if vim.env.FORGE_SQL_REFERENCE_CASE and not name:find(vim.env.FORGE_SQL_REFERENCE_CASE,1,true) then return end
  T.check('IDE-SQL-9 '..name,function()
    local e
    local ok,err=pcall(function()
      require('sql_project').start(root,function(child) e=child end,nil,{fixture='/tests/e2e/fixtures/sql-references'})
      for _,file in ipairs({'tests/e2e/sql-references.test.lua','tests/lib/sql_project.lua'}) do
        assert(vim.uv.fs_copyfile(root..'/'..file,e.dir..'/'..vim.fs.basename(file)))
      end
      assert(vim.uv.fs_copyfile(e.sql_deps..'/manifest.json',e.dir..'/sql-sdk-manifest.json'))
      local schema=[[import sqlite3,sys;d=sqlite3.connect(sys.argv[1]);d.executescript('CREATE TABLE accounts(id INTEGER PRIMARY KEY,owner_id INTEGER);INSERT INTO accounts VALUES(1,1);');d.close()]]
      for _,db in ipairs({'dev ü.sqlite3','second.sqlite3'}) do
        local r=vim.system({e.sql_python,'-B','-c',schema,e.sql_project..'/db/'..db},{text=true}):wait()
        assert(r.code==0,r.stderr)
      end
      e:input(':edit '..vim.fn.fnameescape(e.sql_project..'/current.sql')..'<CR>')
      e:wait('реальный SQLS и mapping готовы',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='sqls'})) do
        if c.initialized and vim.fn.maparg('gr','n',false,true).buffer==1 then return true end end;return false]]) end,30000)
      e:lua([[_G.forge_reference_requests={};vim.api.nvim_create_autocmd('LspRequest',{callback=function(ev)
        if ev.data.request.method=='textDocument/references' then
          _G.forge_reference_requests[#_G.forge_reference_requests+1]=vim.deepcopy(ev.data.request)
        end end})]])
      fn(e)
      local s=state(e);T.eq(s.installs,0);assert(not s.mode.blocking,'неожиданный prompt')
      assert(not s.messages:match('E%d%d%d+:'),s.messages)
      T.eq(require('sql_project').counter(e),0,'references не исполняет SQL')
      T.eq(#s.sql_spawns,1,'один SQLS backend')
    end)
    if e then
      local got,s=pcall(state,e);if got then save(e.dir..'/sql-reference-state.json',s) end
      if vim.fn.filereadable(e.log_lsp)==1 then assert(vim.uv.fs_copyfile(e.log_lsp,e.dir..'/lsp.log')) end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
check('schema column references через gr, closed file и quickfix Enter',function(e)
  e:input('2G0/, u.id<CR>4l')
  e:wait('курсор на первом символе настоящей u.id после Unicode',function()
    return e:lua([[local row,col=unpack(vim.api.nvim_win_get_cursor(0));local line=vim.api.nvim_get_current_line();
      local at=assert(line:find(', u.id',1,true));return row==2 and col==at+3]])
  end)
  -- Дополнительная запись настоящего backend reply; gr по-прежнему строит UI сам.
  e:lua([[local c=vim.lsp.get_clients({bufnr=0,name='sqls'})[1]
    local p=vim.lsp.util.make_position_params(0,c.offset_encoding);p.context={includeDeclaration=true}
    c.rpc.request('textDocument/references',p,function(err,result)
      _G.forge_reference_raw={error=err or false,result=result or false}
    end)]])
  e:wait('native references reply записан',function() return e:lua('return _G.forge_reference_raw~=nil') end,10000)
  save(e.dir..'/before-gr.json',state(e))
  e:input('gr')
  e:wait('semantic references не появились в quickfix',function() return e:current_ft()=='qf' end,12000)
  local refs=e:lua([[local out={};for _,r in ipairs(vim.fn.getqflist()) do
    out[#out+1]={path=vim.api.nvim_buf_get_name(r.bufnr):gsub('\\','/'),line=r.lnum,col=r.col}
    end;return out]])
  save(e.dir..'/quickfix-references.json',refs)
  local expected={}
  for _,file in ipairs({'current.sql','closed.sql'}) do
    for line,text in ipairs(vim.fn.readfile(e.sql_project..'/'..file)) do
      -- Независимые ожидаемые token ranges только на заранее заданных строках.
      if file=='closed.sql' or line==2 or line==4 or line==5 or line==7 then
        local pattern=file=='closed.sql' and 'person%.()id' or (line==7 and 'users%.()id' or ',? ?u%.()id')
        local from=1
        while true do
          local first,last,col=text:find(pattern,from);if not first then break end
          -- В line 2 literal содержит u.id: учитывается только после marker.
          if line~=2 or col>assert(text:find('AS marker',1,true)) then expected[#expected+1]={path=e.sql_project..'/'..file,line=line,col=col} end
          from=last+1
        end
      end
    end
  end
  T.eq(#expected,6,'fixture expected locations')
  local function key(r) return r.path..':'..r.line..':'..r.col end
  local actual,desired={},{}
  for _,r in ipairs(refs) do actual[#actual+1]=key(r) end
  for _,r in ipairs(expected) do desired[#desired+1]=key(r) end
  table.sort(actual);table.sort(desired);T.eq(actual,desired,'schema identity, not id text matches')
  local chosen
  for i,r in ipairs(refs) do if r.path==e.sql_project..'/closed.sql' then chosen=i;break end end
  assert(chosen,'closed SQL file отсутствует');local target=refs[chosen]
  e:input(tostring(chosen)..'G<CR>')
  e:wait('Enter открыл точный SQL identifier',function()
    return e:current_file()==target.path and
      e:lua([[local row,col=unpack(vim.api.nvim_win_get_cursor(0));local target=...;return row==target.line and col+1==target.col]],{target})
  end)
end)
T.finish()
