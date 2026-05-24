-- blink.cmp — modern, fast completion engine (Rust core).
-- Replaces nvim-cmp + sources + LuaSnip glue with one plugin.

return {
    {
        "saghen/blink.cmp",
        event = { "InsertEnter", "CmdlineEnter" },
        version = "*",      -- pre-built binary release; no rust toolchain needed
        dependencies = {
            "rafamadriz/friendly-snippets",
        },
        opts = {
            keymap = {
                preset = "default",
                ["<C-y>"]     = { "accept", "fallback" },
                ["<CR>"]      = { "accept", "fallback" },
                ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
                ["<Tab>"]     = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"]   = { "select_prev", "snippet_backward", "fallback" },
                ["<C-n>"]     = { "select_next", "fallback" },
                ["<C-p>"]     = { "select_prev", "fallback" },
                ["<C-d>"]     = { "scroll_documentation_down", "fallback" },
                ["<C-u>"]     = { "scroll_documentation_up",   "fallback" },
            },
            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = "mono",
            },
            completion = {
                accept = { auto_brackets = { enabled = true } },
                menu = {
                    border = "rounded",
                    draw = { treesitter = { "lsp" } },
                },
                documentation = {
                    auto_show       = true,
                    auto_show_delay_ms = 200,
                    window          = { border = "rounded" },
                },
                ghost_text = { enabled = true },
            },
            signature = { enabled = true, window = { border = "rounded" } },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
                providers = {
                    lsp     = { score_offset = 100 },
                    path    = { score_offset = 80 },
                    snippets = { score_offset = 60 },
                    buffer  = { score_offset = 20 },
                },
            },
            cmdline = {
                keymap = { preset = "inherit" },
                completion = { menu = { auto_show = true } },
            },
        },
        opts_extend = { "sources.default" },
    },
}
