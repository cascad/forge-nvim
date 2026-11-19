-- Existing launch-buffer/path helpers only; no new state.
local function normalize_path(path)
    if not path or path == "" then return "" end
    local normalized = vim.fs.normalize(path):gsub("\\", "/")
    if vim.fn.has("win32") == 1 then
        normalized = normalized:lower()
    end
    return normalized
end

local function with_launch_buffer(fn)
    local buf = vim.g.user_dap_launch_buf
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
        return vim.api.nvim_buf_call(buf, fn)
    end
    return fn()
end

local function current_launch_path()
    return with_launch_buffer(function()
        return vim.api.nvim_buf_get_name(0)
    end)
end

return {
    normalize_path = normalize_path,
    with_launch_buffer = with_launch_buffer,
    current_launch_path = current_launch_path,
}
