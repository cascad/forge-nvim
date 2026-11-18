-- Controlled install callback that reports success without correcting a receipt.
local root,base=assert(vim.env.FORGE_IDE_ROOT),arg[1]
-- Match the actual private installer's pre-init boundary, before registry/process.
vim.env.GOTOOLCHAIN=vim.env.FRIDE_SETUP_GO_TOOLCHAIN or 'local'
vim.env.RUSTUP_AUTO_INSTALL='0'
-- These false-success/old-SDK controls explicitly validate the strict baseline.
vim.env.FRIDE_TOOLS_VERSIONS=vim.env.FRIDE_TOOLS_VERSIONS or 'baseline'
local context=dofile(root..'/tests/diagnostics/install-ide-tools-registry.lua')
context.setup()
local refreshed=false;require('mason-registry').refresh(function() refreshed=true end)
assert(vim.wait(5000,function() return refreshed end,10))
require('forge.tool_catalog').mason=function() return context.names end
vim.api.nvim_create_user_command('Lazy',function()
 vim.api.nvim_create_user_command('MasonToolsInstallSync',function()
  vim.fn.writefile({vim.json.encode({go=vim.env.GOTOOLCHAIN,rust=vim.env.RUSTUP_AUTO_INSTALL})},base..'/setup-env.json')
 end,{force=true})
end,{nargs='*'})
arg={'tools'};dofile(root..'/nvim_forge/scripts/setup-stage.lua')
