-- spec: IDE-BOOT-50. Native rustup proxy, real editor and SDK subprocesses.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
if vim.env.FORGE_TEST_ID and not T.matches('IDE-BOOT-50',vim.env.FORGE_TEST_ID)then T.finish();return end
local win=vim.fn.has('win32')==1
local suffix=win and '.exe' or ''
local rustup=vim.fn.exepath('rustup')
local name='IDE-BOOT-50 executable symlink retains Rust proxy name through native probe'
if rustup=='' then T.skip(name,'Prepared native rustup SDK is required; no download during E2E');T.finish();return end
local permission=vim.fn.tempname()..' SDK link'
local linked,why=vim.uv.fs_symlink(rustup,permission)
if not linked then T.skip(name,'Native file symlink unavailable: '..tostring(why));T.finish();return end
assert(vim.uv.fs_unlink(permission))
T.check(name,function()
 local e,proxy
 local ok,err=xpcall(function()
  e=require('editor').start(root,{timeout=60000,snapshot_ignore={['SDK links']=true},prepare=function(project)
   local folder=project..'/SDK links';vim.fn.mkdir(folder,'p')
   proxy=folder..'/rustc'..suffix
   assert(vim.uv.fs_symlink(rustup,proxy))
   assert(vim.uv.fs_symlink(rustup,folder..'/cargo'..suffix))
   assert(vim.fn.writefile({'before'},project..'/notes.txt')==0)
  end})
  e:wait('ready',function()return e:lua('return _G.forge_e2e_observed')end,15000)
  e:lua([[local proxy,rustup=...;local m=require('forge.sdk')
   assert(not pcall(m.location,'rust',rustup),'rustup itself is not a compiler path')
   local location=m.location('rust',proxy)
   assert(location.executable==vim.fs.normalize(proxy),'Executable proxy name was lost')
   m.probe('rust',proxy,function(sdk,err)_G.sdk_proxy_result={sdk=sdk,error=err}end)
   return true]],{proxy,rustup})
  e:wait('native proxy probe completed',function()return e:lua('return _G.sdk_proxy_result~=nil')end,15000)
  local result=e:lua('return _G.sdk_proxy_result')
  assert(result.sdk,result.error)
  assert(result.sdk.version:match('^rustc %d+'),result.sdk.version)
  assert(result.sdk.cargo:match('^cargo %d+'),result.sdk.cargo)
  e:input(':ForgeLanguages<CR>')
  e:wait('language picker',function()return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i'end)
  e:input('Rust')
  e:wait('selected Rust',function()return e:lua([[local s=require('telescope.actions.state').get_selected_entry();return s and s.ordinal:find('Rust',1,true)~=nil]])end)
  e:input('<CR>')
  e:wait('hub accepts inherited SDK after version check',function()
   return e:lua([[local state=require('forge.languages').status('rust');local s=state.sdks[1]
    return state.components~=nil and s and s.ready and s.version~=nil and s.error==nil]])
  end,15000)
  e:input('<Esc><Esc>:edit notes.txt<CR>iSDK_PROXY_OK <Esc>:write<CR>')
  e:wait('editor remains usable',function()return vim.fn.readfile(e.project..'/notes.txt')[1]:find('SDK_PROXY_OK',1,true)end)
 end,debug.traceback)
 if e then
  e:snapshot('sdk-proxy');io.stdout:write('  artifacts: '..e.dir..'\n')
  local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
  if not stopped then ok=false;err=tostring(err)..'\n'..tostring(cleanup)end
 end
 assert(ok,err)
end)
T.finish()
