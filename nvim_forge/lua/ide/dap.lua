-- ide/dap.lua — DAP UI-оркестрация поверх ide.state (slot-контроллер).
-- Конвенция секций:
--   "console"  → ide.show("dap.console") (layout 2 — явная Debug Console)
--   "repl"     → ide.show("dap.repl")    (layout 3 — bottom, Go/Python)
--   "terminal" → bottom не открываем сами: окно создаст dap_terminal_win_cmd
--                при runInTerminal (см. plugins/dap.lua)
--   "scopes"/"watches"/"stacks"/"threads"/"breakpoints" → left sidebar + фокус
--   nil        → только left sidebar; bottom не трогаем (F5 до известного типа)

local activities = require("ide.activities")

local M = {}
local last_output = 'repl'
local OUTPUT_FT = { repl = 'dap-repl', console = 'dapui_console', terminal = 'dap-terminal' }

function M.remember_output(section)
    if OUTPUT_FT[section] then last_output = section end
end

-- spec: IDE-PANEL-11. Конфигурация выбирает канал нового запуска;
-- ручное открытие возвращает видимый либо последний выбранный Output.
function M.output_section(cfg)
    if cfg ~= nil then
        local type_ = type(cfg) == 'table' and cfg.type or cfg
        if type_ == 'codelldb' then return 'terminal' end
        -- spec: IDE-DAP-1 remote Delve использует output events даже
        -- при сохранённом console=integratedTerminal в launch.json.
        if (type_ == 'go' or type_ == 'delve') and type(cfg) == 'table' and cfg.outputMode == 'remote' then return 'repl' end
        if type(cfg) == 'table' and cfg.console == 'integratedTerminal' then return 'terminal' end
        return 'repl'
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative == '' then
            local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
            for section, output_ft in pairs(OUTPUT_FT) do
                if ft == output_ft then return section, win end
            end
        end
    end
    return last_output
end

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
function M.show_section(section, enter, reuse_terminal)
    -- spec: IDE-LOG-1. Поздний возврат не отменяет новый явный выбор панели.
    local requester=vim.api.nvim_get_current_win()
    local function owns_focus()
        return vim.api.nvim_get_current_win()==requester
            or activities.is_debug_buffer(vim.api.nvim_get_current_buf())
    end
    activities.close_activity("debug")

    local mod = ide()
    if not mod then
        activities.focus_code_later(owns_focus)
        return
    end

    mod.show("dap.sidebar")

    local sidebar_section_ft = DAPUI_SECTION_TO_FT[section]
    if section == "repl" then
        mod.show("dap.repl")
    elseif section == "console" then
        mod.show("dap.console")
    elseif section == "terminal" then
        if reuse_terminal then
            -- Пассивный компонент показывает сохранённый buffer, без termopen.
            mod.show('dap.terminal')
        else
            -- Новый запуск: свежий PTY создаст только runInTerminal.
            mod.hide_slot('bottom')
        end
    end
    -- Закрытие прежнего компонента не должно перезаписать новый выбор.
    M.remember_output(section)
    -- nil или sidebar_section_ft: bottom не трогаем — он откроется позже
    -- (event_initialized listener в plugins/dap.lua), когда тип адаптера ясен.

    if enter then
        if sidebar_section_ft and dapui_focus_ft(sidebar_section_ft) then
            return
        end
        activities.focus_later(OUTPUT_FT[section], activities.is_debug_buffer)
    else
        activities.focus_code_later(owns_focus)
    end
end

-- Ручной Debug View сохраняет пользовательский выбор и историю после exit.
function M.open()
    M.show_section(M.output_section(), false, true)
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

-- Явная Debug Console, с фокусом.
function M.show_console()
    M.show_section("console", true)
end

-- Bottom = REPL (interactive DAP REPL), с фокусом.
function M.show_repl()
    M.show_section("repl", true)
end

-- Сохраняем канал вывода: скрытый PTY не заменяется пустым REPL.
function M.focus_output()
    local section, win = M.output_section()
    if win then
        M.remember_output(section)
        vim.api.nvim_set_current_win(win)
        return
    end
    local mod = ide()
    if not mod then return end
    mod.show('dap.' .. section)
    M.remember_output(section)
    vim.schedule(function()
        dapui_focus_ft(OUTPUT_FT[section])
    end)
end

-- Сфокусировать конкретную sidebar-секцию (scopes/watches/stacks/threads/
-- breakpoints) или bottom-секцию (console/repl), открыв нужный layout.
function M.focus_section(name)
    M.show_section(name, true)
end

-- Остановить активную DAP-сессию (re-export).
M.stop = activities.stop_debug

return M
