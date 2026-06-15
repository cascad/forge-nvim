-- ide/activities.lua — императивный слой «закрыть/найти/сфокусировать» окна
-- инструментов. Перенесён из старого config/panels.lua (проверенная логика),
-- очищен от mode-контроллера. Используется ide/dap.lua и ide.cleanup_for_session.
--
-- Зачем отдельно от ide/state.lua: state — это чистый FSM слотов поверх
-- registry. Здесь же — «грубые» закрыватели для вещей, которые не являются
-- slot-компонентами (quickfix, Diffview) или которые надо снести принудительно
-- (close_activity при смене активности). Один контроллер, два уровня.

local M = {}

-- ------------------------------------------------------------------
-- Таблицы filetypes
-- ------------------------------------------------------------------

local tool_filetypes = {
    ["neo-tree"] = true,
    ["dap-repl"] = true,
    ["dap-view"] = true,
    ["dap-view-term"] = true,
    ["dap-view-help"] = true,
    ["neotest-summary"] = true,
    ["neotest-output-panel"] = true,
    ["OverseerList"] = true,
    ["overseer"] = true,
    ["overseer-list"] = true,
    ["grug-far"] = true,
    ["qf"] = true,
}

local session_unsafe_filetypes = vim.tbl_extend("force", tool_filetypes, {
    ["alpha"] = true,
    ["lazy"] = true,
    ["mason"] = true,
    ["TelescopePrompt"] = true,
    ["TelescopeResults"] = true,
})

local session_unsafe_buftypes = {
    ["nofile"] = true,
    ["prompt"] = true,
    ["quickfix"] = true,
    ["terminal"] = true,
}

local explorer_modes = {
    files = true,
    buffers = true,
    git = true,
}

local debug_filetypes = {
    ["dap-repl"] = true,
    ["dapui_scopes"] = true,
    ["dapui_watches"] = true,
    ["dapui_stacks"] = true,
    ["dapui_breakpoints"] = true,
    ["dapui_console"] = true,
}

M.debug_filetypes = debug_filetypes

-- ------------------------------------------------------------------
-- Низкоуровневые helpers
-- ------------------------------------------------------------------

local function pcall_cmd(cmd)
    pcall(vim.cmd, cmd)
end

local function ide_safe()
    local ok, ide = pcall(require, "ide")
    return ok and ide or nil
end

local function load_lazy(plugin)
    local ok, lazy = pcall(require, "lazy")
    if ok then pcall(lazy.load, { plugins = { plugin } }) end
end

function M.get_neotest()
    local ok, neotest = pcall(require, "neotest")
    if not ok then
        load_lazy("neotest")
        ok, neotest = pcall(require, "neotest")
    end
    return ok and neotest or nil
end

function M.get_overseer()
    local ok, overseer = pcall(require, "overseer")
    if not ok then
        load_lazy("overseer.nvim")
        ok, overseer = pcall(require, "overseer")
    end
    return ok and overseer or nil
end

local function close_windows(match)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if match(buf, win) then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
    end
end
M.close_windows = close_windows

local function close_filetypes(filetypes)
    close_windows(function(buf)
        return filetypes[vim.bo[buf].filetype] == true
    end)
end

local function find_window(ft, predicate)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local matches_ft = not ft or vim.bo[buf].filetype == ft
            local matches_predicate = not predicate or predicate(buf, win)
            if matches_ft and matches_predicate then
                return win
            end
        end
    end
end
M.find_window = find_window

function M.is_visible(ft, predicate)
    return find_window(ft, predicate) ~= nil
end

local function has_buffer_filetype(ft)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == ft then
            return true
        end
    end
    return false
end

function M.focus_window(ft, predicate)
    local win = find_window(ft, predicate)
    if win then
        vim.api.nvim_set_current_win(win)
        return true
    end
    return false
end

local function is_code_window(win)
    if not vim.api.nvim_win_is_valid(win) then return false end
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    local bt = vim.bo[buf].buftype
    return not tool_filetypes[ft] and bt ~= "nofile" and bt ~= "prompt"
end

local function find_code_window()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_code_window(win) then
            return win
        end
    end
end
M.find_code_window = find_code_window

function M.focus_code_window()
    local win = find_code_window()
    if win then
        vim.api.nvim_set_current_win(win)
        return true
    end
    return false
end

function M.neo_tree_source(source)
    return function(buf)
        return vim.b[buf].neo_tree_source == source
    end
end

function M.focus_later(ft, predicate)
    vim.schedule(function()
        if M.focus_window(ft, predicate) then return end
        vim.defer_fn(function()
            M.focus_window(ft, predicate)
        end, 50)
    end)
end

function M.focus_code_later()
    vim.schedule(function()
        if M.focus_code_window() then return end
        vim.defer_fn(M.focus_code_window, 50)
    end)
end

function M.any_filetype_visible(filetypes)
    return find_window(nil, function(buf)
        return filetypes[vim.bo[buf].filetype] == true
    end) ~= nil
end

function M.is_debug_buffer(buf)
    return debug_filetypes[vim.bo[buf].filetype] == true
end

function M.is_jobs_buffer(buf)
    local ft = vim.bo[buf].filetype:lower()
    local name = vim.api.nvim_buf_get_name(buf):lower()
    return ft:find("overseer", 1, true) ~= nil
        or name:find("overseer", 1, true) ~= nil
end

-- ------------------------------------------------------------------
-- Закрыватели активностей
-- ------------------------------------------------------------------

function M.close_files()
    if package.loaded["neo-tree"] or has_buffer_filetype("neo-tree") then
        pcall_cmd("Neotree close")
    end
    close_filetypes({ ["neo-tree"] = true })
end

function M.close_debug()
    local ide = ide_safe()
    if ide then
        ide.hide("dap.sidebar")
        ide.hide("dap.console")
        ide.hide("dap.repl")
    else
        local ok, dapui = pcall(require, "dapui")
        if ok then
            pcall(dapui.close, { layout = 1 })
            pcall(dapui.close, { layout = 2 })
            pcall(dapui.close, { layout = 3 })
        end
    end
    close_filetypes(debug_filetypes)
end

function M.close_tests()
    local neotest = package.loaded["neotest"]
    if neotest then
        pcall(neotest.summary.close)
        pcall(neotest.output_panel.close)
    end
    close_filetypes({
        ["neotest-summary"] = true,
        ["neotest-output-panel"] = true,
    })
end

function M.close_jobs()
    local overseer = package.loaded["overseer"]
    if overseer then pcall(overseer.close) end
    pcall_cmd("OverseerClose")
end

function M.close_search()
    pcall_cmd("GrugFarClose")
    close_filetypes({ ["grug-far"] = true })
end

function M.close_quickfix()
    pcall_cmd("cclose")
end

function M.close_git_diff()
    pcall_cmd("DiffviewClose")
end

function M.stop_debug()
    local dap = package.loaded["dap"]
    if not dap or not dap.session or not dap.session() then
        return false
    end

    local ok = pcall(function()
        dap.terminate({ terminateDebuggee = true })
    end)
    if not ok then
        pcall(function()
            dap.disconnect({ terminateDebuggee = true })
        end)
    end

    return true
end

---@param except? string  имя активности, которую НЕ закрывать
function M.close_activity(except)
    if not explorer_modes[except] then M.close_files() end
    if except ~= "debug" then M.close_debug() end
    if except ~= "tests" then M.close_tests() end
    if except ~= "jobs" then M.close_jobs() end
    if except ~= "search" then M.close_search() end
    if except ~= "quickfix" then M.close_quickfix() end
    if except ~= "git-diff" then M.close_git_diff() end
end

-- ------------------------------------------------------------------
-- Подготовка сессии: вытащить файлы из панелей, закрыть tool-окна/буферы.
-- (Перенос panels.prepare_session_save; зовётся как ide.cleanup_for_session.)
-- ------------------------------------------------------------------

function M.cleanup_for_session()
    -- Сначала вытаскиваем залипшие в панелях файлы обратно в редактор —
    -- чтобы в сессию НЕ попал layout с файлом в edgebar'е (см.
    -- forge/panel_guard.lua, FIXLOG §22).
    pcall(function() require("forge.panel_guard").sweep() end)

    M.close_activity(nil)

    close_windows(function(buf)
        return session_unsafe_filetypes[vim.bo[buf].filetype] == true
            or session_unsafe_buftypes[vim.bo[buf].buftype] == true
    end)

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
            local ft = vim.bo[buf].filetype
            local bt = vim.bo[buf].buftype
            local name = vim.api.nvim_buf_get_name(buf)
            if session_unsafe_filetypes[ft] or session_unsafe_buftypes[bt] or name:find("neo%-tree", 1, false) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
end

return M
