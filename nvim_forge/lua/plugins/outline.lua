-- Aerial — outline/symbols sidebar. В forge используется как
-- компонент "outline" в left edgebar (через edgy).
--
-- Источник символов: LSP по умолчанию, treesitter fallback. Для
-- Rust/Go/Python LSP даёт лучший результат, чем TS-only.

return {
    {
        "stevearc/aerial.nvim",
        cmd = { "AerialOpen", "AerialToggle", "AerialClose", "AerialNavToggle" },
        keys = {
            { "<leader>lo", function() require('ide.controls').outline(true) end, desc = "Outline: toggle left" },
            { "<leader>so", function() require('ide.controls').outline(true) end, desc = "Outline: toggle left" },
            { "<leader>sn", "<cmd>AerialNavToggle<CR>", desc = "Outline: nav popup" },
        },
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        opts = {
            -- Backends priority: LSP > treesitter > markdown.
            -- Если LSP не подцепился (например, в внешнем файле без
            -- проекта), aerial скатывается на TS.
            backends = { "lsp", "treesitter", "markdown", "man" },
            attach_mode = "global",
            show_guides = true,
            autojump = false, -- spec: IDE-PANEL-3 переход только после подтверждения
            disable_max_lines = 3000,
            disable_max_size = 500 * 1024,
            on_attach = function(buf)
                vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = buf, desc = "Aerial: prev symbol" })
                vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = buf, desc = "Aerial: next symbol" })
            end,

            -- Слот фиксирован "left" чтобы edgy его захватывал в
            -- left edgebar. Можно ставить "right", но тогда наша
            -- spec в plugins/edgy.lua тоже должна это знать.
            layout = {
                default_direction = "left",
                placement = "edge",
                min_width = 20,
                max_width = { 40, 0.2 },
                resize_to_content = false,
                preserve_equality = false,
            },

            -- Не открываем aerial автоматически на BufEnter — мы
            -- управляем им через ide.show("outline") явно.
            open_automatic = false,

            -- Подсветка текущей позиции (показывает символ под
            -- курсором). Удобно для быстрой навигации.
            highlight_on_hover = true,
            highlight_on_jump = 300,

            -- Treesitter показывает функции/классы/методы — этого
            -- хватает для обзора в большинстве случаев.
            filter_kind = {
                "Class", "Constructor", "Enum", "Function",
                "Interface", "Module", "Method", "Struct", "Trait",
            },

            -- Иконки берём из nvim-web-devicons, общие для всего
            -- forge UI (catppuccin).
            icons = {},

            -- Штатные переходы. h/l и folds берём из defaults Aerial;
            -- q/Esc/? после FileType задаёт общий ide.controls.
            keymaps = {
                ["<CR>"] = "actions.jump",
                ["o"]    = "actions.jump",
                ["v"]    = "actions.jump_vsplit",
                ["s"]    = "actions.jump_split",
            },
        },
    },
}
