-- Only parser delivery is real here; plugin and Mason provisioning are controlled.
local config, deps = assert(vim.env.FRIDE_CONFIG), assert(vim.env.FORGE_E2E_DEPS)
vim.opt.rtp:prepend(config)
vim.opt.rtp:prepend(deps .. '/lazy/lazy.nvim')
local lazy, captured = require('lazy'), nil
-- Read the real config's policy; only plugin/Mason provisioning is controlled.
-- Seed the bootstrap directory to prevent a clone while capturing setup options.
vim.fn.mkdir(vim.fn.stdpath('data') .. '/lazy/lazy.nvim', 'p')
local setup = lazy.setup
lazy.setup = function(options) captured = options end
local configured, configure_error = pcall(dofile, config .. '/lua/config/lazy.lua')
lazy.setup = setup
assert(configured, configure_error)
assert(captured, 'Production Lazy options were not read')
lazy.setup({
    root = vim.fn.stdpath('data') .. '/lazy',
    spec = {}, rocks = {enabled = false}, checker = {enabled = false},
    change_detection = {enabled = false},
    performance = {cache = captured.performance.cache, rtp = {paths = require('forge.parser_runtime').paths(config)}},
})
vim.opt.rtp:prepend(deps .. '/lazy/nvim-treesitter')
local treesitter = require('plugins.treesitter')[1]
assert(treesitter.build == false, 'Managed Lazy restore can still build parsers')
treesitter.config()
package.preload['ide.backports'] = function() return {all = function() return {} end} end
-- Only parser delivery is under test; native plugin readiness has its own suite.
package.preload['forge.plugin_setup'] = function() return {prepare = function(before)
    if before then before() end
    return {fixture = true}
end} end
vim.api.nvim_create_user_command('Lazy', function() end, {nargs = '*', bang = true, force = true})
vim.api.nvim_create_user_command('MasonToolsInstallSync', function() end, {force = true})
local catalog = require('forge.tool_catalog')
catalog.mason = function() return {} end
package.preload['mason-registry'] = function() return {} end
package.preload['mason-core.installer.InstallLocation'] = function() return {global = function() return {} end} end
-- Managed parser setup must never fall back to the source installer.
if vim.env.FRIDE_RUNTIME and arg[1] ~= 'unmanaged' then
    vim.api.nvim_create_user_command('ForgeTreesitterInstall', function() error('Unexpected parser build') end, {force = true})
end
local system = vim.system
vim.system = function(command, options, callback)
    local name = vim.fs.basename(command[1]):lower():gsub('%.exe$', '')
    assert(not vim.tbl_contains({'tree-sitter', 'cc', 'gcc', 'clang', 'cl', 'curl', 'git', 'cargo', 'rustc', 'go', 'npm'}, name), 'Unexpected build/download: ' .. name)
    return system(command, options, callback)
end
