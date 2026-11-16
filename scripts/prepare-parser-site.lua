-- Explicit publisher preparation with existing tree-sitter CLI/C compiler.
-- nvim --headless -u NONE -i NONE -l scripts/prepare-parser-site.lua PLUGIN SITE
local plugin, site = unpack(arg)
assert(site, 'Expected pinned nvim-treesitter directory and output site')
local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
package.path = root .. '/nvim_forge/lua/?.lua;' .. plugin .. '/lua/?.lua;' .. package.path
vim.opt.rtp:prepend(plugin)
vim.env.FORGE_NVIM_COMPONENTS = nil
require('nvim-treesitter').setup({install_dir = site})
require('nvim-treesitter').install(require('forge.tool_catalog').parsers()):wait(300000)
require('forge.setup_readiness').parsers(require('forge.tool_catalog').parsers())
