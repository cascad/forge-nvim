-- nvim-dap-ui — VS Code-style DAP UI. Заменил igorlfs/nvim-dap-view,
-- потому что dap-view физически не умеет разносить scopes/watches/stacks/
-- breakpoints на отдельные окна — это одно окно с табами в винбаре.
--
-- Архитектура (см. docs/PANELS_PLAN.md):
--   * Layout 1 (left, sidebar): scopes + watches + stacks + breakpoints.
--     edgy.nvim ловит каждое окно через ft = dapui_<id> и кладёт в
--     left edgebar как 4 секции.
--   * Layout 2 (bottom, console): PTY-вывод программы (codelldb /
--     debugpy с console=integratedTerminal).
--   * Layout 3 (bottom, repl): интерактивный DAP REPL (Go, Python с
--     internalConsole; вообще любой адаптер, который шлёт output как
--     event).
--
-- Layout 2 и 3 — взаимоисключающие компоненты в bottom slot ide
-- framework'а: одновременно отображаем только один (см. plugins/ide/
-- init.lua → dap.console / dap.repl).

return {
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        cmd = {
            "DapUI",
            "DapUIToggle",
            "DapUIClose",
            "DapUIOpen",
            "DapUIFloatElement",
        },
        opts = function()
            local opts = {
                -- 3 раздельных layout'а — каждый dapui.open(N) активирует
                -- свой набор окон. ide.state управляет: какой именно
                -- bottom-layout сейчас.
                layouts = {
                    {
                        -- LEFT sidebar: 4 секции в одном edgebar.
                        position = "left",
                        size = 40,
                        elements = {
                            { id = "scopes",      size = 0.30 },
                            { id = "watches",     size = 0.20 },
                            { id = "stacks",      size = 0.25 },
                            { id = "breakpoints", size = 0.25 },
                        },
                    },
                    {
                        -- BOTTOM console: один полноразмерный output
                        -- (PTY debuggee для Rust/codelldb).
                        position = "bottom",
                        size = 0.30,
                        elements = {
                            { id = "console", size = 1.0 },
                        },
                    },
                    {
                        -- BOTTOM repl: интерактивный DAP REPL.
                        -- Используется для Go/Python+internalConsole.
                        position = "bottom",
                        size = 0.30,
                        elements = {
                            { id = "repl", size = 1.0 },
                        },
                    },
                },

                -- Авто-open отключён — открытием/закрытием рулит ide
                -- через свой FSM (см. dap.listeners в plugins/dap.lua).
                -- Иначе dap-ui автоматически откроет первый layout при
                -- старте сессии и подерётся с нашим apply_layout("debug").

                controls = {
                    enabled = false,  -- наши F-клавиши + <leader>d* — главные
                },

                -- Без иконок (можно включить, если есть nerd font).
                icons = vim.g.have_nerd_font and {
                    expanded = "",
                    collapsed = "",
                    current_frame = "",
                } or {
                    expanded = "v",
                    collapsed = ">",
                    current_frame = ">",
                },

                mappings = {
                    expand = { "<CR>", "<2-LeftMouse>" },
                    open = "o",
                    remove = "d",
                    edit = "e",
                    repl = "r",
                    toggle = "t",
                },

                floating = {
                    max_height = 0.9,
                    max_width  = 0.5,
                    border = "rounded",
                    mappings = { close = { "q", "<Esc>" } },
                },

                render = {
                    max_type_length = nil,
                    max_value_lines = 100,
                    indent = 1,
                },
            }
            return opts
        end,
        config = function(_, opts)
            require("dapui").setup(opts)
        end,
    },
}
