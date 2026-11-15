-- Actual Mason installation; source/version definitions shared with native tests.
local context=dofile(assert(vim.env.FORGE_IDE_ROOT)..'/tests/diagnostics/install-ide-tools-registry.lua')
local names,versions=context.names,context.versions
local cache=assert(vim.env.FORGE_IDE_CACHE)
local ok,err=xpcall(function()
 context.setup()
 local specs={};for _,name in ipairs(names) do specs[#specs+1]={name,version=versions[name]} end
 require('mason-tool-installer').setup({ensure_installed=specs,auto_update=false,run_on_start=false,integrations={['mason-lspconfig']=false,['mason-null-ls']=false,['mason-nvim-dap']=false}})
 vim.cmd('runtime plugin/mason-tool-installer.lua')
 vim.cmd('MasonToolsInstallSync')
 local report=require('forge.setup_readiness').tools(names,versions)
 vim.fn.writefile({vim.json.encode(report)},cache..'/prepared.json')
end,debug.traceback)
if not ok then io.stderr:write(err..'\n');vim.cmd('cquit 1') end
vim.cmd('qa!')
