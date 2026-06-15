-- nvim-cmp + LuaSnip. Биндинги повторяют поведение VS Code suggest popup
-- из keybindings.json: Ctrl+J / Ctrl+K — next/prev предложение.

return {
    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = (function()
            -- jsregexp под Windows не собирается — отключаем шаг сборки.
            -- LuaSnip работает без него, просто без regex-snippets.
            return nil
        end)(),
        dependencies = { "rafamadriz/friendly-snippets" },
        config = function()
            require("luasnip.loaders.from_vscode").lazy_load()
        end,
    },

    {
        "hrsh7th/nvim-cmp",
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "hrsh7th/cmp-nvim-lsp-signature-help",
            "saadparwaiz1/cmp_luasnip",
            "L3MON4D3/LuaSnip",
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")
            local ru_keys = require("config.ru_keys")

            local has_words_before = function()
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                return col ~= 0
                    and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
            end

            cmp.setup({
                snippet = {
                    expand = function(args) luasnip.lsp_expand(args.body) end,
                },
                completion = {
                    completeopt = "menu,menuone,noselect",
                },
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                mapping = cmp.mapping.preset.insert(ru_keys.extend_mappings({
                    -- VS Code suggest popup (keybindings.json):
                    ["<C-j>"]     = cmp.mapping.select_next_item(),
                    ["<C-k>"]     = cmp.mapping.select_prev_item(),
                    ["<C-Down>"]  = cmp.mapping.select_next_item(),
                    ["<C-Up>"]    = cmp.mapping.select_prev_item(),

                    -- Прокрутка doc-окна
                    ["<C-u>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-d>"] = cmp.mapping.scroll_docs(4),

                    -- Manual trigger
                    ["<C-Space>"] = cmp.mapping.complete(),

                    -- Cancel
                    ["<C-e>"] = cmp.mapping.abort(),

                    -- Confirm: Replace, как editor.suggest.insertMode:replace.
                    -- select=false — не подтверждать первый, если ничего явно
                    -- не выбрано. Иначе будет вешать рандомный вариант на Enter.
                    ["<CR>"] = cmp.mapping.confirm({
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = false,
                    }),

                    -- Tab — supertab-style: completion → snippet jump → indent
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        elseif has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),

                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                })),
                sources = cmp.config.sources({
                    { name = "nvim_lsp",                priority = 1000 },
                    { name = "nvim_lsp_signature_help", priority = 900 },
                    { name = "luasnip",                 priority = 800 },
                }, {
                    { name = "buffer",                  priority = 500, keyword_length = 3 },
                    { name = "path",                    priority = 400 },
                }),
                formatting = {
                    fields = { "abbr", "kind", "menu" },
                    format = function(entry, item)
                        item.menu = ({
                            nvim_lsp = "[LSP]",
                            luasnip  = "[Snip]",
                            buffer   = "[Buf]",
                            path     = "[Path]",
                        })[entry.source.name] or "[?]"
                        if #item.abbr > 50 then item.abbr = item.abbr:sub(1, 50) .. "…" end
                        return item
                    end,
                },
                experimental = {
                    ghost_text = false, -- ghost text часто конфликтует с copilot/codeium
                },
            })

            -- Cmdline `:` — fuzzy + path. Тут popup-дополнение полезно
            -- (команды/пути) и поиску не мешает.
            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = "path" },
                }, {
                    { name = "cmdline" },
                }),
                matching = { disallow_symbol_nonprefix_matching = false },
            })

            -- Поиск `/` и `?` — НАМЕРЕННО без cmp.
            --
            -- Цель — нативная «подсветка ВСЕХ совпадений прямо во время
            -- набора»: при incsearch+hlsearch (оба включены в options.lua)
            -- Neovim подсвечивает все вхождения по всему файлу, как только
            -- ты печатаешь паттерн (текущее — IncSearch/персиковый, прочие —
            -- Search/жёлтый). Но если на `/` повесить cmp.setup.cmdline,
            -- его popup перехватывает строку поиска и ломает живую
            -- перерисовку incsearch — совпадения по ходу набора перестают
            -- подсвечиваться (и popup ещё и закрывает их собой). Поэтому на
            -- поиске cmp не поднимаем — чистая нативная подсветка.
            --
            -- (Если когда-нибудь снова захочется word-дополнение в поиске —
            -- вернуть cmp.setup.cmdline({ "/", "?" }, { sources = {{ name =
            -- "buffer" }} }), но ценой живой подсветки.)
        end,
    },
}
