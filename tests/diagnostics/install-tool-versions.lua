-- IDE-BOOT-43. Real Mason Github provider, local native fixture releases v1/v2.
local config=vim.json.decode(table.concat(vim.fn.readfile(assert(vim.env.FRIDE_VERSION_CONFIG)),'\n'))
vim.fn.mkdir(vim.fn.stdpath('state'),'p')
vim.opt.rtp:append(config.deps..'/lazy/mason.nvim')
vim.opt.rtp:append(config.deps..'/lazy/mason-tool-installer.nvim')
local name=config.package_name or 'fride-version-fixture'
package.preload.fride_version_package=function() return {
  schema='registry+v1',name=name,description='Native version policy fixture',homepage='https://example.invalid',
  licenses={'MIT'},languages={},categories={},source={id='pkg:github/fride/version-fixture@v1.0.0',
    asset={file='fixture.zip',bin='fride-version-fixture'..(vim.fn.has('win32')==1 and '.exe' or '')}},
  bin={[name]='{{source.asset.bin}}'},
} end
package.preload.fride_version_registry=function() return {'fride_version_package'} end
require('mason').setup({registries={'lua:fride_version_registry'},max_concurrent_installers=1,
  github={download_url_template=config.url..'/%s/%s/%s'}})
local registry=require('mason-registry')
local ready=false;registry.refresh(function() ready=true end);assert(vim.wait(5000,function() return ready end,10))
local package=registry.get_package(name)
local function capture()
  local receipt=package:get_receipt():or_else(nil)
  vim.fn.writefile({vim.json.encode({data=vim.fn.stdpath('data'),installed=package:is_installed(),
    version=receipt and receipt:get_installed_package_version(),policy=vim.env.FRIDE_TOOLS_VERSIONS,
    go_available=vim.fn.executable('go')})},config.report)
end
if config.manual then
  local done,success=false,false
  package:install({version=config.manual},function(ok) success=ok;done=true end)
  assert(vim.wait(30000,function() return done end,10),'Native fixture install timeout')
  assert(success,'Native fixture install failed');capture();return
end
local catalog=require('forge.tool_catalog')
catalog.mason=function() return config.names or {name} end
catalog.versions=function() return config.versions or {[name]='v1.0.0'} end
vim.api.nvim_create_user_command('Lazy',function()
  require('mason-tool-installer').setup({ensure_installed=catalog.mason_specs(),run_on_start=false,auto_update=false,
    integrations={['mason-lspconfig']=false,['mason-null-ls']=false,['mason-nvim-dap']=false}})
  vim.cmd('runtime plugin/mason-tool-installer.lua')
end,{nargs='*'})
if config.remove_external then
  vim.api.nvim_create_autocmd('User',{pattern='MasonToolsUpdateCompleted',once=true,
    callback=function() assert(vim.uv.fs_unlink(config.remove_external)) end})
end
vim.api.nvim_create_autocmd('VimLeavePre',{callback=capture})
if config.mti_only then
  vim.cmd('Lazy load mason-tool-installer.nvim');vim.cmd('MasonToolsInstallSync');return
end
if config.empty_path then vim.env.PATH='' end
dofile(config.stage)
