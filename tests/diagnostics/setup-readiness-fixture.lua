-- Native Mason registry/receipt/location; controlled install command outcomes.
local case=vim.env.FORGE_READINESS_CASE or 'ready'
local deps=assert(vim.env.FORGE_READINESS_DEPS)
vim.opt.rtp:prepend(deps..'/lazy/mason.nvim')
package.preload.forge_fixture_registry=function() return {'forge_fixture_package'} end
package.preload.forge_fixture_package=function() return {
 schema='registry+v1',name='fixture-native',description='readiness fixture',homepage='https://example.invalid',
 licenses={},languages={},categories={},source={id='pkg:generic/fixture-native@1.0.0'},bin={['fixture-native']='tool'},
} end
local root=assert(vim.env.FORGE_READINESS_ROOT)
require('mason').setup({install_root_dir=root,registries={'lua:forge_fixture_registry'}})
local registry=require('mason-registry')
local refreshed=false;registry.refresh(function() refreshed=true end)
assert(vim.wait(5000,function() return refreshed end,10),'Local Lua registry did not refresh')
assert(registry.get_package('fixture-native').name=='fixture-native')
local location=require('mason-core.installer.InstallLocation').global()
local function write(path,text)
 vim.fn.mkdir(vim.fs.dirname(path),'p');local f=assert(io.open(path,'wb'));f:write(text);f:close()
end
local package_root=location:package('fixture-native')
local win=vim.fn.has('win32')==1
local exported=win and 'fixture-native.cmd' or 'fixture-native'
if case~='missing-package' then
 vim.fn.mkdir(package_root,'p')
 if case~='missing-receipt' then
  local receipt={name=case=='wrong-receipt' and 'another-package' or 'fixture-native',schema_version='2.0',
   source={type='registry+v1',id='pkg:generic/fixture-native@1.0.0',raw={}},
   registry={proto='lua',mod='forge_fixture_registry'},links={bin={[exported]='tool'},share={},opt={}},
   metrics={start_time=0,completion_time=1},install_options={}}
  if case=='legacy-receipt' then
   receipt.schema_version='1.0';receipt.primary_source=receipt.source;receipt.source=nil
   receipt.links.bin={['fixture-native']='tool'}
  end
  if case=='empty-bin' then receipt.links.bin=vim.empty_dict() end
  if case=='share-ready' or case=='share-missing' or case=='opt-missing' then
   receipt.links.share={['fixture-share']='assets'};receipt.links.opt={['fixture-opt']='assets'}
   vim.fn.mkdir(package_root..'/assets','p')
   if case~='share-missing' then vim.fn.mkdir(location:share('fixture-share'),'p') end
   if case~='opt-missing' then vim.fn.mkdir(location:opt('fixture-opt'),'p') end
  end
  write(location:receipt('fixture-native'),case=='corrupt-receipt' and 'not JSON' or vim.json.encode(receipt))
 end
 if case~='missing-source' then write(package_root..'/tool','fixture payload\n') end
 if case~='missing-export' and case~='host-fallback' then
  write(location:bin(exported),win and '@exit /b 0\r\n' or '#!/bin/sh\nexit 0\n')
  if case~='not-executable' then vim.uv.fs_chmod(location:bin(exported),493) end
 end
end
if case=='host-fallback' then
 local host=root..'/host-bin';local path=host..'/'..exported
 write(path,win and '@exit /b 0\r\n' or '#!/bin/sh\nexit 0\n');vim.uv.fs_chmod(path,493)
 vim.env.PATH=host..(win and ';' or ':')..vim.env.PATH
 assert(vim.fn.exepath('fixture-native')~='','Host fallback fixture is missing')
end
if case=='broken-parser' then
 local parser=assert(vim.api.nvim_get_runtime_file('parser/lua.*',false)[1])
 local extension=assert(parser:match('(%.[^./]+)$'))
 local extra=root..'/broken-runtime';vim.fn.mkdir(extra..'/parser','p')
 assert(vim.uv.fs_copyfile(parser,extra..'/parser/forge_broken'..extension))
 vim.opt.rtp:prepend(extra)
end
