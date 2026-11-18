local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..root..'/nvim_forge/lua/?.lua;'..package.path
local T=require('check')
T.check('SELF: tool version specs do not load registry during startup',function()
  local before=package.loaded['mason-registry'];local old=package.preload['mason-registry']
  local setup,preload=package.loaded['forge.setup_tools'],package.preload['forge.setup_tools']
  package.loaded['forge.setup_tools']=nil
  package.preload['forge.setup_tools']=function() error('Unexpected startup tool settings load') end
  package.loaded['mason-registry']=nil
  package.preload['mason-registry']=function() error('Unexpected startup registry load') end
  local ok,result=pcall(require('forge.tool_catalog').mason_specs)
  package.preload['mason-registry']=old;package.loaded['mason-registry']=before
  package.loaded['forge.setup_tools']=setup;package.preload['forge.setup_tools']=preload
  assert(ok,result);assert(#result>0)
end)
T.check('SELF: preserved installed Go tool does not require a compiler',function()
  local before,path=package.loaded['mason-registry'],vim.env.PATH
  package.loaded['mason-registry']={get_package=function() return {
    is_installed=function() return true end,
    get_receipt=function() return {or_else=function() return {get_installed_package_version=function() return 'v2' end} end} end,
  } end}
  vim.env.PATH=''
  local ready=require('forge.setup_readiness')
  local ok,err=pcall(ready.build_sdks,{'gopls'},{gopls='v1'},{preserve_versions=true})
  local baseline=pcall(ready.build_sdks,{'gopls'},{gopls='v1'})
  vim.env.PATH=path;package.loaded['mason-registry']=before
  assert(ok,err);assert(not baseline,'Baseline build must still require its compiler')
end)
T.finish()
