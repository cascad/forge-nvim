-- Private native SQLLogicTest workspace. Observers preserve real process results.
local M={}
local function bytes(path) local f=assert(io.open(path,'rb'));local data=f:read('*a');f:close();return data end
local function write(path,data) local f=assert(io.open(path,'wb'));f:write(data);f:close() end
function M.start(root,on_create,mode)
  local deps=vim.env.FORGE_E2E_SQL_TEST_DEPS or root..'/.tests/sql-test-deps'
  local manifest=vim.json.decode(bytes(deps..'/manifest.json'))
  for path,hash in pairs(manifest.files) do assert(vim.fn.sha256(bytes(deps..'/'..path))==hash,path) end
  local relative=next(manifest.files);local binary=deps..'/'..relative
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='')
  local environment={FORGE_SQLTEST_EXECUTABLE=binary}
  if mode=='mixed' then
    local bash_deps=vim.env.FORGE_E2E_BASH_DEPS or root..'/.tests/bash-deps'
    local bash=vim.json.decode(bytes(bash_deps..'/manifest.json'));environment.FORGE_BASH_EXECUTABLE=bash.bash
    for path,hash in pairs(bash.files) do if path:gsub('\\','/'):match('/bin/bats$') then
      environment.FORGE_BATS_EXECUTABLE=bash_deps..'/'..path
      assert(vim.fn.sha256(bytes(environment.FORGE_BATS_EXECUTABLE))==hash)
    end end
    assert(environment.FORGE_BATS_EXECUTABLE,'Prepared native Bats needed for real multi-adapter E2E')
  end
  local function audit(name)
    return "statement ok\nATTACH DATABASE 'run counts.sqlite3' AS audit;\n\nstatement count 1\nUPDATE audit.runs SET value = value + 1 WHERE name = '"..name.."';\n\n"
  end
  local e=require('editor').start(root,{timeout=45000,env=environment,
    prepare=function(project,env,runtime)
      local original=vim.env.FORGE_SQL_TEST_CLIENT_SOURCE
      if original then
        assert(vim.env.FORGE_E2E_CONFIG_SOURCE,'Client replay requires a full original config source')
        local data=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')
        local variants={['lua/neotest/client/init.lua']=original,['lua/neotest/lib/file/init.lua']=assert(vim.env.FORGE_SQL_TEST_FILE_SOURCE),
          ['lua/neotest/adapters/init.lua']=assert(vim.env.FORGE_SQL_TEST_ADAPTERS_SOURCE)}
        for _,spec in ipairs(vim.json.decode(bytes(root..'/nvim_forge/patches/plugins.json')).neotest.extra) do
          local source=assert(variants[spec.file])
          assert(vim.fn.sha256((bytes(source):gsub('\r\n','\n')))==spec.before_sha256,'Replay must be exact upstream source')
          assert(vim.uv.fs_copyfile(source,data..'/lazy/neotest/'..spec.file))
        end
      end
      local dir=project..'/SQL tests ü';vim.fn.mkdir(dir,'p')
      write(dir..'/basic.slt',audit('basic')..bytes(root..'/tests/e2e/fixtures/sql-tests/basic.slt'))
      write(dir.."/other ü quote'.slt",audit('other')..'statement ok\nCREATE TABLE items (id INTEGER);\n\nstatement ok\nINSERT INTO items VALUES (9);\n\nquery I\nSELECT id FROM items;\n----\n9\n')
      write(dir..'/wrong.slt',audit('wrong')..'query I\nSELECT 42;\n----\n43\n')
      if mode=='slow' then write(dir..'/slow.slt',audit('slow')..'sleep 30s\n\nquery I\nSELECT 7;\n----\n7\n') end
      if mode=='invalid' then write(dir..'/invalid.slt','invalid record\n');write(dir..'/empty.slt','# comment only\n') end
      if mode=='mixed' then write(dir..'/mixed.bats',[[@test "MIXED_NATIVE_BATS" {
  printf 'BATS_MIXED_DONE\n' >> "$BATS_TEST_DIRNAME/mixed-ran.txt"
  [ "$((2+2))" -eq 4 ]
}
]]) end
      if mode=='missing' then env.FORGE_SQLTEST_EXECUTABLE=runtime..'/not-installed-sqltest' end
      local script=[=[import sqlite3,sys
from pathlib import Path
p=Path(sys.argv[1]);d=sqlite3.connect(p/'run counts.sqlite3')
d.execute('CREATE TABLE runs(name TEXT PRIMARY KEY,value INTEGER NOT NULL)')
d.executemany('INSERT INTO runs VALUES(?,0)',[(n,) for n in ['basic','other','wrong','slow']]);d.commit();d.close()
]=]
      local r=vim.system({python,'-B','-c',script,dir},{text=true,env=env,clear_env=true}):wait();assert(r.code==0,r.stderr)
      r=vim.system({'git','init',dir},{text=true,env=env,clear_env=true}):wait();assert(r.code==0,r.stderr)
    end})
  if on_create then on_create(e) end
  local execute,input=e.lua,e.input
  function e:lua(code,args)
    write(self.dir..'/last-exec.lua',code..'\n-- Args: '..vim.inspect(args))
    local ok,result=pcall(execute,self,code,args)
    if not ok then
      if vim.fn.filereadable(self.dir..'/failed-exec.lua')==0 then
        write(self.dir..'/failed-exec.lua',code..'\n-- Args: '..vim.inspect(args)..'\n-- Error: '..tostring(result)) end
      error(result)
    end
    return result
  end
  function e:input(keys)
    write(self.dir..'/last-input.txt',keys)
    return input(self,keys)
  end
  e.sql_test_project=(e.project..'/SQL tests ü'):gsub('\\','/');e.sql_test_python=python
  vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/sql-test-dependencies.json')
  e.log_lsp=e:lua([[return vim.lsp.log.get_filename()]])
  e.log_state=e:lua([[return vim.fn.stdpath('log')]])
  local data=e:lua([[return vim.fn.stdpath('data')]])
  assert(vim.uv.fs_copyfile(data..'/lazy/neotest/lua/neotest/client/init.lua',e.dir..'/neotest-client-source.lua'))
  assert(vim.uv.fs_copyfile(data..'/lazy/neotest/lua/neotest/lib/file/init.lua',e.dir..'/neotest-file-source.lua'))
  assert(vim.uv.fs_copyfile(data..'/lazy/neotest/lua/neotest/adapters/init.lua',e.dir..'/neotest-adapters-source.lua'))
  e:input(':cd '..vim.fn.fnameescape(e.sql_test_project)..'<CR>')
  e:lua([[_G.forge_sqltest_jobs={};local nio=require('nio');local start=nio.fn.jobstart;
    nio.fn.jobstart=function(command,options)
      if type(command)~='table' or not command[1]:find('forge-sqltest',1,true) then return start(command,options) end
      local record={command=vim.deepcopy(command),cwd=options.cwd,report=command[3]};table.insert(_G.forge_sqltest_jobs,record)
      local exit=options.on_exit;options.on_exit=function(job,code,...)
        record.code=code
        if vim.g.forge_sqltest_corrupt_report and code==0 then
          local f=io.open(record.report,'rb');if f then local raw=f:read('*a');f:close()
            local backup=assert(io.open(record.report..'.native','wb'));backup:write(raw);backup:close()
            local corrupt=assert(io.open(record.report,'wb'));corrupt:write('{broken report');corrupt:close();record.corrupted=true
          end
        end
        return exit(job,code,...)
      end
      local job=start(command,options);record.job=job
      if job>0 then record.pid=vim.fn.jobpid(job) end
      return job
    end]])
  return e
end
function M.foreign(e)
  local target=(e.project..'/Foreign SQL ü'):gsub('\\','/');vim.fn.mkdir(target,'p')
  assert(vim.uv.fs_copyfile(e.sql_test_project..'/run counts.sqlite3',target..'/run counts.sqlite3'))
  write(target..'/foreign.slt',"statement ok\nATTACH DATABASE 'run counts.sqlite3' AS audit;\n\nstatement count 1\nUPDATE audit.runs SET value=value+1 WHERE name='basic';\n\nquery I\nSELECT 77;\n----\n77\n")
  local r=vim.system({'git','init',target},{text=true}):wait();assert(r.code==0,r.stderr)
  return target
end
function M.counters(e)
  local script="import json,sqlite3,sys;d=sqlite3.connect(sys.argv[1]);print(json.dumps(dict(d.execute('SELECT name,value FROM runs'))));d.close()"
  local r=vim.system({e.sql_test_python,'-B','-c',script,e.sql_test_project..'/run counts.sqlite3'},{text=true}):wait()
  assert(r.code==0,r.stderr);return vim.json.decode(r.stdout)
end
return M
