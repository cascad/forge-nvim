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

-- =====================================================================
-- «Где именно я ошибся» — подсветка точного диапазона под окошком.
-- =====================================================================
-- Пассивно место ошибки и так помечено: DiagnosticUnderline* даёт
-- подчёркивание + лёгкую заливку ровно под теми символами, на которые
-- ругается компилятор. Но раньше на них ещё и УКАЗЫВАЛИ virtual_lines
-- (уголок «╰──» к нужной колонке), а мы их убрали (они раздвигали код).
--
-- Возвращаем указание, не возвращая раздвигание: пока висит окно с текстом
-- (`gl`), ровно тот диапазон, о котором это окно говорит, подсвечивается
-- цветом severity. Видно и ЧТО не так (окно), и ГДЕ (подсветка) — а код
-- не сдвинулся ни на строку.

local FOCUS_NS = vim.api.nvim_create_namespace("forge_diag_focus")
local focus_group = vim.api.nvim_create_augroup("ForgeDiagFocus", { clear = true })

local SEVERITY_SUFFIX = {
    [vim.diagnostic.severity.ERROR] = "Error",
    [vim.diagnostic.severity.WARN]  = "Warn",
    [vim.diagnostic.severity.INFO]  = "Info",
    [vim.diagnostic.severity.HINT]  = "Hint",
}

---Смешать два RGB-цвета: alpha=0 → bg, alpha=1 → fg.
local function blend(fg, bg, alpha)
    local function channel(color, shift)
        return math.floor(color / 2 ^ shift) % 256
    end
    local out = 0
    for _, shift in ipairs({ 16, 8, 0 }) do
        local c = math.floor(channel(fg, shift) * alpha + channel(bg, shift) * (1 - alpha) + 0.5)
        out = out * 256 + math.min(255, math.max(0, c))
    end
    return out
end

---Группы подсветки «фокус на диагностике»: фон = цвет severity, подмешанный
---к фону редактора (заметно, но не выжигает глаза), текст — жирный.
function M.setup_focus_highlights()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    for _, suffix in pairs(SEVERITY_SUFFIX) do
        local sev = vim.api.nvim_get_hl(0, { name = "Diagnostic" .. suffix, link = false })
        local name = "ForgeDiagFocus" .. suffix
        if sev.fg and normal.bg then
            vim.api.nvim_set_hl(0, name, {
                bg = blend(sev.fg, normal.bg, 0.30),
                bold = true,
            })
        else
            -- Прозрачный фон / тема без цветов — падаем на штатную группу.
            vim.api.nvim_set_hl(0, name, { link = "DiagnosticVirtualText" .. suffix })
        end
    end
end

vim.api.nvim_create_autocmd("ColorScheme", {
    group = focus_group,
    callback = function() pcall(M.setup_focus_highlights) end,
})

local function clear_focus(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_clear_namespace, buf, FOCUS_NS, 0, -1)
    end
end

-- Окно, открытое последним `gl`. Нужно, чтобы Esc умел его закрыть НЕ двигая
-- курсор (штатно float гаснет только на CursorMoved).
local float_win, float_buf = nil, nil

---Закрыть оверлей диагностики, если он открыт.
---@return boolean closed было что закрывать (Esc-цепочка на это смотрит)
function M.close_float()
    local win = float_win
    float_win, float_buf = nil, nil
    if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)   -- подсветку снимет WinClosed
        return true
    end
    return false
end

---Показать диагностику строки под курсором ОВЕРЛЕЕМ + подсветить точное место.
---Подсветка живёт ровно столько же, сколько окно: гаснет вместе с ним (движение
---курсора, Esc, `q`).
function M.show_under_cursor()
    -- Курсор уже ВНУТРИ окошка (в него проваливает повторный `gl`) — незачем
    -- открывать окно поверх окна: там диагностики нет, а слепой сброс
    -- autocmd'ов ниже осиротил бы подсветку в коде.
    if float_buf and vim.api.nvim_get_current_buf() == float_buf then
        return float_buf, float_win
    end

    local buf = vim.api.nvim_get_current_buf()
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

    vim.api.nvim_clear_autocmds({ group = focus_group, event = { "CursorMoved", "CursorMovedI", "InsertEnter", "WinClosed" } })
    clear_focus(buf)

    local diags = vim.diagnostic.get(buf, { lnum = lnum })
    if #diags == 0 then return end

    for _, d in ipairs(diags) do
        local end_row = d.end_lnum or d.lnum
        local end_col = d.end_col or (d.col + 1)
        -- Диагностика НУЛЕВОЙ ШИРИНЫ — это не «место в коде», а точка вставки:
        -- так rustc шлёт подсказки вида «try using a conversion method:
        -- `.to_string()`» (диапазон col==end_col сразу после выражения). Тут
        -- указывать не на что: если растянуть до col+1, подсветится соседний
        -- символ (`;`), которого подсказка вообще не касается — враньё глазу.
        -- Текст такой подсказки всё равно виден в окне, просто без заливки.
        local zero_width = (end_row == d.lnum and end_col <= d.col)
        if not zero_width then
            pcall(vim.api.nvim_buf_set_extmark, buf, FOCUS_NS, d.lnum, d.col, {
                end_row = end_row,
                end_col = end_col,
                hl_group = "ForgeDiagFocus" .. (SEVERITY_SUFFIX[d.severity] or "Error"),
                priority = 200,   -- выше treesitter и DiagnosticUnderline*
                strict = false,   -- диапазон может вылезать за конец строки
            })
        end
    end

    float_buf, float_win = vim.diagnostic.open_float(nil, { scope = "line" })

    if float_buf and float_win then
        -- Esc / q ВНУТРИ окошка: повторный `gl` проваливает туда курсор (штатный
        -- focus_id-механизм Neovim), и оттуда окно иначе не закрыть, кроме как
        -- уйти из него.
        for _, lhs in ipairs({ "<Esc>", "q" }) do
            vim.keymap.set("n", lhs, M.close_float, {
                buffer = float_buf, nowait = true, silent = true,
                desc = "Закрыть окно диагностики",
            })
        end

        -- Подсветка живёт ровно столько же, сколько окно, КАК БЫ оно ни закрылось
        -- (Esc, q, движение курсора, смена окна). Одно правило вместо гадания по
        -- списку событий.
        vim.api.nvim_create_autocmd("WinClosed", {
            group = focus_group,
            pattern = tostring(float_win),
            once = true,
            callback = function()
                float_win, float_buf = nil, nil
                clear_focus(buf)
            end,
        })
    end

    -- Страховка на случай, если окно не открылось: подсветка всё равно снимется.
    -- BufLeave тут НЕТ намеренно — вход в само окошко (повторный `gl`) даёт
    -- BufLeave на code-буфере и погасил бы подсветку ровно тогда, когда на неё
    -- и смотрят.
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter" }, {
        group = focus_group,
        buffer = buf,
        once = true,
        callback = function() clear_focus(buf) end,
    })

    return float_buf, float_win
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
