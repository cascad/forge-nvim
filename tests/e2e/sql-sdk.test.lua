-- spec: IDE-SQL-5. Реальный native preparation CLI: immutable SDK readiness.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_SQL_DEPS or root..'/.tests/sql-deps'
local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Нужен host Python')
local script=vim.env.FORGE_SQL_PREPARE_SOURCE or root..'/tests/e2e/prepare_sql.py'
local function bytes(path) local f=assert(io.open(path,'rb'));local data=f:read('*a');f:close();return data end
local manifest_bytes=bytes(deps..'/manifest.json')
local manifest=vim.json.decode(manifest_bytes)
local dir=root..'/.tests/sql-sdk/'..tostring(vim.uv.hrtime());local copy=dir..'/SDK without build scratch ü'
vim.fn.mkdir(copy,'p')
assert(vim.uv.fs_copyfile(root..'/tests/e2e/sql-sdk.test.lua',dir..'/sql-sdk.test.lua'))
assert(vim.uv.fs_copyfile(script,dir..'/prepare-source.py'))
vim.fn.writefile({vim.json.encode({script=script,sha256=vim.fn.sha256(bytes(script)),sdk_manifest=manifest})},dir..'/provenance.json')
local function link(from,to)
  vim.fn.mkdir(vim.fs.dirname(to),'p')
  local ok=vim.uv.fs_link(from,to)
  if not ok then assert(vim.uv.fs_copyfile(from,to)) end
end
assert(vim.uv.fs_copyfile(deps..'/manifest.json',copy..'/manifest.json'))
for file in pairs(manifest.files) do link(deps..'/'..file,copy..'/'..file) end
local sources=vim.json.decode(bytes(root..'/tests/e2e/sql-tools/sources.json'))
for _,item in ipairs({sources.platforms[manifest.platform].sqruff,sources.grammar}) do
  link(deps..'/archives/'..item.archive,copy..'/archives/'..item.archive)
end
local function unchanged()
  T.eq(bytes(copy..'/manifest.json'),manifest_bytes,'readonly manifest')
  T.eq(bytes(deps..'/manifest.json'),manifest_bytes,'original manifest')
  for file,hash in pairs(manifest.files) do T.eq(vim.fn.sha256(bytes(copy..'/'..file)),hash,file) end
  T.eq(vim.fn.isdirectory(copy..'/tmp'),0,'readiness не требует SDK scratch')
end
local function run(name,args)
  local command={python,'-B',script,'--output',copy,'--nvim',vim.v.progpath}
  vim.list_extend(command,args or {})
  local job=vim.system(command,{text=true,env={PYTHONIOENCODING='utf-8',FORGE_E2E_DEPS=vim.env.FORGE_E2E_DEPS or root..'/.tests/editor-deps'}})
  local result=job:wait(30000)
  vim.fn.writefile({vim.json.encode({command=command,pid=job.pid,code=result.code,stdout=result.stdout,stderr=result.stderr})},dir..'/'..name..'.json')
  if vim.fn.has('win32')==1 then
    local prefix='forge-sql-readiness-'..job.pid..'-'
    for folder in vim.fs.dir(root..'/.tests/tmp') do assert(folder:sub(1,#prefix)~=prefix,'leaked readiness profile '..folder) end
  end
  return result
end
local function check(name,fn)
  if vim.env.FORGE_SQL_SDK_CASE and not name:find(vim.env.FORGE_SQL_SDK_CASE,1,true) then return end
  T.check(name,fn)
end
check('IDE-SQL-5 IDE-067 SDK readiness без compiler и build scratch',function()
  local result=run('readiness',{'--go',dir..'/missing-go','--cc',dir..'/missing-cc'})
  T.eq(result.code,0,(result.stderr or '')..(result.stdout or ''))
  assert(result.stdout:find('Ready SQL tools:',1,true),result.stdout)
  unchanged()
end)
check('IDE-SQL-5 SDK variant change требует explicit download',function()
  local variant=manifest.sqls_variant=='patched' and 'upstream' or 'patched'
  local result=run('variant',{'--sqls-variant',variant})
  T.eq(result.code,2,result.stdout);assert(result.stderr:find('Вариант SQLS изменён',1,true),result.stderr)
  unchanged()
end)
io.stdout:write('  artifacts: '..dir..'\n')
T.finish()
