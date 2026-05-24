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
            { "<leader>lo", "<cmd>AerialToggle left<CR>", desc = "Outline (Aerial)" },
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

            -- ВАЖНО: aerial по дефолту привязывает свой
            -- `nav-toggle` к <CR>. У нас <CR> используется для
            -- "go to definition"-style действий в нескольких
            -- местах, поэтому только базовые: open / split / vsplit.
            keymaps = {
                ["<CR>"] = "actions.jump",
                ["o"]    = "actions.jump",
                ["v"]    = "actions.jump_vsplit",
                ["s"]    = "actions.jump_split",
                ["q"]    = "actions.close",
                ["?"]    = "actions.show_help",
            },
        },
    },
}
