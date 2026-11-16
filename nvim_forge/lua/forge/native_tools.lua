-- IDE-BOOT-23. Only IDE-owned runtime paths; language SDK lookup is unchanged.
local M = {}
function M.owned(name)
    local root = vim.env.FRIDE_RUNTIME
    if not root or root == '' then return nil end
    local suffix = vim.fn.has('win32') == 1 and '.exe' or ''
    local path = vim.fs.joinpath(root, 'sql/bin', name..suffix)
    return vim.fn.executable(path) == 1 and path or nil
end
function M.executable(name)
    local path = M.owned(name) or vim.fn.exepath(name)
    return path and path ~= '' and path or nil
end
function M.check_sql()
    local versions = require('forge.tool_catalog').native_versions()
    local report = {}
    for _, name in ipairs({'sqls','forge-sqltest'}) do
        local path = assert(M.owned(name), 'SQL native component missing: '..name)
        local result = vim.system({path, name == 'sqls' and '-version' or '--version'}, {text=true}):wait(5000)
        local output = (result.stdout or '')..(result.stderr or '')
        local expected = name == 'sqls' and ('Version:'..versions[name]..',') or (name..' '..versions[name]..' ')
        assert(result.code == 0 and output:find(expected,1,true), 'Unexpected '..name..' version: '..output)
        report[name] = {path=path,version=vim.trim(output)}
    end
    return report
end
return M
