local M = {}

local function norm(path)
    return (path or ""):lower():gsub("\\", "/")
end

function M.is_path(path)
    path = norm(path)
    if path == "" then
        return false
    end

    local home = norm(vim.fn.expand("~"))
    local external = (#home > 0 and (
        path:find(home .. "/.cargo/", 1, true)
        or path:find(home .. "/.rustup/", 1, true)
    ))
        or path:find("/.cargo/registry/", 1, true)
        or path:find("/.cargo/git/", 1, true)
        or path:find("/.rustup/", 1, true)
        or path:find("/rustlib/src/", 1, true)
        or path:find("/toolchains/", 1, true)

    return external ~= nil and external ~= false
end

function M.is_buf(bufnr)
    bufnr = bufnr or 0
    return M.is_path(vim.api.nvim_buf_get_name(bufnr))
end

function M.mark(bufnr)
    bufnr = bufnr or 0
    local external = M.is_buf(bufnr)
    vim.b[bufnr].rust_external = external or nil
    return external
end

return M
