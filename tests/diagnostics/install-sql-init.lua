-- Core plugins/parsers are controlled; SQL postconditions/providers are real.
local config=assert(vim.env.FRIDE_CONFIG)
vim.opt.rtp:prepend(config);vim.opt.rtp:prepend(assert(vim.env.FORGE_E2E_DEPS)..'/lazy/mason.nvim')
vim.fn.mkdir(vim.fn.stdpath('state'),'p')
package.preload.forge_sql_fixture_registry=function() return {'forge_sqruff_fixture'} end
package.preload.forge_sqruff_fixture=function() return {schema='registry+v1',name='sqruff',description='Existing native sqruff',homepage='https://github.com/quarylabs/sqruff',licenses={},languages={},categories={},source={id='pkg:generic/sqruff@0.44.0'},bin={sqruff='sqruff'}} end
require('mason').setup({registries={'lua:forge_sql_fixture_registry'}})
local refreshed=false;require('mason-registry').refresh(function() refreshed=true end);assert(vim.wait(5000,function() return refreshed end,10))
local location=require('mason-core.installer.InstallLocation').global()
local win=vim.fn.has('win32')==1;local name=win and 'sqruff.exe' or 'sqruff'
local package_root=location:package('sqruff');vim.fn.mkdir(package_root,'p')
assert(vim.uv.fs_copyfile(assert(vim.env.FORGE_SQRUFF_FIXTURE),package_root..'/'..name));assert(vim.uv.fs_chmod(package_root..'/'..name,493))
vim.fn.mkdir(location:bin(),'p');assert(vim.uv.fs_copyfile(package_root..'/'..name,location:bin(name)));assert(vim.uv.fs_chmod(location:bin(name),493))
vim.fn.writefile({vim.json.encode({name='sqruff',schema_version='2.0',metrics={},registry={proto='lua',mod='forge_sql_fixture_registry'},
 source={type='registry+v1',id='pkg:generic/sqruff@0.44.0',raw={}},links={bin={[name]=name},share={},opt={}},install_options={}})},location:receipt('sqruff'))
local catalog=require('forge.tool_catalog');catalog.mason=function() return {'sqruff'} end;catalog.parsers=function() return {} end
package.preload['ide.backports']=function() return {all=function() return {} end} end
package.preload['forge.plugin_setup']=function() return {prepare=function(before)
 if before then before() end;return {fixture=true}
end} end
vim.api.nvim_create_user_command('Lazy',function() vim.api.nvim_create_user_command('MasonToolsInstallSync',function() end,{force=true}) end,{nargs='*',bang=true})
vim.api.nvim_create_user_command('ForgeTreesitterInstall',function() end,{})
local system=vim.system
vim.system=function(command,options,callback)
 local name=vim.fs.basename(command[1]):lower():gsub('%.exe$','')
 assert(not vim.tbl_contains({'go','rustc','cargo','cc','gcc','clang'},name),'Unexpected language/compiler SDK: '..name)
 return system(command,options,callback)
end
