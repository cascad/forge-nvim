-- spec: IDE-BOOT-24. Managed site is read-only and uses Neovim's native loader.
local M = {}
function M.site()
    local runtime = vim.env.FRIDE_RUNTIME
    if runtime and runtime ~= '' then return vim.fs.joinpath(runtime, 'treesitter') end
end
function M.paths(config_root)
    local paths = {}
    if vim.fs.normalize(config_root) ~= vim.fs.normalize(vim.fn.stdpath('config')) then
        paths[#paths + 1] = config_root
    end
    local site = M.site()
    if site then paths[#paths + 1] = site end
    return paths
end
function M.activate()
    local site = M.site()
    if site then vim.opt.rtp:prepend(site) end
end
function M.check(names)
    local site = assert(M.site(), 'Managed parser runtime is missing')
    M.activate()
    local errors, queries = {}, 0
    for _, name in ipairs(names) do
        local ok, reason = pcall(function()
            local path = vim.fs.joinpath(site, 'parser', name .. '.so')
            assert(vim.fn.filereadable(path) == 1, 'owned parser library missing: ' .. path)
            assert(vim.fn.filereadable(vim.fs.joinpath(site, 'queries', name, 'highlights.scm')) == 1,
                'owned highlight query missing: ' .. name)
            assert(vim.treesitter.language.add(name, { path = path, force = true }))
            for _, kind in ipairs({'highlights', 'injections', 'folds', 'indents', 'locals', 'textobjects'}) do
                if vim.treesitter.query.get(name, kind) then queries = queries + 1 end
            end
        end)
        if not ok then errors[#errors + 1] = name .. ': ' .. tostring(reason) end
    end
    assert(#errors == 0, 'Managed Treesitter parsers are not ready:\n' .. table.concat(errors, '\n'))
    return {parsers = #names, queries = queries, site = site}
end
return M
