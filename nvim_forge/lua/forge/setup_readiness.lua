-- spec: IDE-BOOT-15. Read-only postconditions; never installs or refreshes.
local M = {}
local function failures(title, errors)
    if #errors > 0 then error(title .. '\n' .. table.concat(errors, '\n'), 0) end
end
function M.tools(names)
    local registry = require('mason-registry')
    local location = require('mason-core.installer.InstallLocation').global()
    local errors, links_checked = {}, 0
    for _, name in ipairs(names) do
        local ok, reason = pcall(function()
            local package = registry.get_package(name)
            assert(package:is_installed(), 'package directory missing')
            local receipt = package:get_receipt():or_else(nil)
            assert(receipt, 'install receipt missing')
            assert(receipt:get_name() == name, 'install receipt names another package')
            local links = receipt:get_links()
            assert(type(links) == 'table', 'install receipt has no links')
            for _, kind in ipairs({'bin','share','opt'}) do
                assert(links[kind] == nil or type(links[kind]) == 'table', 'invalid receipt links: '..kind)
                for alias, target in pairs(links[kind] or {}) do
                    assert(type(alias)=='string' and type(target)=='string', 'invalid receipt link')
                    local source = vim.fs.joinpath(location:package(name), target)
                    local export = alias
                    if kind=='bin' and receipt:get_schema_version()=='1.0' and vim.fn.has('win32')==1 then
                        export=alias..'.cmd'
                    end
                    local published = location[kind](location, export)
                    local actual, linked = vim.uv.fs_stat(source), vim.uv.fs_stat(published)
                    assert(actual and (kind~='bin' or actual.type=='file'), 'declared '..kind..' source missing: '..source)
                    assert(linked and (kind~='bin' or linked.type=='file'), 'declared '..kind..' export missing: '..published)
                    assert(kind~='bin' or vim.fn.executable(published)==1, 'declared bin export is not executable: '..published)
                    links_checked=links_checked+1
                end
            end
        end)
        if not ok then errors[#errors+1]=name..': '..tostring(reason) end
    end
    failures('Required Mason packages are not ready:', errors)
    return {packages=#names,links=links_checked}
end
function M.parsers(names)
    local errors = {}
    for _, name in ipairs(names) do
        local ok, reason = pcall(function()
            local files=vim.api.nvim_get_runtime_file('parser/'..name..'.*',false)
            assert(#files>0,'parser library missing')
            local added, detail=vim.treesitter.language.add(name)
            assert(added,detail or 'native parser loader rejected library')
        end)
        if not ok then errors[#errors+1]=name..': '..tostring(reason) end
    end
    failures('Required Treesitter parsers are not ready:', errors)
    return {parsers=#names}
end
return M
