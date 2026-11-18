-- Native CLI E2E extracted from the mixed unit suite; no editor or downloads.
-- spec: IDE-TEST-10. Fast plan/CLI checks; never starts editor E2E.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('IDE-TEST-10 native dry plan uses real registry and clears inherited filters',function()
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Python required for batch plans')
  local result=vim.system({python,'-B',root..'/scripts/test-batch.py','--nvim',vim.v.progpath,'--mode','e2e',
    '--file','tests/e2e/setup-sdk-paths.test.lua','--file','tests/install-setup.test.py','--plan'},
    {cwd=root,text=true,timeout=30000,env={FORGE_TEST_ID='NOT-A-REAL-ID',FORGE_RUNTIME_SDK_CASE='should be cleared'}}):wait()
  assert(result.code==0,result.stderr)
  local data=vim.json.decode(result.stdout)
  T.eq(data.registry_files,{'tests/e2e/setup-sdk-paths.test.lua'});T.eq(data.installers,{'tests/install-setup.test.py'})
  T.eq(#data.commands,2);T.eq(data.results,{})
  T.eq(data.filters_cleared,{'FORGE_RUNTIME_SDK_CASE','FORGE_TEST_ID'})
  local invalid=vim.system({python,'-B',root..'/scripts/test-batch.py','--nvim',vim.v.progpath,'--mode','regression',
    '--file','tests/e2e/setup-sdk-paths.test.lua','--plan'},{cwd=root,text=true,timeout=30000}):wait()
  assert(invalid.code~=0 and invalid.stderr:find('regression is complete',1,true))
  local full=vim.system({python,'-B',root..'/scripts/test-batch.py','--nvim',vim.v.progpath,'--mode','regression','--plan'},
    {cwd=root,text=true,timeout=30000}):wait()
  assert(full.code==0,full.stderr)
  assert(vim.tbl_contains(vim.json.decode(full.stdout).installers,'tests/release-inventory.test.py'),'Release inventory omitted from regression')
end)
T.check('IDE-TEST-11 Core input gate blocks before tests and declares source installed argv',function()
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
  local argv={python,'-B',root..'/scripts/test-batch.py','--nvim',vim.v.progpath,'--mode','e2e','--file','tests/install-core-acceptance.test.py'}
  local env={FORGE_CORE_TEST_KIT='',FORGE_CORE_TEST_PROFILE='',FORGE_CORE_TEST_RUNTIME=''}
  local function invoke(extra)
    local result=vim.system(vim.list_extend(vim.deepcopy(argv),extra or {}),{cwd=root,text=true,timeout=30000,env=env}):wait()
    return result,result.code==0 and vim.json.decode(result.stdout) or nil
  end
  local result,data=invoke({'--plan'})
  assert(result.code==0,result.stderr);assert(not data.ready and #data.missing_inputs>0)
  T.eq(data.installers,{'tests/install-core-acceptance.test.py'});T.eq(data.results,{})
  local blocked=invoke()
  T.eq(blocked.code,2);assert(blocked.stderr:find('no tests started',1,true))
  local report_path=assert(blocked.stderr:match('Report: ([^\r\n]+)'))
  local stopped=vim.json.decode(table.concat(vim.fn.readfile(report_path),'\n'))
  T.eq(stopped.results,{});assert(not stopped.complete and not stopped.ok)
  local folder=root..'/.tests/batch-inputs/'..tostring(vim.uv.hrtime())
  vim.fn.mkdir(folder..'/runtime/treesitter/parser','p')
  vim.fn.writefile({'plan fixture, not a binary'},folder..'/runtime/treesitter/parser/lua.so')
  env.FORGE_CORE_TEST_RUNTIME=folder..'/runtime'
  result,data=invoke({'--plan'});assert(result.code==0,result.stderr)
  T.eq(data.core_mode,'prepared-native-config');assert(data.ready)
  assert(vim.tbl_contains(data.commands[1].argv,'--editor-deps') and vim.tbl_contains(data.commands[1].argv,'--runtime'))
  vim.fn.mkdir(folder..'/kit','p');vim.fn.mkdir(folder..'/profile','p')
  vim.fn.writefile({'{}'},folder..'/kit/.forge-install.json')
  env.FORGE_CORE_TEST_KIT=folder..'/kit';env.FORGE_CORE_TEST_PROFILE=folder..'/profile'
  result,data=invoke({'--plan'});assert(result.code==0,result.stderr)
  T.eq(data.core_mode,'installed-kit');assert(data.ready)
  assert(vim.tbl_contains(data.commands[1].argv,'--kit') and vim.tbl_contains(data.commands[1].argv,'--profile'))
  assert(not vim.tbl_contains(data.commands[1].argv,'--editor-deps'))
  env.FORGE_CORE_TEST_PROFILE=''
  result,data=invoke({'--plan'});assert(result.code==0,result.stderr)
  assert(not data.ready and data.core_mode=='installed-kit','Partial kit input silently fell back to source mode')
end)
T.finish()
