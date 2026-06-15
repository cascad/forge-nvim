-- IDE-фреймворк: тонкий facade над state + registry + layouts.
-- Вызывается из nvim_forge/init.lua после загрузки плагинов
-- (через VeryLazy hook или сразу — все компоненты регистрируются
-- ленivo, плагины не дёргаются при registration).
--
-- Архитектура и инварианты — в docs/PANELS_PLAN.md.

local M = {}

local registry = require("ide.registry")
local state    = require("ide.state")
local layouts  = require("ide.layouts")
local empty    = require("ide.empty")

-- Реэкспортируем подмодули для интроспекции (`:lua print(vim.inspect(
-- require('ide').state.current()))`).
M.registry = registry
M.state    = state
M.layouts  = layouts
M.empty    = empty

-- Высокоуровневое API.
M.show         = state.show
M.hide         = state.hide
M.hide_slot    = state.hide_slot
M.toggle       = state.toggle
M.toggle_slot  = state.toggle_slot
M.cycle        = state.cycle
M.apply_layout = state.apply_layout
M.focus_main   = state.focus_main
M.focus_slot   = state.focus_slot
M.current      = state.current
M.list_layouts = state.list_layouts
M.find_main_window = state.find_main_window
M.is_main_window   = state.is_main_window

-- Единый toggle панелей + фокус по панелям (см. ide/state.lua).
M.toggle_panels    = state.toggle_panels
M.focus_next_panel = state.focus_next_panel
M.focus_panel      = state.focus_panel

-- DAP-оркестрация (см. ide/dap.lua). Требуем лениво, чтобы не словить
-- цикл require (ide → ide.dap → ide).
M.dap = setmetatable({}, {
    __index = function(_, k) return require("ide.dap")[k] end,
})

-- Декларативные триггеры авто-открытия панелей (см. ide/triggers.lua).
M.triggers = setmetatable({}, {
    __index = function(_, k) return require("ide.triggers")[k] end,
})

-- Закрыть ВСЕ tool-окна + остановить debug-сессию.
function M.close_ide()
    local activities = require("ide.activities")
    local had_debug = activities.stop_debug()
    activities.close_activity(nil)
    M.apply_layout("code") -- синхронизируем state + фокус в main
    if had_debug then
        -- DAP может слать поздние события при terminate — дочищаем.
        vim.defer_fn(function()
            activities.close_debug()
            activities.focus_code_window()
        end, 120)
    end
end

-- Подготовка к сохранению сессии: вытащить файлы из панелей, закрыть
-- tool-окна/буферы (см. ide/activities.lua, forge/panel_guard.lua).
function M.cleanup_for_session()
    require("ide.activities").cleanup_for_session()
end

-- =============================================================
-- Helpers для определения is_open по filetype
-- =============================================================

local function any_window_with_ft(ft, predicate)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == ft then
                if not predicate or predicate(buf) then
                    return true
                end
            end
        end
    end
    return false
end

local function neo_tree_open_with_source(source)
    return any_window_with_ft("neo-tree", function(buf)
        return vim.b[buf].neo_tree_source == source
    end)
end

local function safe_require(modname)
    local ok, mod = pcall(require, modname)
    return ok and mod or nil
end

-- =============================================================
-- Component specs (default; можно дополнять через setup{components=...})
-- =============================================================

---@type ide.Component[]
local default_components = {
    -- ===========================================================
    -- LEFT
    -- ===========================================================
    {
        id = "explorer", slot = "left", title = "Explorer",
        filetypes = { "neo-tree" },
        open    = function() vim.cmd("Neotree filesystem reveal left") end,
        close   = function()
            if neo_tree_open_with_source("filesystem") then
                pcall(vim.cmd, "Neotree close")
            end
        end,
        is_open = function() return neo_tree_open_with_source("filesystem") end,
    },
    {
        id = "buffers", slot = "left", title = "Buffers",
        filetypes = { "neo-tree" },
        open    = function() vim.cmd("Neotree buffers reveal left") end,
        close   = function()
            if neo_tree_open_with_source("buffers") then
                pcall(vim.cmd, "Neotree close")
            end
        end,
        is_open = function() return neo_tree_open_with_source("buffers") end,
    },
    {
        id = "git_status", slot = "left", title = "Git Files",
        filetypes = { "neo-tree" },
        open    = function() vim.cmd("Neotree git_status reveal left") end,
        close   = function()
            if neo_tree_open_with_source("git_status") then
                pcall(vim.cmd, "Neotree close")
            end
        end,
        is_open = function() return neo_tree_open_with_source("git_status") end,
    },
    {
        id = "outline", slot = "left", title = "Outline",
        filetypes = { "aerial" },
        open    = function() pcall(vim.cmd, "AerialOpen left") end,
        close   = function() pcall(vim.cmd, "AerialClose") end,
        is_open = function() return any_window_with_ft("aerial") end,
    },

    -- ===========================================================
    -- RIGHT
    -- ===========================================================
    {
        id = "tests", slot = "right", title = "Tests",
        filetypes = { "neotest-summary" },
        open = function()
            local nt = safe_require("neotest")
            if nt then pcall(nt.summary.open) end
        end,
        close = function()
            local nt = safe_require("neotest")
            if nt then pcall(nt.summary.close) end
        end,
        is_open = function() return any_window_with_ft("neotest-summary") end,
    },
    {
        id = "neogit", slot = "right", title = "Neogit",
        filetypes = { "NeogitStatus" },
        open = function()
            local ng = safe_require("neogit")
            if ng then pcall(ng.open, { kind = "split" }) end
        end,
        close = function()
            -- Neogit close — это просто bdelete окна со статусом.
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_is_valid(win) then
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].filetype == "NeogitStatus" then
                        pcall(vim.api.nvim_win_close, win, true)
                    end
                end
            end
        end,
        is_open = function() return any_window_with_ft("NeogitStatus") end,
    },

    -- ===========================================================
    -- LEFT (DAP sidebar — composite через nvim-dap-ui layout 1).
    -- ===========================================================
    --
    -- Один ide-компонент `dap.sidebar` открывает РАЗОМ четыре окна
    -- (scopes/watches/stacks/breakpoints) через `dapui.open({layout=1})`.
    -- Edgy потом ловит каждое окно по filetype `dapui_*` и стэкает
    -- внутри left edgebar (см. plugins/edgy.lua).
    --
    -- Это единственный "composite" компонент в нашем FSM: одно
    -- логическое open => несколько физических окон в одном слоте.
    {
        id = "dap.sidebar", slot = "left", title = "Debug",
        filetypes = {
            "dapui_scopes", "dapui_watches", "dapui_stacks", "dapui_breakpoints",
        },
        open = function()
            local ok, dapui = pcall(require, "dapui")
            if ok then pcall(dapui.open, { layout = 1, reset = true }) end
        end,
        close = function()
            local ok, dapui = pcall(require, "dapui")
            if ok then pcall(dapui.close, { layout = 1 }) end
        end,
        is_open = function() return any_window_with_ft("dapui_scopes") end,
    },

    -- ===========================================================
    -- BOTTOM (DAP console / DAP REPL — взаимоисключающие).
    -- ===========================================================
    {
        id = "dap.console", slot = "bottom", title = "Debug Console",
        filetypes = { "dapui_console" },
        open = function()
            local ok, dapui = pcall(require, "dapui")
            if ok then pcall(dapui.open, { layout = 2, reset = true }) end
        end,
        close = function()
            local ok, dapui = pcall(require, "dapui")
            if ok then pcall(dapui.close, { layout = 2 }) end
        end,
        is_open = function() return any_window_with_ft("dapui_console") end,
    },
    {
        -- Свежий PTY-буфер codelldb (см. plugins/dap.lua →
        -- dap_terminal_win_cmd). Окно создаётся самим terminal_win_cmd
        -- при runInTerminal-запросе адаптера, поэтому open/close здесь
        -- "пассивные" — мы не открываем сами, только закрываем/находим.
        id = "dap.terminal", slot = "bottom", title = "DAP Terminal",
        filetypes = { "dap-terminal" },
        open = function()
            -- Если уже есть видимое окно dap-terminal — фокус оставляем
            -- как есть (ide.state idempotent). Если буфер есть, но окно
            -- закрыто — re-open в bottom-split, edgy подхватит.
            local last_buf
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(win) then
                    local b = vim.api.nvim_win_get_buf(win)
                    if vim.bo[b].filetype == "dap-terminal" then
                        return
                    end
                end
            end
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(b)
                    and vim.bo[b].filetype == "dap-terminal" then
                    last_buf = b
                    break
                end
            end
            if last_buf then
                pcall(vim.api.nvim_open_win, last_buf, false, {
                    split = "below", win = -1,
                    height = math.max(10, math.floor(vim.o.lines * 0.3)),
                })
            end
        end,
        close = function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(win) then
                    local b = vim.api.nvim_win_get_buf(win)
                    if vim.bo[b].filetype == "dap-terminal" then
                        pcall(vim.api.nvim_win_close, win, true)
                    end
                end
            end
        end,
        is_open = function() return any_window_with_ft("dap-terminal") end,
    },
    {
        id = "dap.repl", slot = "bottom", title = "DAP REPL",
        filetypes = { "dap-repl" },
        open = function()
            local ok, dapui = pcall(require, "dapui")
            if ok then pcall(dapui.open, { layout = 3, reset = true }) end
        end,
        close = function()
            local ok, dapui = pcall(require, "dapui")
            if ok then pcall(dapui.close, { layout = 3 }) end
        end,
        is_open = function() return any_window_with_ft("dap-repl") end,
    },
    {
        id = "tasks_output", slot = "bottom", title = "Tasks",
        filetypes = { "OverseerList" },
        open = function() pcall(vim.cmd, "OverseerOpen bottom") end,
        close = function() pcall(vim.cmd, "OverseerClose") end,
        is_open = function() return any_window_with_ft("OverseerList") end,
    },
    {
        id = "tests_output", slot = "bottom", title = "Test Output",
        filetypes = { "neotest-output-panel" },
        open = function()
            local nt = safe_require("neotest")
            if nt then pcall(nt.output_panel.open) end
        end,
        close = function()
            local nt = safe_require("neotest")
            if nt then pcall(nt.output_panel.close) end
        end,
        is_open = function() return any_window_with_ft("neotest-output-panel") end,
    },
    {
        id = "search", slot = "bottom", title = "Search",
        filetypes = { "grug-far" },
        -- GrugFar при каждом вызове создаёт НОВЫЙ buffer/split. Если делать
        -- его без проверки, после нескольких <leader>ps в bufferline (и
        -- внутри edgy) висят grug-far #1, #2, #3. Поэтому:
        --   1) если уже есть видимое окно grug-far — просто фокус;
        --   2) если есть буфер grug-far, но он не отображён — reuse в split;
        --   3) иначе — создать новый через :GrugFar.
        open = function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_is_valid(win) then
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].filetype == "grug-far" then
                        pcall(vim.api.nvim_set_current_win, win)
                        return
                    end
                end
            end
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(b)
                    and vim.bo[b].filetype == "grug-far" then
                    pcall(vim.cmd, "botright split | buffer " .. b)
                    return
                end
            end
            pcall(vim.cmd, "GrugFar")
        end,
        -- GrugFarClose закрывает только одно окно; обходим все, плюс
        -- зачищаем сами буферы — иначе они остаются live и при следующем
        -- `:GrugFar` всплывают как pre-existing.
        close = function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_is_valid(win) then
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].filetype == "grug-far" then
                        pcall(vim.api.nvim_win_close, win, true)
                    end
                end
            end
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(b)
                    and vim.bo[b].filetype == "grug-far" then
                    pcall(vim.api.nvim_buf_delete, b, { force = true })
                end
            end
        end,
        is_open = function() return any_window_with_ft("grug-far") end,
    },
    {
        id = "trouble", slot = "bottom", title = "Trouble",
        filetypes = { "trouble" },
        open = function() pcall(vim.cmd, "Trouble diagnostics") end,
        close = function() pcall(vim.cmd, "Trouble close") end,
        is_open = function() return any_window_with_ft("trouble") end,
    },
    {
        id = "quickfix", slot = "bottom", title = "QuickFix",
        filetypes = { "qf" },
        open = function() pcall(vim.cmd, "copen") end,
        close = function() pcall(vim.cmd, "cclose") end,
        is_open = function() return any_window_with_ft("qf") end,
    },
    {
        id = "terminal", slot = "bottom", title = "Terminal",
        filetypes = { "toggleterm" },
        open = function() pcall(vim.cmd, "ToggleTerm direction=horizontal") end,
        -- toggleterm имеет несколько окон — закрываем все
        -- горизонтальные через TermNew API. Простой `close` close'ает
        -- активный — этого хватает.
        close = function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_is_valid(win) then
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].filetype == "toggleterm" then
                        pcall(vim.api.nvim_win_close, win, true)
                    end
                end
            end
        end,
        is_open = function() return any_window_with_ft("toggleterm") end,
    },
}

-- =============================================================
-- Default layouts
-- =============================================================

---@type table<string, ide.Layout>
local default_layouts = {
    code     = { left = nil,           right = nil,      bottom = nil           },
    files    = { left = "explorer",    right = nil,      bottom = nil           },
    buffers  = { left = "buffers",     right = nil,      bottom = nil           },
    outline  = { left = "outline",     right = nil,      bottom = nil           },
    git      = { left = "git_status",  right = "neogit", bottom = nil           },
    -- DAP layout (VS Code Run-and-Debug):
    --   * left   = sidebar с 4 секциями (scopes/watches/stacks/breakpoints)
    --   * bottom = dap.terminal — НАШ свежий PTY-буфер для codelldb
    --     (Rust/C/C++). Создаётся dap_terminal_win_cmd при runInTerminal.
    --     Для Go/Python (internalConsole) event_initialized listener
    --     переключит bottom на dap.repl (см. plugins/dap.lua).
    debug    = { left = "dap.sidebar", right = nil,      bottom = "dap.terminal" },
    tests    = { left = "explorer",    right = "tests",  bottom = "tests_output"},
    search   = { left = nil,           right = nil,      bottom = "search"      },
    jobs     = { left = nil,           right = nil,      bottom = "tasks_output"},
    trouble  = { left = nil,           right = nil,      bottom = "trouble"     },
    term     = { left = nil,           right = nil,      bottom = "terminal"    },
}

-- =============================================================
-- Setup
-- =============================================================

---@class ide.SetupOpts
---@field components? ide.Component[]            -- доп. компоненты
---@field layouts?    table<string, ide.Layout>  -- доп. layouts
---@field replace?    boolean                     -- false: merge с дефолтами, true: только переданное

---@param opts? ide.SetupOpts
function M.setup(opts)
    opts = opts or {}

    if not opts.replace then
        for _, spec in ipairs(default_components) do
            registry.register(spec)
        end
        for name, def in pairs(default_layouts) do
            state.register_layout(name, def)
        end
    end

    if opts.components then
        for _, spec in ipairs(opts.components) do
            registry.register(spec)
        end
    end
    if opts.layouts then
        for name, def in pairs(opts.layouts) do
            state.register_layout(name, def)
        end
    end

    -- Маркировка tool-окон (w:forge_panel/slot/component) — после того, как
    -- компоненты зарегистрированы (marks строит карту ft→component из registry).
    require("ide.marks").setup()

    -- User commands для интроспекции и быстрого вызова.
    vim.api.nvim_create_user_command("IdeShow", function(o)
        M.show(o.args)
    end, { nargs = 1, complete = function()
        local ids = {}
        for id in pairs(registry.all()) do table.insert(ids, id) end
        table.sort(ids)
        return ids
    end })

    vim.api.nvim_create_user_command("IdeLayout", function(o)
        M.apply_layout(o.args)
    end, { nargs = 1, complete = function() return state.list_layouts() end })

    vim.api.nvim_create_user_command("IdeClose", function()
        M.close_ide()
    end, { desc = "Закрыть все tool-окна и остановить debug-сессию" })

    vim.api.nvim_create_user_command("IdeMode", function()
        require("ide.layouts").select()
    end, { desc = "Выбрать layout (vim.ui.select)" })

    vim.api.nvim_create_user_command("IdeStatus", function()
        local cur = M.current()
        local lines = {
            "Layout: " .. tostring(cur.layout or "(none)"),
            "Slots:",
            "  left   = " .. tostring(cur.slots.left   or "-"),
            "  right  = " .. tostring(cur.slots.right  or "-"),
            "  bottom = " .. tostring(cur.slots.bottom or "-"),
        }
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "ide" })
    end, {})

    -- Если при старте проекта не открыт ни один code-буфер (session был
    -- очищен, либо открыли просто директорию и закрыли скретч), показываем
    -- alpha welcome screen вместо безымянного Noname-буфера.
    --
    -- Делается через VimEnter + vim.schedule, чтобы:
    --   * succeed после autocmd'а neo-tree.lua (он создаёт scratch);
    --   * увидеть итоговый набор буферов после lazy + session restore.
    vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("IdeEmptyOnStart", { clear = true }),
        once = true,
        nested = true,
        callback = function()
            vim.schedule(function()
                -- Если уже видим alpha — ничего не делать.
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    if vim.api.nvim_win_is_valid(win) then
                        local buf = vim.api.nvim_win_get_buf(win)
                        if vim.bo[buf].filetype == "alpha" then return end
                    end
                end

                -- Если есть хотя бы один обычный code-буфер — ничего не
                -- делать, юзер уже открыл файл.
                for _, b in ipairs(vim.api.nvim_list_bufs()) do
                    if empty.is_code_buffer(b) then return end
                end

                -- Иначе — найти main editor window и подменить его буфер на
                -- alpha. find_main_window умеет создавать main, если он по
                -- какой-то причине не существует.
                local main = M.find_main_window()
                if not (main and vim.api.nvim_win_is_valid(main)) then return end

                pcall(vim.api.nvim_set_current_win, main)
                local prev_buf = vim.api.nvim_win_get_buf(main)
                empty.open_alpha_screen()

                -- Удалить предыдущий пустой "Noname" буфер, чтобы он не
                -- торчал в :ls.
                if vim.api.nvim_buf_is_valid(prev_buf)
                    and vim.api.nvim_buf_get_name(prev_buf) == ""
                    and vim.bo[prev_buf].buftype == ""
                    and not vim.bo[prev_buf].modified
                then
                    pcall(vim.api.nvim_buf_delete, prev_buf, { force = true })
                end
            end)
        end,
    })
end

return M
