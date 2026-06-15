-- ide/dap.lua — DAP UI-оркестрация поверх ide.state (slot-контроллер).
-- Перенос «debug-мозга» из старого config/panels.lua БЕЗ изменения логики:
-- только убран mode-контроллер (current_mode) и пути на ide/activities.
--
-- Конвенция секций (см. plugins/dap.lua → section_for_config):
--   "console"  → ide.show("dap.console") (layout 2 — bottom, codelldb/PTY)
--   "repl"     → ide.show("dap.repl")    (layout 3 — bottom, Go/Python)
--   "terminal" → bottom не открываем сами: окно создаст dap_terminal_win_cmd
--                при runInTerminal (см. plugins/dap.lua)
--   "scopes"/"watches"/"stacks"/"threads"/"breakpoints" → left sidebar + фокус
--   nil        → только left sidebar; bottom не трогаем (F5 до известного типа)

local activities = require("ide.activities")

local M = {}

-- ide требуем лениво внутри функций — иначе цикл (ide/init → ide.dap → ide).
local function ide()
    local ok, mod = pcall(require, "ide")
    return ok and mod or nil
end

local DAPUI_SECTION_TO_FT = {
    scopes      = "dapui_scopes",
    watches     = "dapui_watches",
    stacks      = "dapui_stacks",
    threads     = "dapui_stacks", -- alias: VS Code "Call Stack" → dapui stacks
    breakpoints = "dapui_breakpoints",
}

local function dapui_focus_ft(ft)
    if not ft then return false end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == ft then
                pcall(vim.api.nvim_set_current_win, win)
                return true
            end
        end
    end
    return false
end

-- @param section nil | "console" | "repl" | "terminal" | "scopes" | "watches"
--                | "stacks" | "threads" | "breakpoints"
-- @param enter   boolean — ставить ли фокус в debug-окно (иначе фокус в код)
function M.show_section(section, enter)
    activities.close_activity("debug")

    local mod = ide()
    if not mod then
        activities.focus_code_later()
        return
    end

    mod.show("dap.sidebar")

    local sidebar_section_ft = DAPUI_SECTION_TO_FT[section]
    if section == "repl" then
        mod.show("dap.repl")
    elseif section == "console" then
        mod.show("dap.console")
    elseif section == "terminal" then
        -- НЕ открываем сами dap.terminal — окно создаётся
        -- dap_terminal_win_cmd когда codelldb пришлёт runInTerminal.
        -- Закрываем предыдущий bottom (вдруг там repl от прошлой сессии).
        mod.hide_slot("bottom")
    end
    -- nil или sidebar_section_ft: bottom не трогаем — он откроется позже
    -- (event_initialized listener в plugins/dap.lua), когда тип адаптера ясен.

    if enter then
        if sidebar_section_ft and dapui_focus_ft(sidebar_section_ft) then
            return
        end
        activities.focus_later(nil, activities.is_debug_buffer)
    else
        activities.focus_code_later()
    end
end

-- Открыть debug-view (sidebar + bottom по типу активной сессии).
-- По умолчанию Console; для Go/delve — REPL (delve в mode=debug шлёт stdout
-- через DAP output events в REPL, а не в integratedTerminal).
function M.open()
    local section = "console"
    local ok, dap = pcall(require, "dap")
    if ok then
        local session = dap.session()
        local type_ = session and session.config and session.config.type
        if type_ == "go" or type_ == "delve" then
            section = "repl"
        end
    end
    M.show_section(section, false)
end

function M.toggle()
    if activities.any_filetype_visible(activities.debug_filetypes) then
        activities.close_debug()
        activities.focus_code_window()
    else
        M.open()
    end
end

function M.close()
    activities.close_debug()
end

-- Bottom = Console (PTY дебагги-процесса), с фокусом.
function M.show_console()
    M.show_section("console", true)
end

-- Bottom = REPL (interactive DAP REPL), с фокусом.
function M.show_repl()
    M.show_section("repl", true)
end

-- Сфокусировать конкретную sidebar-секцию (scopes/watches/stacks/threads/
-- breakpoints) или bottom-секцию (console/repl), открыв нужный layout.
function M.focus_section(name)
    M.show_section(name, true)
end

-- Остановить активную DAP-сессию (re-export).
M.stop = activities.stop_debug

return M
