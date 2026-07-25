-- LSP-стек на Neovim 0.11+ (нативный vim.lsp.config / vim.lsp.enable).
-- require('lspconfig').<server>.setup{} больше НЕ используем — этот API
-- deprecated, удаляется в nvim-lspconfig v3.
--
-- Как это работает в 0.11+:
--   1. nvim-lspconfig поставляет lsp/<server>.lua с дефолтами (cmd,
--      filetypes, root_markers).
--   2. mason-lspconfig 2.x с automatic_enable=true вызывает
--      vim.lsp.enable() для каждого ensure_installed-сервера, который
--      успешно поставлен.
--   3. Наша задача — до enable() вызвать vim.lsp.config('<srv>', {...})
--      с settings/capabilities/init_options. vim.lsp.enable() мерджит
--      это поверх дефолтов из lsp/<server>.lua.
--
-- rust_analyzer настраиваем здесь же через vim.lsp.config('rust_analyzer', ...).
-- DAP для Rust живёт в plugins\dap.lua (codelldb adapter напрямую, без
-- rustaceanvim — у того были проблемы с experimental endpoints,
-- блокировавшими ra на 20 сек).

return {
    -- =====================================================================
    -- Mason
    -- =====================================================================
    {
        "williamboman/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonLog" },
        opts = {
            ui = {
                border = "rounded",
                icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
            },
        },
    },

    -- =====================================================================
    -- mason-lspconfig 2.x — мост Mason ⇄ vim.lsp.config/enable.
    -- automatic_enable=true (default в 2.x) делает vim.lsp.enable()
    -- автоматически для всех ensure_installed-серверов.
    -- =====================================================================
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig",
        },
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            ensure_installed = {
                "gopls",
                "pyright",
                "ruff",
                "lua_ls",
                "rust_analyzer",
            },
            -- automatic_enable=true (default 2.x) поднимет все
            -- ensure_installed-сервера через vim.lsp.enable().
            -- Settings для rust_analyzer задаём в vim.lsp.config()
            -- ниже в этом же файле.
        },
    },

    -- =====================================================================
    -- Декларативный список инструментов (LSP / DAP / форматтеры / линтеры).
    -- Запускается на старте, прогресс показывает fidget.
    -- =====================================================================
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = { "williamboman/mason.nvim" },
        event = "VeryLazy",
        opts = {
            ensure_installed = {
                -- LSP
                "gopls",
                "pyright",
                "ruff",
                "lua-language-server",
                "rust-analyzer",
                -- DAP
                -- Delve follows Go runtime/compiler internals closely. Keep it
                -- current so project toolchain upgrades do not break debugging.
                "delve",
                "debugpy",
                -- codelldb НЕ ставим: пользователь держит его в PATH
                -- (%LocalAppData%\codelldb\adapter\codelldb.exe).
                --
                -- Форматтеры здесь НЕ держим (единый механизм — системный):
                --   stylua   : cargo install stylua  (см. format.lua)
                --   prettier : npm i -g prettier
                --   gofumpt/golines : go install ...  (уже в PATH)
                -- Два конкурирующих механизма (mason + system) раньше давали
                -- «на костылях»: stylua числился тут, но Mason его не ставил,
                -- а system-установки не было → conform молча падал на lua/json.
                -- Линтеры (если ruff/gopls/pyright чего-то не покрывают)
                "golangci-lint",
            },
            auto_update = false,
            run_on_start = true,
            start_delay = 3000,
        },
    },

    -- =====================================================================
    -- neodev — добавляет API Neovim в lua_ls workspace, чтобы он не
    -- ругался на глобал `vim` при правке самого конфига.
    -- =====================================================================
    {
        "folke/neodev.nvim",
        ft = "lua",
        opts = {},
    },

    -- =====================================================================
    -- nvim-lspconfig: подгружаем ради lsp/<server>.lua-дефолтов
    -- (filetypes, root_markers, cmd). require('lspconfig') не вызываем.
    -- В этом же файле — diagnostics UI, общий on_attach (LspAttach
    -- autocmd), capabilities-пресет и vim.lsp.config() для серверов.
    -- =====================================================================
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            local diagnostics = require("config.diagnostics")
            local rust_external = require("config.rust_external")

            -- ----------- Diagnostics UI -----------
            -- ГЛАВНОЕ ПРАВИЛО: текст диагностики НИКОГДА не появляется сам.
            --
            -- Раньше было virtual_lines={current_line=true} — сообщение
            -- разворачивалось под строкой, едва курсор на неё попадал, и
            -- РАЗДВИГАЛО код вниз. При наборе кода (где половина строк
            -- временно «ошибочные») страница дёргалась на каждое движение
            -- курсора. Теперь inline-раскрытия нет вообще:
            --
            --   * пассивно  — только знак в gutter (E/W/I/H) + подчёркивание
            --     под проблемным местом. Ничего не двигается, ничего не мигает;
            --   * по запросу — `gl` (или родной neovim'ский <C-W>d) открывает
            --     ОВЕРЛЕЙ (float) с полным текстом у курсора. Это плавающее
            --     окно поверх кода: строки не раздвигаются, окно само гаснет
            --     при первом же движении курсора.
            --
            -- virtual_text не включаем и здесь: длинные сообщения уезжают за
            -- правый край и не переносятся. Полный текст — во float.
            -- Раскрытие inline всё ещё доступно, но только руками: <leader>td
            -- (DiagToggle) переключает off → current_line → all → off.
            local function apply_diagnostic_config()
                local sev = vim.diagnostic.severity
                -- Без nerd-шрифта (vim.g.have_nerd_font=false) значки-глифы
                -- рендерятся пустотой/тофу — значок в gutter не виден. Даём
                -- ASCII-фоллбэк (E/W/I/H), он красится в цвет severity через
                -- DiagnosticSign* и виден в ЛЮБОМ шрифте. С nerd-шрифтом
                -- вернутся иконки.
                local sign_text = vim.g.have_nerd_font
                    and {
                        [sev.ERROR] = " ", [sev.WARN] = " ",
                        [sev.INFO]  = " ", [sev.HINT] = " ",
                    }
                    or {
                        [sev.ERROR] = "E", [sev.WARN] = "W",
                        [sev.INFO]  = "I", [sev.HINT] = "H",
                    }
                vim.diagnostic.config({
                    virtual_text = false,
                    virtual_lines = false,   -- см. блок выше: только по хоткею
                    signs = { text = sign_text },
                    underline = true,
                    update_in_insert = false,
                    severity_sort = true,
                    -- Оверлей по `gl` / <C-W>d. header="" — без строчки
                    -- «Diagnostics:», она только съедает высоту. max_width
                    -- + wrap: длинное сообщение переносится внутри окна,
                    -- а не уезжает за край экрана.
                    float = {
                        border = "rounded",
                        source = "if_many",
                        header = "",
                        max_width = 90,
                        wrap = true,
                    },
                })
            end

            -- ВАЖНО: оборачиваем в pcall. В новых Neovim vim.diagnostic.config()
            -- при применении делает re-show диагностики по уже открытым буферам
            -- (diagnostic.lua → show → once_buf_loaded). Если на момент вызова
            -- среди буферов есть невалидный/wiped (на старте бывает временный
            -- scratch/alpha buffer, напр. id=2), внутренний show падает с
            -- "Invalid buffer id". Без pcall эта ошибка обрывала ВЕСЬ config()
            -- lspconfig — и всё, что ниже (LspAttach, настройка LSP-серверов,
            -- capabilities), не выполнялось → LSP вообще не поднимался.
            -- Конфиг при этом успевает примениться (show идёт ПОСЛЕ записи
            -- опций), поэтому swallowнутая ошибка не теряет настройки.
            if not pcall(apply_diagnostic_config) then
                vim.api.nvim_create_autocmd("VimEnter", {
                    once = true,
                    callback = function()
                        vim.schedule(function() pcall(apply_diagnostic_config) end)
                    end,
                })
            end
            diagnostics.setup_refresh()

            -- Раскрыть диагностику под курсором ОВЕРЛЕЕМ (float поверх кода,
            -- строки не раздвигает, гаснет при движении курсора) + подсветить
            -- ТОЧНОЕ место, о котором это окно говорит (см. config/diagnostics).
            --   gl     — основной хоткей: два символа, без leader и модификаторов;
            --   <C-W>d — родной дефолт Neovim 0.10+ (голый float, без подсветки
            --            места; ничего не переопределяем, работает сам по себе).
            -- Не буферный маппинг (не в LspAttach): диагностика бывает не только
            -- от LSP (линтеры, neotest), и `gl` должен работать всегда.
            diagnostics.setup_focus_highlights()
            vim.keymap.set("n", "gl", diagnostics.show_under_cursor,
                { desc = "Diag: показать под курсором (окно + подсветка места)" })

            -- Ручное inline-раскрытие, если всё-таки понадобилось «как раньше»:
            -- off (по умолчанию) → current_line → all → off.
            local diag_state = "off"
            vim.api.nvim_create_user_command("DiagToggle", function()
                if diag_state == "off" then
                    -- → inline под строкой с курсором (старое поведение)
                    pcall(vim.diagnostic.config, {
                        virtual_lines = diagnostics.virtual_lines_current(),
                        virtual_text = false,
                    })
                    diag_state = "current_line"
                    vim.notify("Diagnostics: virtual_lines (current line)", vim.log.levels.INFO)
                elseif diag_state == "current_line" then
                    -- → inline на ВСЕХ строках с диагностикой
                    pcall(vim.diagnostic.config, {
                        virtual_lines = diagnostics.virtual_lines_all(),
                        virtual_text = false,
                    })
                    diag_state = "all"
                    vim.notify("Diagnostics: virtual_lines (all)", vim.log.levels.INFO)
                else
                    -- → назад к «ничего само не раскрывается»
                    pcall(vim.diagnostic.config, { virtual_lines = false, virtual_text = false })
                    diag_state = "off"
                    vim.notify("Diagnostics: signs only (gl — показать под курсором)",
                        vim.log.levels.INFO)
                end
            end, { desc = "Cycle diagnostics display: off → current_line → all" })

            vim.keymap.set("n", "<leader>td", "<cmd>DiagToggle<CR>",
                { desc = "Toggle diagnostics display mode" })

            -- ----------- LspAttach: общие маппинги для всех серверов -----------
            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
                callback = function(ev)
                    local buf = ev.buf
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    if not client then return end

                    local function nm(lhs, rhs, desc)
                        vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc, silent = true })
                    end

                    -- ruff: hover отключаем, hover делает pyright (он лучше типизирован)
                    if client.name == "ruff" then
                        client.server_capabilities.hoverProvider = false
                    end

                    -- ★ КРИТИЧНО: имя клиента может быть как
                    -- "rust_analyzer" (из vim.lsp.config()), так и
                    -- "rust-analyzer" (из serverInfo.name самого ra).
                    -- В Neovim 0.11+ это зависит от того, переписал ли
                    -- сервер своё имя в initialize-ответе. Поэтому
                    -- проверяем оба варианта.
                    local is_ra = (client.name == "rust_analyzer")
                        or (client.name == "rust-analyzer")

                    -- rust-analyzer: для буферов вне нашего проекта
                    -- (stdlib, ~/.cargo/registry, ~/.rustup/, vendored
                    -- deps) НЕ подписываемся на тяжёлые pull-запросы —
                    -- иначе после `gd` в std/fs.rs ra делает full
                    -- inference на 3300 строк сериализованно с
                    -- ответом на наш следующий `gd` → блокировка.
                    --
                    -- LSP-клиент ОСТАЁТСЯ attach: `gd`/`K`/hover везде
                    -- работают. Просто не дёргаем:
                    --   - pull diagnostics
                    --   - inlay hints
                    --   - aerial / barbecue / illuminate (через флаг)
                    if is_ra then
                        if rust_external.mark(buf) then
                            pcall(vim.diagnostic.enable, false, { bufnr = buf })
                        end
                    end

                    -- IDE-style F-клавиши и Alt+J (как в keybindings.json)
                    nm("<F12>",   vim.lsp.buf.definition,                "LSP: go to definition")
                    nm("<S-F12>", vim.lsp.buf.references,                "LSP: references")
                    nm("<C-F12>", vim.lsp.buf.implementation,            "LSP: implementation")
                    nm("<F2>",    vim.lsp.buf.rename,                    "LSP: rename")
                    nm("<F3>",    function() vim.diagnostic.jump({ count = 1, float = true }) end,  "Diag: next")
                    nm("<S-F3>",  function() vim.diagnostic.jump({ count = -1, float = true }) end, "Diag: prev")
                    nm("<A-j>",   vim.lsp.buf.definition,                "LSP: go to definition")

                    -- gd / gD / gr / gi / gy + K — стандартный Vim-набор
                    nm("gd", vim.lsp.buf.definition,      "LSP: definition")
                    nm("gD", vim.lsp.buf.declaration,     "LSP: declaration")
                    nm("gr", vim.lsp.buf.references,      "LSP: references")
                    nm("gi", vim.lsp.buf.implementation,  "LSP: implementation")
                    nm("gy", vim.lsp.buf.type_definition, "LSP: type definition")
                    nm("K",  vim.lsp.buf.hover,           "LSP: hover")

                    -- Code action / signature
                    nm("<leader>la", vim.lsp.buf.code_action,           "LSP: code action")
                    -- Organize imports as an explicit, non-magical action.
                    -- В gopls это source-level code action: добавляет НЕДОСТАЮЩИЕ
                    -- импорты (предлагая выбор при коллизии — что нам и нужно)
                    -- и убирает неиспользуемые, сортирует по группам. В ruff —
                    -- сортировка/удаление мёртвых import-ов в Python.
                    nm("<leader>lO", function()
                        vim.lsp.buf.code_action({
                            context = { only = { "source.organizeImports" } },
                            apply = true,
                        })
                    end, "LSP: organize imports")
                    nm("<leader>ln", vim.lsp.buf.rename,                "LSP: rename")
                    nm("<leader>lh", vim.lsp.buf.hover,                 "LSP: hover")
                    nm("<leader>lk", vim.lsp.buf.signature_help,        "LSP: signature help")
                    nm("<leader>ld", vim.lsp.buf.definition,            "LSP: definition")
                    nm("<leader>lr", vim.lsp.buf.references,            "LSP: references")
                    nm("<leader>li", vim.lsp.buf.implementation,        "LSP: implementation")
                    nm("<leader>lt", vim.lsp.buf.type_definition,       "LSP: type def")
                    nm("<leader>lD", vim.lsp.buf.declaration,           "LSP: declaration")

                    -- Inlay hints. Включаем сразу везде, КРОМЕ внешних
                    -- rust-буферов (stdlib/registry) — там это
                    -- блокирует ra. Toggle на текущий буфер: <leader>th.
                    if client:supports_method("textDocument/inlayHint")
                        and not vim.b[buf].rust_external then
                        vim.lsp.inlay_hint.enable(true, { bufnr = buf })
                    end

                    -- Document highlight отключён здесь: vim-illuminate
                    -- уже делает это через свой LSP-провайдер. Дублирующий
                    -- запрос на каждый CursorHold (200мс) создаёт лишнюю
                    -- нагрузку на rust-analyzer и блокирует gd.
                    -- Если illuminate когда-нибудь уберём — раскомментировать:
                    --
                    -- if client:supports_method("textDocument/documentHighlight") then
                    --     local hl_aug = vim.api.nvim_create_augroup("UserLspDocHL_" .. buf, { clear = true })
                    --     vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                    --         group = hl_aug, buffer = buf, callback = vim.lsp.buf.document_highlight,
                    --     })
                    --     vim.api.nvim_create_autocmd("CursorMoved", {
                    --         group = hl_aug, buffer = buf, callback = vim.lsp.buf.clear_references,
                    --     })
                    -- end

                    -- Для rust-analyzer выключаем тяжёлые серверные
                    -- capabilities, которые при каждом CursorMoved/Hold
                    -- забивают очередь сериализованных запросов и блокируют
                    -- следующий `gd` (видно в LSP-логе: десятки
                    -- documentHighlight / semanticTokens / runnables за
                    -- одну секунду).
                    --
                    --   - semanticTokensProvider: подсветка через TS — ok
                    --   - documentHighlightProvider: illuminate всё равно
                    --     fallback'ается на regex-провайдер
                    if is_ra then
                        client.server_capabilities.semanticTokensProvider = nil
                        client.server_capabilities.documentHighlightProvider = nil
                    end
                end,
            })

            -- ----------- Capabilities (общие для всех серверов) -----------
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
            if ok_cmp then
                capabilities = cmp_lsp.default_capabilities(capabilities)
            end
            -- Глобальный дефолт для всех LSP-конфигов.
            --
            -- on_exit: если сервер УПАЛ (диагностика/линтер «тихо сломались» —
            -- ровно жалоба юзера), громко сообщаем и подсказываем рестарт.
            -- Чтобы не спамить на ШТАТНЫХ остановках, молчим когда:
            --   * code == 0 (чистый стоп);
            --   * выходим из nvim (v:exiting не null);
            --   * мы сами перезапускаем (:LspRestart / :GoToolchain ставят
            --     vim.g.forge_lsp_restarting).
            vim.lsp.config("*", {
                capabilities = capabilities,
                on_exit = function(code, signal, _client_id)
                    -- чистый стоп = code 0 И без сигнала (на Unix kill может
                    -- дать code 0 + ненулевой signal — это тоже падение).
                    if code == 0 and (signal == nil or signal == 0) then return end
                    if vim.v.exiting ~= vim.NIL then return end
                    if vim.g.forge_lsp_restarting then return end
                    vim.schedule(function()
                        vim.notify(
                            ("LSP-сервер упал (exit %d). Диагностика/линтер молчат —\n"
                                .. "перезапусти: <leader>lR (буфер) или :LspRestart. Лог: :LspLog"):format(code),
                            vim.log.levels.WARN, { title = "LSP" }
                        )
                    end)
                end,
            })

            -- ----------- gopls -----------
            -- settings.json: useLanguageServer:true, formatTool:goimports,
            -- organizeImports on save, gofumpt-style.
            --
            -- completeUnimported = true. Набираешь `strings.` или
            -- `strings.Filter` — gopls ищет символ по НЕИМПОРТИРОВАННЫМ
            -- пакетам и при accept'е сам добавляет import. Это именно тот
            -- VS Code-style autocomplete-импорт, который и нужен.
            -- На коллизиях (rand → math/rand vs crypto/rand, log → стандартный
            -- vs zap) gopls показывает ВСЕ кандидаты ОТДЕЛЬНЫМИ пунктами с
            -- полным путём пакета в `[LSP]`-detail — выбираешь нужный руками,
            -- эвристика ничего не угадывает молча. Если же хочется добавить
            -- импорт к уже написанному имени — остаётся <leader>la / <leader>lO.
            -- importShortcut="Both" — в hover/jump доступны и определение, и
            -- ссылка на импортируемый пакет.
            vim.lsp.config("gopls", {
                settings = {
                    gopls = {
                        gofumpt = true,
                        usePlaceholders = true,
                        completeUnimported = true,
                        importShortcut = "Both",
                        staticcheck = true,
                        analyses = {
                            unusedparams = true,
                            unusedwrite = true,
                            useany = true,
                            nilness = true,
                            shadow = true,
                        },
                        hints = {
                            assignVariableTypes = true,
                            compositeLiteralFields = true,
                            compositeLiteralTypes = true,
                            constantValues = true,
                            functionTypeParameters = true,
                            parameterNames = true,
                            rangeVariableTypes = true,
                        },
                        codelenses = {
                            generate = true,
                            gc_details = false,
                            test = true,
                            tidy = true,
                            upgrade_dependency = true,
                            vendor = true,
                        },
                    },
                },
            })

            -- ----------- pyright -----------
            vim.lsp.config("pyright", {
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode = "basic",
                            autoSearchPaths = true,
                            useLibraryCodeForTypes = true,
                            diagnosticMode = "openFilesOnly",
                        },
                    },
                },
            })

            -- ----------- ruff (LSP + линтер + форматтер) -----------
            vim.lsp.config("ruff", {
                init_options = {
                    settings = {
                        organizeImports = true,
                    },
                },
                -- on_attach: hoverProvider отключается в общем LspAttach
                -- выше через client.name == "ruff".
            })

            -- ----------- lua_ls -----------
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        diagnostics = { globals = { "vim" } },
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true),
                            checkThirdParty = false,
                        },
                        telemetry = { enable = false },
                        format = { enable = false }, -- форматирует stylua через conform
                    },
                },
            })

            -- ----------- rust-analyzer -----------
            --
            -- Чистый nvim-lspconfig, БЕЗ rustaceanvim. Эта связка
            -- работает у миллионов людей, у пользователя точно так же
            -- работало в его старом конфиге без проблем «20 сек hang
            -- после первого gd».
            --
            -- Settings — рекомендованные LazyVim/rust extras:
            --   https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/rust.lua
            --
            -- Capabilities (workspace.didChangeWatchedFiles.dynamicRegistration
            -- и пр.) уже выставлены через vim.lsp.config("*", { capabilities }) выше.
            vim.lsp.config("rust_analyzer", {
                on_init = function(client)
                    -- Отключаем до первого attach, чтобы Neovim не успел
                    -- запустить semantic tokens/documentHighlight в stdlib.
                    client.server_capabilities.semanticTokensProvider = nil
                    client.server_capabilities.documentHighlightProvider = nil
                end,
                settings = {
                    ["rust-analyzer"] = {
                        cargo = {
                            allFeatures = true,
                            loadOutDirsFromCheck = true,
                            buildScripts = { enable = true },
                        },
                        procMacro = { enable = true },
                        diagnostics = {
                            enable = true,
                            -- Экспериментальные нативные диагностики ra: ловят
                            -- БОЛЬШЕ ошибок "на лету" (необъявленные имена,
                            -- обращение к несуществующим полям/методам, mismatched
                            -- args и т.п.) ДО запуска cargo check на save. Иногда
                            -- дают редкие ложные срабатывания на сложных макросах —
                            -- осознанный размен ради более полной подсветки.
                            experimental = { enable = true },
                            disabled = { "unlinked-file" },
                        },
                        -- clippy на каждый save, включая фоновый Rust autosave
                        -- через 500мс (см. editor.lua). Это НЕ фризит набор:
                        -- ra гоняет cargo clippy в ОТДЕЛЬНОМ процессе и шлёт
                        -- диагностики асинхронно — главный цикл nvim его не
                        -- ждёт («линтер в фоне»). conform тоже не блокирует:
                        -- format_after_save асинхронный и autosave не форматит.
                        checkOnSave = true,
                        check = {
                            command = "clippy",
                            extraArgs = { "--no-deps" },
                        },
                        files = {
                            -- "client" решает hang на Roots Scanned под Windows:
                            -- rust-lang/rust-analyzer#12613
                            watcher = "client",
                            excludeDirs = {
                                ".direnv", ".git", ".jj", ".github",
                                "node_modules", "target", "venv", ".venv",
                            },
                        },
                        inlayHints = {
                            bindingModeHints = { enable = false },
                            chainingHints = { enable = true },
                            closingBraceHints = { enable = true, minLines = 25 },
                            closureReturnTypeHints = { enable = "never" },
                            lifetimeElisionHints = { enable = "never" },
                            parameterHints = { enable = true },
                            reborrowHints = { enable = "never" },
                            renderColons = true,
                            typeHints = {
                                enable = true,
                                hideClosureInitialization = false,
                                hideNamedConstructor = false,
                            },
                        },
                    },
                },
            })

            -- :RustSrcInstall — установить rust-src component
            -- (нужен для gd внутрь stdlib).
            vim.api.nvim_create_user_command("RustSrcInstall", function()
                vim.notify("Installing rust-src via rustup...",
                    vim.log.levels.INFO, { title = "rust-analyzer" })
                vim.system({ "rustup", "component", "add", "rust-src" },
                    { text = true }, function(out)
                        vim.schedule(function()
                            if out.code == 0 then
                                vim.notify("rust-src installed. Restart rust-analyzer with :LspRestart rust_analyzer",
                                    vim.log.levels.INFO, { title = "rust-analyzer" })
                            else
                                vim.notify("Failed: " .. (out.stderr or out.stdout or ""),
                                    vim.log.levels.ERROR, { title = "rust-analyzer" })
                            end
                        end)
                    end)
            end, { desc = "Install rust-src component (for stdlib navigation)" })

            -- ----------- User-команды для отсутствующих в новом API -----------
            -- В nvim-lspconfig 0.11+ удалили :LspLog/:LspInfo/:LspRestart
            -- вместе со старым require('lspconfig') фреймворком. Часть из
            -- них Neovim core регистрирует, часть — нет. Делаем свои.

            vim.api.nvim_create_user_command("LspLog", function()
                vim.cmd.tabnew(vim.lsp.get_log_path())
            end, { desc = "Open LSP log file in new tab" })

            -- Перезапуск набора LSP-клиентов БЕЗ :edit. :edit падает E37 на
            -- изменённом буфере (и тогда сервер не поднимается — ровно когда
            -- правишь код и линтер «отвалился»), к тому же ре-attach'ит только
            -- текущий буфер. Здесь: форс-стоп (сервер мог зависнуть — ровно
            -- случай «диагностика молчит»), затем ре-attach через FileType на
            -- ВСЕХ задетых буферах (vim.lsp.enable вешает старт именно на
            -- FileType). НАШ рестарт глушит crash-нотификацию из on_exit.
            local function forge_restart_clients(clients, on_done)
                local names, bufs, seen = {}, {}, {}
                for _, c in ipairs(clients) do
                    names[#names + 1] = c.name
                    for b in pairs(c.attached_buffers or {}) do
                        if not seen[b] then seen[b] = true; bufs[#bufs + 1] = b end
                    end
                end
                vim.g.forge_lsp_restarting = true
                for _, c in ipairs(clients) do pcall(function() c:stop(true) end) end
                vim.defer_fn(function()
                    vim.g.forge_lsp_restarting = nil
                    for _, b in ipairs(bufs) do
                        if vim.api.nvim_buf_is_valid(b) then
                            pcall(vim.api.nvim_exec_autocmds, "FileType", { buffer = b })
                        end
                    end
                    if on_done then on_done(names) end
                end, 500)
            end

            vim.api.nvim_create_user_command("LspRestart", function(args)
                local name_filter = args.fargs[1]
                local clients = vim.lsp.get_clients(name_filter and { name = name_filter } or nil)
                if #clients == 0 then
                    vim.notify("No LSP clients to restart"
                        .. (name_filter and (" matching '" .. name_filter .. "'") or ""),
                        vim.log.levels.WARN, { title = "LSP" })
                    return
                end
                forge_restart_clients(clients, function(names)
                    vim.notify("LSP restarted: " .. table.concat(names, ", "),
                        vim.log.levels.INFO, { title = "LSP" })
                end)
            end, {
                nargs = "?",
                complete = function()
                    return vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients())
                end,
                desc = "Restart LSP client(s) (optional: server name)",
            })

            vim.api.nvim_create_user_command("LspInfo", function()
                vim.cmd("checkhealth vim.lsp")
            end, { desc = "LSP info (alias for :checkhealth vim.lsp)" })

            vim.api.nvim_create_user_command("LspDebug", function(args)
                local level = (args.fargs[1] or "debug"):lower()
                vim.lsp.set_log_level(level)
                vim.notify("LSP log level: " .. level
                    .. "\nLog file: " .. vim.lsp.get_log_path()
                    .. "\nUse :LspLog to view, :LspDebug warn to revert.",
                    vim.log.levels.INFO, { title = "LSP" })
            end, {
                nargs = "?",
                complete = function() return { "trace", "debug", "info", "warn", "error", "off" } end,
                desc = "Set LSP log level (default: debug)",
            })

            vim.api.nvim_create_user_command("LspWho", function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then
                    vim.notify("No LSP clients attached to current buffer\n"
                        .. "Filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
                    return
                end
                local lines = { "LSP clients on this buffer:" }
                for _, c in ipairs(clients) do
                    local cmd = type(c.config.cmd) == "table"
                        and table.concat(c.config.cmd, " ") or tostring(c.config.cmd)
                    table.insert(lines, string.format("  • %s  (id=%d)\n      cmd: %s\n      root: %s",
                        c.name, c.id, cmd, c.config.root_dir or "<none>"))
                end
                vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LSP" })
            end, { desc = "Show LSP clients attached to current buffer" })

            -- ----------- Перезапуск LSP/линтера на текущем буфере -----------
            -- «Линтер тихо сломался» (gopls перестал слать диагностику) →
            -- перезапускаем сервер(ы) ЭТОГО буфера одной клавишей, без аргумента.
            vim.keymap.set("n", "<leader>lR", function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then
                    vim.notify("Нет LSP на этом буфере", vim.log.levels.WARN, { title = "LSP" })
                    return
                end
                forge_restart_clients(clients, function(names)
                    vim.notify("Перезапущен LSP/линтер: " .. table.concat(names, ", "),
                        vim.log.levels.INFO, { title = "LSP" })
                end)
            end, { desc = "LSP: restart on this buffer (refresh diagnostics/linter)" })

            -- ----------- Go: версия и переключение toolchain -----------
            -- :GoVersion — показать активную версию Go и GOTOOLCHAIN.
            -- :GoToolchain [go1.25.0|auto|local] — переключить toolchain и
            -- перезапустить gopls (как смена версии Go в VS Code). Без
            -- аргумента — picker. Логика в forge/go.lua, статуслайн — ui.lua.
            vim.api.nvim_create_user_command("GoVersion", function()
                local go = require("forge.go")
                go.refresh()
                vim.defer_fn(function()
                    local v = go.version()
                    vim.notify(
                        "Go: " .. (v == "" and "<неизвестно>" or v)
                        .. "\nGOTOOLCHAIN: " .. go.current_toolchain()
                        .. "\nПереключить: :GoToolchain [go1.25.0 | auto | local]",
                        vim.log.levels.INFO, { title = "Go" }
                    )
                end, 300)
            end, { desc = "Show active Go version and GOTOOLCHAIN" })

            vim.api.nvim_create_user_command("GoToolchain", function(a)
                local go = require("forge.go")
                if a.args and a.args ~= "" then
                    go.set_toolchain(a.args)
                    return
                end
                local choices = { "auto", "local", "go1.25.0", "go1.24.0", "go1.23.3" }
                vim.ui.select(choices, {
                    prompt = "GOTOOLCHAIN (сейчас: " .. go.current_toolchain() .. "):",
                }, function(c) if c then go.set_toolchain(c) end end)
            end, {
                nargs = "?",
                complete = function() return { "auto", "local", "go1.25.0", "go1.24.0", "go1.23.3" } end,
                desc = "Switch Go toolchain (GOTOOLCHAIN) and restart gopls",
            })
        end,
    },
}
