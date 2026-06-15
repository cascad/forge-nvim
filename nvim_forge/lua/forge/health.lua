-- :checkhealth forge — агрегированный статус локального сетапа.
--
-- Зачем отдельный health, если есть :checkhealth conform?
--   1) conform показывает только формат-тулзы; здесь же — ещё и LSP,
--      DAP, format-on-save status, autosave bypass для текущего ft.
--   2) Group-by по filetype в одном экране, без переключения буфера.
--   3) Подсказки "как поставить недостающее" прямо в выдаче — в твоём
--      сетапе тулзы ставятся СИСТЕМНО (go install / cargo install /
--      winget), а не через mason. Mason здесь только Python.
--
-- Стандартный API healthcheck:
--   :checkhealth forge → ищет lua/forge/health.lua → вызывает M.check().
--   vim.health.start/ok/warn/error/info — стандартные секции.
local M = {}

local function ok(msg)    vim.health.ok(msg)    end
local function warn(msg)  vim.health.warn(msg)  end
local function err(msg)   vim.health.error(msg) end
local function info(msg)  vim.health.info(msg)  end

local INSTALL_HINTS = {
    gofumpt   = "go install mvdan.cc/gofumpt@latest",
    golines   = "go install github.com/segmentio/golines@latest",
    goimports = "go install golang.org/x/tools/cmd/goimports@latest",
    stylua    = "cargo install stylua  |  winget install JohnnyMorganz.StyLua",
    rustfmt   = "rustup component add rustfmt",
    clippy    = "rustup component add clippy",
    prettier  = "npm i -g prettier",
    prettierd = "npm i -g @fsouza/prettierd",
    ruff      = ":Mason -> ruff (Python tools идут через Mason)",
    ruff_format = ":Mason -> ruff",
    ruff_organize_imports = ":Mason -> ruff",
    delve     = "go install github.com/go-delve/delve/cmd/dlv@latest",
    codelldb  = ":Mason -> codelldb",
    debugpy   = "pip install debugpy   (или :Mason -> debugpy)",
    rust_analyzer = "rustup component add rust-analyzer",
    gopls     = "go install golang.org/x/tools/gopls@latest",
    lua_ls    = ":Mason -> lua-language-server",
    pyright   = ":Mason -> pyright",
}

local function hint_for(name)
    return INSTALL_HINTS[name] or "see :Mason or upstream docs"
end

-- =============================================================
-- Section 1: Format-on-save status
-- =============================================================
local function check_format_on_save()
    vim.health.start("forge: format-on-save")

    if vim.g.disable_autoformat then
        warn("vim.g.disable_autoformat = true (global) — format-on-save выключен везде")
        info("Включить: :FormatEnable  или  :lua vim.g.disable_autoformat = false")
    else
        ok("global autoformat enabled (vim.g.disable_autoformat = false)")
    end

    local cur_buf = vim.api.nvim_get_current_buf()
    if vim.b[cur_buf].disable_autoformat then
        warn("vim.b.disable_autoformat = true для текущего буфера — здесь не форматируется")
        info("Включить: :FormatEnable  или  :lua vim.b.disable_autoformat = false")
    end

    if vim.g.user_auto_save_active then
        info("vim.g.user_auto_save_active = true (auto-save идёт прямо сейчас)")
    end

    -- Проверяем что у нас вообще зарегистрирован format_on_save в conform.
    local ok_conform, conform = pcall(require, "conform")
    if not ok_conform then
        err("conform.nvim не загружен — формат-он-save не может работать")
        return
    end

    -- Косвенная проверка: ищем автокоманду conform на BufWritePre.
    local autocmds = vim.api.nvim_get_autocmds({ event = "BufWritePre" })
    local has_conform_autocmd = false
    for _, a in ipairs(autocmds) do
        if (a.group_name or ""):match("[Cc]onform") or (a.desc or ""):match("[Cc]onform") then
            has_conform_autocmd = true
            break
        end
    end
    if has_conform_autocmd then
        ok("conform: format_on_save колбек установлен (BufWritePre autocmd активен)")
    else
        warn("conform: BufWritePre autocmd не найден — format-on-save может не сработать")
        info("Проверь что в format.lua не выключена секция format_on_save = function(...)")
    end

    -- Текущий ft + auto-save bypass.
    local ft = vim.bo[cur_buf].filetype
    local autosave_skip = { rust = true }
    if autosave_skip[ft] then
        info(("filetype=%s — БАЙПАС auto-save активен (rustfmt не дёргается каждые 500мс)"):format(ft))
        info("явный <C-s>/:w форматирует, autosave-запись — нет")
    elseif ft ~= "" then
        ok(("filetype=%s — формат на каждое сохранение (включая autosave)"):format(ft))
    else
        info("текущий буфер без filetype — формат не запускается")
    end
end

-- =============================================================
-- Section 2: Formatters per filetype (свёрнутая выдача :ConformInfo)
-- =============================================================
local function check_formatters()
    vim.health.start("forge: formatters per filetype")

    local ok_conform, conform = pcall(require, "conform")
    if not ok_conform then
        err("conform.nvim не загружен")
        return
    end

    -- Получаем formatters_by_ft из конфига conform. Это публичное поле.
    local by_ft = conform.formatters_by_ft or {}
    local fts = vim.tbl_keys(by_ft)
    table.sort(fts)

    if #fts == 0 then
        warn("formatters_by_ft пуст — формат не настроен")
        return
    end

    for _, ft in ipairs(fts) do
        local list = by_ft[ft]
        if type(list) == "table" then
            local names = {}
            for _, name in ipairs(list) do
                if type(name) == "string" then names[#names + 1] = name end
            end

            if #names == 0 then
                info(("[%s] нет форматтеров (LSP-fallback при наличии)"):format(ft))
            else
                local statuses = {}
                local any_available = false
                for _, name in ipairs(names) do
                    local fi = conform.get_formatter_info(name)
                    if fi.available then
                        any_available = true
                        statuses[#statuses + 1] = ("%s ✓"):format(name)
                    else
                        statuses[#statuses + 1] = ("%s ✗ (%s — install: %s)"):format(
                            name, fi.available_msg or "unavailable", hint_for(name))
                    end
                end

                local fallback = list.lsp_format == "fallback"
                local line = ("[%s] %s"):format(ft, table.concat(statuses, ", "))
                if fallback then line = line .. "  [+ LSP fallback]" end

                if any_available or fallback then
                    ok(line)
                else
                    warn(line .. "  → ни один форматтер не доступен и нет LSP-fallback'а")
                end
            end
        end
    end

    -- Глобальные ("*") форматтеры — trim_whitespace / trim_newlines.
    local star = by_ft["*"]
    if star then
        info("[*] " .. table.concat(vim.tbl_filter(function(v) return type(v) == "string" end, star), ", "))
    end
end

-- =============================================================
-- Section 3: External tools (binary in PATH)
-- =============================================================
local function check_external_tools()
    vim.health.start("forge: external tools (PATH lookup)")

    local tools = {
        -- core
        { name = "nvim",       optional = false },
        { name = "git",        optional = false },
        { name = "rg",         optional = false, desc = "ripgrep — telescope live_grep, grug-far" },
        { name = "fd",         optional = true,  desc = "telescope file finder (fallback на find)" },
        { name = "node",       optional = true,  desc = "нужен для prettier / некоторых LSP" },
        -- compilers
        { name = "go",         optional = true },
        { name = "cargo",      optional = true },
        { name = "rustc",      optional = true },
        { name = "python",     optional = true },
        { name = "py",         optional = true,  desc = "Windows python launcher" },
        -- formatters
        { name = "gofumpt",    optional = true,  desc = "Go strict formatter" },
        { name = "golines",    optional = true,  desc = "Go long-line wrapper" },
        { name = "rustfmt",    optional = true },
        { name = "stylua",     optional = true,  desc = "Lua formatter" },
        { name = "prettier",   optional = true },
        { name = "prettierd",  optional = true },
        -- debug adapters
        { name = "dlv",        optional = true,  desc = "Delve — Go DAP" },
        -- linters / extras
        { name = "tree-sitter", optional = true, desc = "treesitter CLI (для :TSInstall)" },
    }

    for _, t in ipairs(tools) do
        local found = vim.fn.executable(t.name) == 1
        local label = t.name
        if t.desc then label = label .. "  — " .. t.desc end
        if found then
            ok(label .. "  [" .. (vim.fn.exepath(t.name) or "") .. "]")
        elseif t.optional then
            local hint = INSTALL_HINTS[t.name] or "(optional)"
            info(("%s — not in PATH (install: %s)"):format(label, hint))
        else
            err(label .. " — not in PATH (REQUIRED)")
        end
    end
end

-- =============================================================
-- Section 4: LSP servers (active for current buffer)
-- =============================================================
local function check_lsp()
    vim.health.start("forge: LSP servers")

    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
        info("ни один LSP-клиент не attach'ен к текущему буферу")
        info("это норма для unsupported filetypes (txt, markdown без marksman, ...)")
    else
        for _, c in ipairs(clients) do
            local caps = c.server_capabilities or {}
            local fmt_provider = caps.documentFormattingProvider and "format" or nil
            local hover = caps.hoverProvider and "hover" or nil
            local def = caps.definitionProvider and "def" or nil
            local code_action = caps.codeActionProvider and "code-action" or nil
            local tags = vim.tbl_filter(function(v) return v end, { fmt_provider, hover, def, code_action })
            ok(("%s (id=%d) — %s"):format(c.name, c.id, table.concat(tags, ", ")))
        end
    end
end

-- =============================================================
-- Section 5: Quick actions hints
-- =============================================================
local function check_actions()
    vim.health.start("forge: how-to (быстрые действия)")
    info("Format buffer manually          : <S-A-f>  или  <leader>lf")
    info("Disable autoformat globally     : :FormatDisable  (вернуть :FormatEnable)")
    info("Disable autoformat for buffer   : :FormatDisable!")
    info("See full conform info           : :ConformInfo")
    info("Reload config                   : :Lazy reload conform.nvim")
    info("Install missing tools — см. секцию `external tools` выше")
end

function M.check()
    check_format_on_save()
    check_formatters()
    check_external_tools()
    check_lsp()
    check_actions()
end

return M
