-- IDE-BOOT-22: actual Mason compilers/receipts, local registry, real payloads.
local root, deps, cache = assert(vim.env.FORGE_IDE_ROOT), assert(vim.env.FORGE_E2E_DEPS), assert(vim.env.FORGE_IDE_CACHE)
vim.fn.mkdir(vim.fn.stdpath('state'),'p')
package.path = root..'/nvim_forge/lua/?.lua;'..package.path
vim.opt.rtp:prepend(deps..'/lazy/mason.nvim')
vim.opt.rtp:prepend(deps..'/lazy/mason-tool-installer.nvim')
local catalog=require('forge.tool_catalog')
local versions=catalog.versions()
local names={'gopls','gofumpt','golines','stylua','prettier'}
local definitions={}
local sources={gopls='pkg:golang/golang.org/x/tools/gopls',gofumpt='pkg:golang/mvdan.cc/gofumpt',golines='pkg:golang/github.com/golangci/golines',stylua='pkg:github/johnnymorganz/stylua',prettier='pkg:npm/prettier'}
local win=vim.fn.has('win32')==1
local osname=win and 'windows' or vim.fn.has('macunix')==1 and 'macos' or 'linux'
local arm=vim.uv.os_uname().machine:lower():find('arm') or vim.uv.os_uname().machine=='aarch64'
for _,name in ipairs(names) do
 local source={id=sources[name]..'@'..versions[name]}
 local bin=(name=='prettier' and 'npm:' or 'golang:')..name
 if name=='stylua' then
  local file='stylua-'..osname..'-'..(arm and 'aarch64' or 'x86_64')..'.zip'
  source.asset={file=file,bin=win and 'stylua.exe' or 'stylua'}
  bin='{{source.asset.bin}}'
 end
 definitions[name]={schema='registry+v1',name=name,description='Official tool source for native acceptance',homepage='https://github.com/mason-org/mason-registry',licenses={},languages={},categories={},source=source,bin={[name]=bin}}
 package.preload['forge_ide_package_'..name]=function() return definitions[name] end
end
package.preload.forge_ide_registry=function() return vim.tbl_map(function(n) return 'forge_ide_package_'..n end,names) end
local function setup()
 local settings={install_root_dir=vim.fn.stdpath('data')..'/mason',registries={'lua:forge_ide_registry'},max_concurrent_installers=1}
 if vim.env.FORGE_IDE_GITHUB_TEMPLATE then settings.github={download_url_template=vim.env.FORGE_IDE_GITHUB_TEMPLATE} end
 require('mason').setup(settings)

end
return {setup=setup,names=names,versions=versions}
