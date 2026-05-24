local M = {}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function display_width(s)
    local ok, width = pcall(vim.fn.strdisplaywidth, s)
    if ok then return width end
    return #s
end

local function split_long_word(word, width)
    local lines = {}
    local chunk = ""

    for _, char in ipairs(vim.fn.split(word, "\\zs")) do
        if chunk ~= "" and display_width(chunk .. char) > width then
            table.insert(lines, chunk)
            chunk = char
        else
            chunk = chunk .. char
        end
    end

    if chunk ~= "" then table.insert(lines, chunk) end
    return lines
end

local function wrap_line(line, width)
    line = trim(line)
    if line == "" then return { "" } end

    local lines = {}
    local current = ""

    for word in line:gmatch("%S+") do
        if display_width(word) > width then
            if current ~= "" then
                table.insert(lines, current)
                current = ""
            end
            vim.list_extend(lines, split_long_word(word, width))
        elseif current == "" then
            current = word
        elseif display_width(current .. " " .. word) <= width then
            current = current .. " " .. word
        else
            table.insert(lines, current)
            current = word
        end
    end

    if current ~= "" then table.insert(lines, current) end
    return lines
end

function M.wrap_width()
    local ok, width = pcall(vim.api.nvim_win_get_width, 0)
    if not ok then return 88 end

    -- Leave room for signs, line numbers, folds and diagnostic prefixes.
    return math.max(30, math.min(100, width - 12))
end

function M.wrap_message(message, width)
    width = width or M.wrap_width()
    message = tostring(message or "")
        :gsub("\r\n", "\n")
        :gsub("\r", "\n")
        :gsub("\t", " ")
        :gsub(" +", " ")

    local out = {}
    for _, line in ipairs(vim.split(message, "\n", { plain = true })) do
        vim.list_extend(out, wrap_line(line, width))
    end

    return trim(table.concat(out, "\n"))
end

function M.format(diagnostic)
    local message = diagnostic.message
    if diagnostic.code then
        message = string.format("%s: %s", diagnostic.code, message)
    end
    return M.wrap_message(message)
end

function M.virtual_lines_current()
    return {
        current_line = true,
        format = M.format,
    }
end

function M.virtual_lines_all()
    return {
        format = M.format,
    }
end

function M.setup_refresh()
    if M._refresh_setup then return end
    M._refresh_setup = true

    vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "WinEnter" }, {
        group = vim.api.nvim_create_augroup("UserDiagnosticWrapRefresh", { clear = true }),
        callback = function()
            vim.schedule(function()
                pcall(vim.diagnostic.show, nil, 0)
            end)
        end,
    })
end

return M
