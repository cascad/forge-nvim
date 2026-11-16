local config, deps, output = unpack(arg)
vim.env.FRIDE_RUNTIME = nil
package.path = config .. '/lua/?.lua;' .. package.path
vim.opt.rtp:prepend(deps .. '/lazy/nvim-treesitter')
local ts, calls = require('nvim-treesitter'), 0
ts.install = function(names)
    assert(#names == 33)
    calls = calls + 1
    return {wait = function() end}
end
local treesitter = require('plugins.treesitter')[1]
assert(treesitter.build == ':TSUpdate', 'Unmanaged build hook was lost')
treesitter.config()
assert(calls == 0, 'Parser installation ran on startup')
vim.cmd('ForgeTreesitterInstall')
assert(calls == 1, 'Explicit unmanaged preparation was lost')
vim.fn.writefile({vim.json.encode({startup = 0, explicit = calls})}, output)
