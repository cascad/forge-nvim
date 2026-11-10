-- Private SQL workspace и настоящие SQLite fixtures, без mock DB/LSP.
local M={}
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function copy(from,to)
  vim.fn.mkdir(to,'p')
  for name,kind in vim.fs.dir(from) do
    if kind=='directory' then copy(from..'/'..name,to..'/'..name)
    elseif kind=='file' then assert(vim.uv.fs_copyfile(from..'/'..name,to..'/'..name))
    else error('Неожиданный тип SQL fixture '..name) end
  end
end
function M.start(root,on_create,missing,options)
  options=options or {}
  local deps=vim.env.FORGE_E2E_SQL_DEPS or root..'/.tests/sql-deps'
  local manifest=read(deps..'/manifest.json')
  for path,hash in pairs(manifest.files) do
    local f=assert(io.open(deps..'/'..path,'rb'));local raw=f:read('*a');f:close();assert(vim.fn.sha256(raw)==hash,'Изменён SQL payload '..path)
  end
  local win=vim.fn.has('win32')==1;local suffix=win and '.exe' or '';local sep=win and ';' or ':'
  local python=vim.fn.exepath(win and 'python' or 'python3');assert(python~='','Нужен host Python sqlite3 для fixtures')
  local path={deps..'/bin'}
  for _,dir in ipairs(vim.split(vim.env.PATH or '',sep,{plain=true,trimempty=true})) do
    local foreign=false
    for _,name in ipairs({'sqls','sqruff'}) do for _,ext in ipairs(win and {'','.exe','.cmd','.bat'} or {''}) do
      if vim.fn.filereadable(dir..'/'..name..ext)==1 then foreign=true end
    end end
    if not foreign then path[#path+1]=dir end
  end
  local e=require('editor').start(root,{timeout=45000,site=deps..'/site',env={PATH=table.concat(path,sep),
    FORGE_SQLS_EXECUTABLE=deps..'/bin/sqls'..suffix,FORGE_SQRUFF_EXECUTABLE=deps..'/bin/sqruff'..suffix},
    prepare=function(project,env,runtime)
      local dir=project..'/SQL workspace ü';copy(root..(options.fixture or '/tests/e2e/fixtures/sql-language'),dir)
      local script=[[
import json,sqlite3,sys
from pathlib import Path
p=Path(sys.argv[1]);(p/'db').mkdir()
profiles=[]
for name,person,extra in [('dev ü.sqlite3','Alice',''),('second.sqlite3','Bob',', extra_column TEXT')]:
 d=sqlite3.connect(p/'db'/name)
 d.executescript('CREATE TABLE users(id INTEGER PRIMARY KEY,name TEXT NOT NULL'+extra+');CREATE TABLE counters(value INTEGER NOT NULL);INSERT INTO counters VALUES(0);')
 d.execute('INSERT INTO users(id,name) VALUES(1,?)',(person,));d.execute('INSERT INTO users(id,name) VALUES(2,?)',('Second row',));d.commit();d.close()
 profiles.append({'alias':'Dev ü' if not extra else 'Second','driver':'sqlite3','dataSourceName':'file:db/'+name+'?mode=rw&_busy_timeout=15000'})
(p/'.sqls.json').write_text(json.dumps({'connections':profiles},ensure_ascii=False)+'\n',encoding='utf-8')
]]
      local result=vim.system({python,'-B','-c',script,dir},{text=true,env=env,clear_env=true}):wait();assert(result.code==0,result.stderr)
      local init=vim.system({'git','init',dir},{text=true,env=env,clear_env=true}):wait();assert(init.code==0,init.stderr)
      vim.fn.writefile({'.sqls.json','db/'},dir..'/.gitignore')
      if missing=='tools' then env.FORGE_SQLS_EXECUTABLE=runtime..'/absent-sqls';env.FORGE_SQRUFF_EXECUTABLE=runtime..'/absent-sqruff'
      elseif missing=='config' then assert(vim.fn.delete(dir..'/.sqls.json')==0)
      elseif missing=='database' then local cfg=read(dir..'/.sqls.json');cfg.connections[1].dataSourceName='file:db/missing.sqlite3?mode=rw';vim.fn.writefile({vim.json.encode(cfg)},dir..'/.sqls.json') end
    end})
  if on_create then on_create(e) end
  e.sql_project=(e.project..'/SQL workspace ü'):gsub('\\','/');e.sql_python=python;e.sql_deps=deps
  e.log_lsp=e:lua([[return vim.lsp.log.get_filename()]])
  e.sql_exit_log=e.dir..'/sqls-native-exits.jsonl'
  vim.fn.writefile({},e.sql_exit_log)
  e:lua([[local exit_log=...;vim.lsp.log.set_level('debug');_G.forge_sql_spawns={};local spawn=vim.uv.spawn;
    local function pack(...) return {n=select('#',...),...} end
    vim.uv.spawn=function(cmd,opts,on_exit)
      local name=cmd:gsub('\\','/'):lower()
      if not (name:match('/sqls%.exe$') or name:match('/sqls$')) then return spawn(cmd,opts,on_exit) end
      local record={cmd=cmd,args=opts.args}
      local result=pack(spawn(cmd,opts,function(code,signal)
        record.code=code;record.signal=signal
        local file,err=vim.uv.fs_open(exit_log,'a',384)
        if file then
          local _,write_error=vim.uv.fs_write(file,vim.json.encode({pid=record.pid,code=code,signal=signal})..'\n',-1)
          vim.uv.fs_close(file);record.exit_log_error=write_error
        else record.exit_log_error=err end
        if on_exit then return on_exit(code,signal) end
      end))
      record.pid=result[2];_G.forge_sql_spawns[#_G.forge_sql_spawns+1]=record
      return unpack(result,1,result.n)
    end]],{e.sql_exit_log})
  e:lua([[_G.forge_sql_events={};vim.api.nvim_create_autocmd({'WinEnter','WinClosed','BufEnter','FileType'}, {callback=function(ev)
    local all=_G.forge_sql_events;all[#all+1]={event=ev.event,match=ev.match,buf=ev.buf,win=vim.api.nvim_get_current_win(),ft=vim.bo.filetype};
    if #all>250 then table.remove(all,1) end end})]])
  vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/sql-dependencies.json')
  assert(vim.uv.fs_copyfile(root..'/tests/e2e/sql-tools/sources.json',e.dir..'/sql-sources.json'))
  e:input(':cd '..vim.fn.fnameescape(e.sql_project)..'<CR>')
  return e
end
function M.counter(e,second)
  local script=[[import sqlite3,sys;d=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True);print(d.execute('SELECT value FROM counters').fetchone()[0]);d.close()]]
  local r=vim.system({e.sql_python,'-B','-c',script,e.sql_project..'/db/'..(second and 'second.sqlite3' or 'dev ü.sqlite3')},{text=true}):wait()
  assert(r.code==0,r.stderr);return tonumber(vim.trim(r.stdout))
end
function M.other_workspace(e,name)
  local target=(e.project..'/'..(name or 'Other SQL ü')):gsub('\\','/')
  vim.fn.mkdir(target..'/db','p')
  for _,file in ipairs({'.sqls.json','.sqruff','aliases.sql','db/dev ü.sqlite3','db/second.sqlite3'}) do
    assert(vim.uv.fs_copyfile(e.sql_project..'/'..file,target..'/'..file))
  end
  return target
end
return M
