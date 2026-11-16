-- spec: IDE-BOOT-29. Read-only catalog; no setup, package registry or SDK queries.
local config, plugin, output = unpack(arg)
assert(output, 'Expected config, pinned Treesitter plugin and output')
package.path = config .. '/lua/?.lua;' .. plugin .. '/lua/?.lua;' .. package.path
local tools = require('forge.tool_catalog')
local rows, components = {}, {}
for line in io.lines(config .. '/scripts/components.tsv') do
    local fields = vim.split(line:gsub('\r$', ''), '\t', { plain = true })
    assert(#fields == 5)
    if fields[2] ~= '-' then rows[#rows + 1] = fields[1] end
end
for _, id in ipairs(rows) do
    vim.env.FORGE_NVIM_COMPONENTS = id == 'core' and 'core' or ('core,' .. id)
    components[id] = { mason = tools.mason(), parsers = tools.parsers() }
end
vim.env.FORGE_NVIM_COMPONENTS = nil
local catalog, grammars = require('nvim-treesitter.parsers'), {}
for _, name in ipairs(tools.parsers()) do
    local source = assert(catalog[name].install_info, name)
    grammars[name] = { source = source.url, revision = source.revision }
end
local sys = vim.uv.os_uname()
local osname = sys.sysname == 'Windows_NT' and 'windows' or (sys.sysname == 'Darwin' and 'macos' or 'linux')
local arch = ({ AMD64 = 'x64', x86_64 = 'x64', arm64 = 'arm64', aarch64 = 'arm64' })[sys.machine]
vim.fn.writefile({ vim.json.encode({ schema = 1, platform = osname .. '-' .. assert(arch),
    nvim_version = tostring(vim.version()), components = components, grammars = grammars,
    pins = tools.versions(), native_tools = tools.native_versions() }) }, output)
