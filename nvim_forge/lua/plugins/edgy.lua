-- Edge-bar window manager. Захватывает tool-окна (neo-tree, dap-view,
-- aerial, toggleterm, overseer, neotest, grug-far, trouble, qf,
-- neogit-split) и кладёт их в left/right/bottom edgebar.
--
-- Архитектура и слой состояния (cycle, layouts, focus) — наш собственный
-- ide framework, см.:
--   lua/ide/init.lua         — facade + регистрация компонентов
--   lua/ide/state.lua        — FSM (slot transitions, инварианты)
--   lua/ide/layouts.lua      — именованные пресеты
--   config/keymaps.lua       — <leader>p* и <leader>P*
--   docs/PANELS_PLAN.md      — общий план
--
-- Pre-flight: см. config/options.lua → laststatus=3 и splitkeep=screen.
-- Оба обязательны: без них collapse views ломается, а main-splits
-- прыгают при открытии edgebar'а.
--
-- Editor-area views (Diffview, Neogit log, GitGraph): эти штуки
-- открываются в основной editor group, а не в edgebar. Чтобы edgy их
-- не подхватывал, ставим buffer-local vim.b[buf].edgy_disable = true
-- через autocmd (см. ниже).

-- Tool-окна, которые edgy кладёт в edgebar'ы. Для них:
--   * buflisted=false — чтобы не торчали в bufferline / `:ls` как файлы
--     (раньше GrugFar #1 / #2 выглядели как обычные файлы);
--   * edgy_disable НЕ ставим — edgy именно их и должен ловить.
local TOOL_FILETYPES = {
    "grug-far",
    "dap-repl",
    "dapui_scopes", "dapui_watches", "dapui_stacks", "dapui_breakpoints",
    "dapui_console", "dap-terminal",
    "neotest-summary", "neotest-output-panel",
    "OverseerList",
    "trouble",
    "aerial", "toggleterm",
    "NeogitStatus",
}

local function setup_edgy_disable_autocmds()
    local group = vim.api.nvim_create_augroup("ForgeEdgyDisable", { clear = true })

    -- Tool-окна никогда не должны быть `buflisted` — иначе они утекают в
    -- bufferline и выглядят как обычные файлы (см. жалобу про GrugFar #1/#2).
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = TOOL_FILETYPES,
        callback = function(ev)
            vim.bo[ev.buf].buflisted = false
        end,
    })

    -- Diffview: tabpage-mode, всё там — editor area.
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "DiffviewFiles", "DiffviewFileHistory", "DiffviewStatus" },
        callback = function(ev) vim.b[ev.buf].edgy_disable = true end,
    })

    -- Neogit log (commit history view) — открываем в editor area
    -- как git-graph-replacement. Базовый NeogitStatus с kind="split"
    -- ловим в edgebar (см. right.NeogitStatus filter); kind="tab"
    -- пройдёт мимо edgy потому что относительные окна вообще не
    -- ловятся (или filter их отсеет).
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "NeogitLogView", "NeogitReflogView", "NeogitCommitView" },
        callback = function(ev) vim.b[ev.buf].edgy_disable = true end,
    })

    -- gitgraph.nvim (если установлен — открывается как обычный
    -- buffer, мы помечаем как editor-area).
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "gitgraph",
        callback = function(ev) vim.b[ev.buf].edgy_disable = true end,
    })

    -- Alpha welcome screen — editor area, не edgebar.
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "alpha",
        callback = function(ev) vim.b[ev.buf].edgy_disable = true end,
    })
end

return {
    {
        "folke/edgy.nvim",
        event = "VeryLazy",
        opts = {
            -- ===========================================================
            --  LEFT edgebar: Neo-Tree (3 source'а через filter) + Aerial
            -- ===========================================================
            left = {
                {
                    title = "Explorer",
                    ft = "neo-tree",
                    filter = function(buf)
                        return vim.b[buf].neo_tree_source == "filesystem"
                    end,
                    size = { width = 32, height = 0.5 },
                    pinned = false,
                    open = "Neotree filesystem reveal left",
                },
                {
                    title = "Buffers",
                    ft = "neo-tree",
                    filter = function(buf)
                        return vim.b[buf].neo_tree_source == "buffers"
                    end,
                    size = { width = 32 },
                    pinned = false,
                    open = "Neotree buffers reveal left",
                },
                {
                    title = "Git Files",
                    ft = "neo-tree",
                    filter = function(buf)
                        return vim.b[buf].neo_tree_source == "git_status"
                    end,
                    size = { width = 32 },
                    pinned = false,
                    open = "Neotree git_status reveal left",
                },
                {
                    title = "Outline",
                    ft = "aerial",
                    size = { width = 32 },
                    pinned = false,
                    open = "AerialOpen left",
                },

                -- ---------------------------------------------------
                -- DAP sidebar (nvim-dap-ui layout 1): 4 секции в одном
                -- едгебаре. Открываются разом через `dapui.open({layout=1})`
                -- из ide-компонента `dap.sidebar` (см. lua/ide/init.lua).
                -- Edgy подхватывает каждую секцию по filetype и стэкает
                -- их вертикально внутри left edgebar.
                -- ---------------------------------------------------
                {
                    title = "Variables",
                    ft = "dapui_scopes",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    title = "Watch",
                    ft = "dapui_watches",
                    size = { height = 0.20 },
                    pinned = false,
                },
                {
                    title = "Call Stack",
                    ft = "dapui_stacks",
                    size = { height = 0.25 },
                    pinned = false,
                },
                {
                    title = "Breakpoints",
                    ft = "dapui_breakpoints",
                    size = { height = 0.25 },
                    pinned = false,
                },
            },

            -- ===========================================================
            --  RIGHT edgebar: Neotest Summary, Neogit (status split).
            -- ===========================================================
            right = {
                {
                    title = "Tests",
                    ft = "neotest-summary",
                    size = { width = 40 },
                    pinned = false,
                },
                {
                    title = "Neogit",
                    ft = "NeogitStatus",
                    size = { width = 60 },
                    pinned = false,
                    filter = function(buf, win)
                        -- Neogit kind="tab" открывается во весь tabpage,
                        -- захватывать НЕ надо. kind="split" даёт обычный
                        -- side-split — его и кладём в edgebar.
                        return vim.api.nvim_win_get_config(win).relative == ""
                    end,
                },
            },

            -- ===========================================================
            --  BOTTOM edgebar: DAP console / DAP REPL, ToggleTerm, tests,
            --  tasks, search, trouble, quickfix.
            --
            --  DAP в bottom — это либо console (PTY вывод debuggee, Rust/
            --  codelldb), либо repl (interactive DAP REPL, Go/Python).
            --  В одно время видим ОДИН из них, ide.state управляет
            --  переключением через слот bottom (см. ide.init: dap.console
            --  → layout 2, dap.repl → layout 3). Между ними циклит
            --  `<leader>Pb` (вместе с другими bottom-компонентами).
            -- ===========================================================
            bottom = {
                {
                    title = "Debug Console",
                    ft = "dapui_console",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    -- Свежий PTY-буфер codelldb (создаётся нашим
                    -- dap_terminal_win_cmd в plugins/dap.lua). Edgy
                    -- забирает его в bottom edgebar по ft. На каждый
                    -- запуск сессии — новое окно, новый buf, фикс
                    -- "первый println! теряется на Windows".
                    title = "DAP Terminal",
                    ft = "dap-terminal",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    title = "DAP REPL",
                    ft = "dap-repl",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    title = "Test Output",
                    ft = "neotest-output-panel",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    title = "Tasks",
                    ft = "OverseerList",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    title = "Terminal",
                    ft = "toggleterm",
                    size = { height = 0.30 },
                    pinned = false,
                    filter = function(_, win)
                        -- Только horizontal/vertical toggleterm попадают в
                        -- bottom edgebar. Float-окна (`<leader>tT`) едут
                        -- как floating и не должны попадать в edgy.
                        local cfg = vim.api.nvim_win_get_config(win)
                        return cfg.relative == ""
                    end,
                },
                {
                    title = "Search",
                    ft = "grug-far",
                    size = { height = 0.40 },
                    pinned = false,
                },
                {
                    title = "Trouble",
                    ft = "trouble",
                    size = { height = 0.30 },
                    pinned = false,
                },
                {
                    title = "QuickFix",
                    ft = "qf",
                    size = { height = 0.25 },
                    pinned = false,
                    filter = function(buf, win)
                        -- В edgebar — только обычный quickfix-list. Location-list
                        -- (per-window) пускай открывается как обычный split,
                        -- иначе его поведение становится непредсказуемым.
                        return vim.fn.getwininfo(win)[1].loclist == 0
                    end,
                },
                {
                    ft = "help",
                    size = { height = 0.40 },
                    filter = function(buf)
                        return vim.bo[buf].buftype == "help"
                    end,
                },
            },

            -- Дефолтные размеры по позиции — используются как fallback,
            -- если в view не задано size.
            options = {
                left = { size = 32 },
                right = { size = 40 },
                bottom = { size = 10 },
                top = { size = 10 },
            },

            -- Анимации ОТКЛЮЧЕНЫ. Они и есть визуальное "раздвигание"
            -- edgebar'ов при открытии DAP UI / Neo-Tree / поиска: edgy
            -- плавно интерполирует размеры окон от нуля до target. Это
            -- красиво на demo, но раздражает в рабочем потоке, особенно
            -- когда подряд срабатывают несколько transition'ов (DAP
            -- открывает 4 sidebar-окна + console = 5 anim'ов).
            -- С `equalalways=false` (см. config/options.lua) окна
            -- появляются мгновенно с правильным размером.
            animate = {
                enabled = false,
            },

            exit_when_last = false,
            close_when_all_hidden = true,

            -- Window-local опции для всех edgebar окон.
            --
            --   * winfixwidth=true для left/right edgebars — main editor не
            --     может "съесть" место у edgebar'а при resize.
            --   * winfixheight=true для bottom edgebar — при добавлении/
            --     удалении любого окна (не только в edgebar, а ВООБЩЕ)
            --     Neovim не пытается ресайзить высоту bottom-секций.
            --     Раньше было false → каждый F5/F10 в DAP сессии
            --     перерисовывал bottom-секции, потому что dap-ui
            --     создавал/закрывал scopes/watches окна.
            --   * number/relativenumber/foldcolumn — убираем, чтобы tool-
            --     окна (Neo-Tree, Aerial, DAP, ...) не наследовали
            --     глобальные настройки редактора и не показывали колонку
            --     с номерами строк / фолдов. Раньше было видно при старте
            --     проекта без сессии: у Neo-Tree лезли номера, пока не
            --     сфокусируешься в него (тогда сам плагин их сбрасывал).
            wo = {
                winbar = true,
                winfixwidth = true,
                winfixheight = true,
                winhighlight = "WinBar:EdgyWinBar,Normal:EdgyNormal",
                spell = false,
                signcolumn = "no",
                number = false,
                relativenumber = false,
                foldcolumn = "0",
                statuscolumn = "",
            },
        },
        init = function()
            -- edgy.nvim полагается на эти два опшна. Они уже выставлены
            -- в config/options.lua, но дублируем тут на случай, если
            -- порядок загрузки поменяется (edgy у нас на VeryLazy, опции
            -- грузятся до плагинов, так что обычно избыточно).
            vim.opt.laststatus = 3
            vim.opt.splitkeep = "screen"

            setup_edgy_disable_autocmds()
        end,
    },
}
