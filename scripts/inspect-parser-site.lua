-- Publisher helper. No plugin setup, downloads, compiler or host-site writes.
local config, plugin, site, output = unpack(arg)
assert(output, 'Expected config, pinned nvim-treesitter, prepared site and output')
package.path = config .. '/lua/?.lua;' .. plugin .. '/lua/?.lua;' .. package.path
vim.env.FORGE_NVIM_COMPONENTS = nil
local names = require('forge.tool_catalog').parsers()
local catalog = require('nvim-treesitter.parsers')
local languages = require('nvim-treesitter.config').norm_languages(vim.deepcopy(names))
local result = {languages = names, grammars = {}, queries = {}}
for _, name in ipairs(languages) do
    local info = assert(catalog[name], name).install_info
    if info then
        assert(info.revision and info.url and not info.queries, 'Unsupported parser source: ' .. name)
        local revision = vim.trim(table.concat(vim.fn.readfile(site .. '/parser-info/' .. name .. '.revision'), '\n'))
        assert(revision == info.revision, 'Parser revision mismatch: ' .. name)
        result.grammars[name] = {revision = revision, url = info.url}
    end
    local queries = plugin .. '/runtime/queries/' .. name
    if vim.fn.isdirectory(queries) == 1 then result.queries[name] = queries end
end
vim.fn.writefile({vim.json.encode(result)}, output)
