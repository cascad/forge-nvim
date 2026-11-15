-- spec: IDE-BOOT-17. Real Lazy reset; fixture plugin inventory, no installs.
vim.go.loadplugins=true -- -u NONE/-l disables it; normal managed startup enables it.
vim.opt.rtp:prepend(vim.env.FORGE_SDK_LAZY)
local root=vim.env.FRIDE_CONFIG
vim.env.FRIDE_CONFIG=root..'/inherited-other-installation'
local lazy=require('lazy')
local setup=lazy.setup
lazy.setup=function(opts)
 opts.spec={};opts.install.missing=false
 opts.pkg={enabled=false};opts.readme={enabled=false}
 opts.change_detection={enabled=false}
 return setup(opts)
end
dofile(root..'/lua/config/lazy.lua')
local config=require('lazy.core.config')
assert(vim.fs.normalize(config.options.lockfile)==vim.fs.normalize(root..'/lazy-lock.json'))
assert(require('forge_sdk_fixture').loaded,'Kit config lost after Lazy runtimepath reset')
vim.fn.writefile({vim.json.encode({lockfile=config.options.lockfile,rtp=vim.opt.rtp:get(),data=vim.fn.stdpath('data')})},vim.env.FORGE_SDK_RESULT)
vim.cmd('qa!')
