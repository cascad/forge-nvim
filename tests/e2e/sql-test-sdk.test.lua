-- spec: IDE-SQL-8. Real native process E2E, no editor/UI PASS implied.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_SQL_TEST_DEPS or root..'/.tests/sql-test-deps'
local dir=root..'/.tests/sql-test-sdk/'..tostring(vim.uv.hrtime())..' ü space'
vim.fn.mkdir(dir,'p')
local function bytes(path) local f=assert(io.open(path,'rb'));local data=f:read('*a');f:close();return data end
local function write(path,data) local f=assert(io.open(path,'wb'));f:write(data);f:close() end
local function normalize(s) return s:gsub('\\','/') end
local manifest_bytes=bytes(deps..'/manifest.json');local manifest=vim.json.decode(manifest_bytes)
local relative=next(manifest.files);assert(relative and not next(manifest.files,relative),'One native runner expected')
local binary=deps..'/'..relative
assert(vim.fn.sha256(bytes(binary))==manifest.files[relative],'Payload hash')
for _,file in ipairs({'tests/e2e/sql-test-sdk.test.lua','tests/e2e/prepare_sql_test.py','scripts/sdk/sql-test/Cargo.toml','scripts/sdk/sql-test/Cargo.lock','scripts/sdk/sql-test/src/main.rs'}) do
  assert(vim.uv.fs_copyfile(root..'/'..file,dir..'/'..vim.fs.basename(file)))
end
write(dir..'/manifest.json',manifest_bytes)
local runs={}
local function run(name,script,exe,args)
  local path=dir..'/'..name..'.slt';if script then write(path,script) end
  local report=dir..'/'..name..'-report.json'
  local command=args or {exe or binary,'--report',report,'--',path}
  local job=vim.system(command,{text=true,env={PYTHONIOENCODING='utf-8'}})
  local result=job:wait(20000)
  local record={command=command,pid=job.pid,code=result.code,signal=result.signal,stdout=result.stdout,stderr=result.stderr}
  write(dir..'/'..name..'-process.json',vim.json.encode(record));runs[#runs+1]=record
  local data=vim.fn.filereadable(report)==1 and vim.json.decode(bytes(report)) or nil
  if data then T.eq(data.protocol,1);T.eq(normalize(data.file),normalize(path)) end
  return result,data,path
end
local function passed(name,script,checks)
  local r,data=run(name,script);T.eq(r.code,0,(r.stderr or '')..(r.stdout or ''))
  T.eq(data.status,'passed');T.eq(data.checks,checks);T.eq(#data.errors,0)
  return data
end
local function failed(name,script,line)
  local r,data=run(name,script);T.eq(r.code,1,(r.stderr or '')..(r.stdout or ''))
  T.eq(data.status,'failed');T.eq(data.errors[1].line,line)
  assert(data.output~='');return data
end
T.check('IDE-SQL-8 native SQLite setup values Unicode NULL real and expected error',function()
  passed('basic',bytes(root..'/tests/e2e/fixtures/sql-tests/basic.slt'),6)
end)
T.check('IDE-SQL-8 native assertion failure has expected actual and exact line',function()
  local data=failed('wrong expected','\nquery I\nSELECT 42;\n----\n43\n\n',2)
  assert(data.output:find('42',1,true) and data.output:find('43',1,true),data.output)
  T.eq(data.checks,0)
end)
T.check('IDE-SQL-8 parser error is a real failed report',function()
  failed('bad syntax','invalid record\n',1)
end)
T.check('IDE-SQL-8 empty and all skipped scripts cannot pass',function()
  for name,script in pairs({empty='# comment only\n',skipped='skipif sqlite\nquery I\nSELECT 42;\n----\n42\n\n'}) do
    local data=failed(name,script,1);T.eq(data.checks,0);assert(data.output:find('No SQL assertions',1,true),data.output)
  end
end)
T.check('IDE-SQL-8 scripts have independent DBs named connections share one script',function()
  local script='statement ok\nCREATE TABLE isolated (value INTEGER);\n\nstatement ok\nINSERT INTO isolated VALUES (7);\n\nconnection other\n\nquery I\nSELECT value FROM isolated;\n----\n7\n\n'
  passed('first isolated',script,3);passed('second isolated',script,3)
end)
T.check('IDE-SQL-8 include failure preserves script identity and actual error file',function()
  write(dir..'/child.slt','\nquery I\nSELECT 5;\n----\n6\n\n')
  local data=failed('include parent','include child.slt\n',2)
  T.eq(normalize(data.errors[1].file),normalize(dir..'/child.slt'))
end)
T.check('IDE-SQL-8 shell system extension fails explicitly',function()
  local data=failed('system','system ok\necho SHOULD_NOT_EXECUTE\n\n',1)
  assert(data.output:find('does not support SLT system commands',1,true),data.output)
end)
T.check('IDE-SQL-8 include parser error names actual included file',function()
  write(dir..'/bad-child.slt','\ninvalid record\n')
  local data=failed('include parser','include bad-child.slt\n',2)
  T.eq(normalize(data.errors[1].file),normalize(dir..'/bad-child.slt'))
end)
T.check('IDE-SQL-8 include unsupported command preserves root report identity',function()
  write(dir..'/system-child.slt','system ok\necho SHOULD_NOT_EXECUTE\n\n')
  local data=failed('include system','include system-child.slt\n',1)
  T.eq(normalize(data.errors[1].file),normalize(dir..'/system-child.slt'))
end)
local copy=dir..'/SDK without compiler scratch ü'
vim.fn.mkdir(vim.fs.dirname(copy..'/'..relative),'p')
assert(vim.uv.fs_copyfile(binary,copy..'/'..relative));write(copy..'/manifest.json',manifest_bytes)
local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Host Python needed for preparation CLI only')
local function readiness(name,output)
  local r=run(name,nil,nil,{python,'-B',root..'/tests/e2e/prepare_sql_test.py','--output',output,
    '--rustc',dir..'/missing-rustc','--cc',dir..'/missing-cc'})
  local pid=runs[#runs].pid;local prefix='forge-sql-test-sdk-'..pid..'-'
  if vim.fn.has('win32')==1 then
    for folder in vim.fs.dir(root..'/.tests/tmp') do assert(folder:sub(1,#prefix)~=prefix,'Leaked readiness profile '..folder) end
  end
  return r
end
T.check('IDE-SQL-8 readiness works without compiler Cargo cache target or scratch',function()
  local r=readiness('readiness',copy);T.eq(r.code,0,(r.stderr or '')..(r.stdout or ''))
  assert(r.stdout:find('Ready ',1,true),r.stdout)
  T.eq(bytes(copy..'/manifest.json'),manifest_bytes)
  T.eq(vim.fn.sha256(bytes(copy..'/'..relative)),manifest.files[relative])
  for _,name in ipairs({'target','cargo-home','tmp'}) do T.eq(vim.fn.isdirectory(copy..'/'..name),0) end
end)
T.check('IDE-SQL-8 corrupted manifest and missing SDK require explicit preparation',function()
  local corrupt=vim.deepcopy(manifest);corrupt.files[relative]=string.rep('0',64)
  write(copy..'/manifest.json',vim.json.encode(corrupt))
  local r=readiness('corrupted',copy);T.eq(r.code,2);assert(r.stderr:find('Hash native SQL test runner',1,true),r.stderr)
  write(copy..'/manifest.json',manifest_bytes)
  r=readiness('missing SDK',dir..'/not prepared');T.eq(r.code,2)
  assert(r.stderr:find('prepare_sql_test.py --download',1,true),r.stderr)
end)
T.check('IDE-SQL-8 manifest without payload gives actionable readiness error',function()
  local partial=dir..'/SDK manifest only';vim.fn.mkdir(partial,'p');write(partial..'/manifest.json',manifest_bytes)
  local r=readiness('missing payload',partial);T.eq(r.code,2,r.stderr)
  assert(r.stderr:find('prepare_sql_test.py --download',1,true),r.stderr)
  assert(not r.stderr:find('Traceback',1,true),r.stderr)
end)
T.eq(bytes(deps..'/manifest.json'),manifest_bytes,'Original SDK immutable')
T.eq(vim.fn.sha256(bytes(binary)),manifest.files[relative],'Original payload immutable')
io.stdout:write('  artifacts: '..dir..'\n')
T.finish()
