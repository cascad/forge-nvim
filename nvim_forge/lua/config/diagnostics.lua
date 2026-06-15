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

-- Кэш переноса текста (problem 2): Neovim дёргает M.format на КАЖДУЮ
-- диагностику при КАЖДОМ показе virtual_lines (а показ случается часто:
-- курсор сменил строку, ресайз, повторный publish). wrap_message не
-- бесплатный (посимвольный strdisplaywidth). Кэшируем результат по
-- (сообщение → перенос) для текущей ширины окна; при смене ширины
-- сбрасываем. Так «генерация текста пояснения» считается один раз и
-- больше не подтормаживает — выезжает мгновенно из кэша.
local format_cache = {}
local format_cache_width = nil

function M.format(diagnostic)
    local width = M.wrap_width()
    if width ~= format_cache_width then
        format_cache = {}
        format_cache_width = width
    end

    local message = diagnostic.message
    if diagnostic.code then
        message = string.format("%s: %s", diagnostic.code, message)
    end

    local cached = format_cache[message]
    if cached ~= nil then return cached end

    local wrapped = M.wrap_message(message, width)
    format_cache[message] = wrapped
    return wrapped
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

    -- Перерисовываем диагностику ТОЛЬКО при реальном изменении ширины окна
    -- (перенос текста зависит от ширины). Раньше тут был ещё WinEnter — он
    -- передёргивал show на КАЖДЫЙ переход фокуса между окнами, заставляя
    -- заново раскладывать все virtual_lines без причины (ширина-то не
    -- менялась). Это и давало микро-фриз при переключении панелей. Убрали.
    -- Плюс дебаунс: серию событий ресайза схлопываем в один re-show.
    local timer
    local function schedule_refresh()
        if timer then timer:stop() end
        timer = vim.defer_fn(function()
            timer = nil
            pcall(vim.diagnostic.show, nil, 0)
        end, 60)
    end

    vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
        group = vim.api.nvim_create_augroup("UserDiagnosticWrapRefresh", { clear = true }),
        callback = schedule_refresh,
    })
end

return M
