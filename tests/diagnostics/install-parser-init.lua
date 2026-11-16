-- Only parser delivery is real here; plugin and Mason provisioning are controlled.
local config, deps = assert(vim.env.FRIDE_CONFIG), assert(vim.env.FORGE_E2E_DEPS)
vim.opt.rtp:prepend(config)
vim.opt.rtp:prepend(deps .. '/lazy/lazy.nvim')
require('lazy').setup({
    root = vim.fn.stdpath('data') .. '/lazy',
    spec = {}, rocks = {enabled = false}, checker = {enabled = false},
    change_detection = {enabled = false},
    -- This stand intentionally creates deeply nested Unicode paths. Native
    -- vim.loader currently exceeds the 255-byte cache filename limit there;
    -- that separate full-Default blocker is recorded with the failed v1 log.
    performance = {cache = {enabled = vim.env.FORGE_PARSER_TEST_CACHE == '1'}, rtp = {paths = require('forge.parser_runtime').paths(config)}},
})
vim.opt.rtp:prepend(deps .. '/lazy/nvim-treesitter')
local treesitter = require('plugins.treesitter')[1]
assert(treesitter.build == false, 'Managed Lazy restore can still build parsers')
treesitter.config()
package.preload['ide.backports'] = function() return {all = function() return {} end} end
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
