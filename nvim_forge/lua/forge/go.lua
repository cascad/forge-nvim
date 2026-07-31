-- forge/go.lua — показ и переключение версии Go (toolchain).
--
-- Зачем: в статуслайне снизу видно только filetype «go», а КАКАЯ версия Go
-- реально используется — было непонятно. Плюс бывает, что пакет требует
-- go>=1.25, а в PATH стоит go1.23 — нужен способ переключать версию прямо
-- из редактора, как в VS Code.
--
-- Механизм переключения — GOTOOLCHAIN (Go 1.21+):
--   * GOTOOLCHAIN=auto       — авто-выбор по директиве `toolchain`/`go` в
--                              go.mod, при необходимости САМ скачивает (дефолт);
--   * GOTOOLCHAIN=go1.25.0   — жёстко эта версия (скачается, если нет);
--   * GOTOOLCHAIN=local      — строго бинарник `go` из PATH, без авто-скачки.
-- Выставляем vim.env.GOTOOLCHAIN — его наследует gopls (nvim запускает его
-- дочерним процессом), который под капотом зовёт `go`. После смены —
-- перезапускаем gopls, чтобы он перечитал toolchain.

local M = {}

-- nil = ещё не запрашивали; "" = запросили, но не определилось.
local version_cache = nil

-- Узнаём версию АСИНХРОННО (vim.system не блокирует ввод): `go version`
-- уважает GOTOOLCHAIN и печатает реально используемую версию. Кэшируем,
-- статуслайн читает кэш; при готовности дёргаем redrawstatus.
local function refresh_async()
    if vim.fn.executable("go") ~= 1 then
        version_cache = ""
        return
    end
    local ok = pcall(function()
        -- timeout: если GOTOOLCHAIN указывает на неустановленную версию,
        -- `go version` начнёт её СКАЧИВАТЬ; не держим процесс вечно.
        vim.system({ "go", "version" }, { text = true, timeout = 15000 }, function(out)
            local v = ""
            if out.code == 0 and out.stdout then
                v = out.stdout:match("go(%d+%.%d+%.?%d*)") or ""
            end
            version_cache = v
            vim.schedule(function() pcall(vim.cmd, "redrawstatus") end)
        end)
    end)
    if not ok then version_cache = "" end
end

---Версия Go (например "1.23.3"), либо "" пока не подтянулась.
function M.version()
    if version_cache == nil then
        version_cache = ""
        refresh_async()
    end
    return version_cache
end

---Сбросить кэш и перезапросить версию.
function M.refresh()
    version_cache = nil
    refresh_async()
end

---Текущий GOTOOLCHAIN (или "auto (default)", если не задан).
function M.current_toolchain()
    local tc = vim.env.GOTOOLCHAIN
    if tc and tc ~= "" then return tc end
    return "auto (default)"
end

---Метка для статуслайна: «Go 1.23.3» либо «Go 1.25.0*» (звёздочка =
---задан явный GOTOOLCHAIN-оверрайд, т.е. версия принудительная).
function M.label()
    local v = M.version()
    if v == "" then return "" end
    local tc = vim.env.GOTOOLCHAIN
    local overridden = tc and tc ~= "" and tc ~= "auto" and tc ~= "local"
    return "Go " .. v .. (overridden and "*" or "")
end

---Реально установленные версии Go для picker'а :GoToolchain, по убыванию.
---Источники: SDK в ~/sdk/go* (их качают официальные обёртки golang.org/dl
---и GOTOOLCHAIN) + сами обёртки go1.* в GOBIN. Обёртка без скачанного SDK
---тоже годится: при выборе GOTOOLCHAIN найдёт её в PATH и докачает SDK.
function M.installed_versions()
    local seen, list = {}, {}
    local function add(name)
        if name:match("^go%d+%.%d+") and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
        end
    end
    for _, dir in ipairs(vim.fn.glob(vim.fn.expand("~/sdk") .. "/go*", true, true)) do
        add(vim.fn.fnamemodify(dir, ":t"))
    end
    local gobin = vim.env.GOBIN
        or ((vim.env.GOPATH and vim.env.GOPATH ~= "" and vim.env.GOPATH
            or vim.fn.expand("~/go")) .. "/bin")
    for _, f in ipairs(vim.fn.glob(gobin .. "/go1*", true, true)) do
        add(vim.fn.fnamemodify(f, ":t"))
    end
    local function parts(v)
        local maj, min, patch = v:match("^go(%d+)%.(%d+)%.?(%d*)")
        return tonumber(maj) or 0, tonumber(min) or 0, tonumber(patch) or 0
    end
    table.sort(list, function(a, b)
        local a1, a2, a3 = parts(a)
        local b1, b2, b3 = parts(b)
        if a1 ~= b1 then return a1 > b1 end
        if a2 ~= b2 then return a2 > b2 end
        return a3 > b3
    end)
    return list
end

---Переключить toolchain и перезапустить gopls.
---@param ver string "go1.25.0" | "1.25.0" | "auto" | "local"
function M.set_toolchain(ver)
    ver = vim.trim(ver or "")
    if ver == "" then return end
    if ver:match("^%d") then ver = "go" .. ver end -- "1.25.0" → "go1.25.0"

    vim.env.GOTOOLCHAIN = ver
    M.refresh()

    -- forge_lsp_restarting глушит crash-нотификацию в lsp.lua (это НАШ
    -- осознанный рестарт, а не падение сервера).
    vim.g.forge_lsp_restarting = true
    -- Собираем go-буферы ДО остановки, форс-стоп (сервер мог зависнуть и не
    -- ответить на graceful shutdown → старый gopls остался бы с прежним
    -- toolchain), затем ре-attach через FileType (без :edit, чтобы не падать
    -- E37 на изменённом буфере и поднять gopls на ВСЕХ go-буферах).
    local bufs, seen = {}, {}
    for _, c in ipairs(vim.lsp.get_clients({ name = "gopls" })) do
        for b in pairs(c.attached_buffers or {}) do
            if not seen[b] then seen[b] = true; bufs[#bufs + 1] = b end
        end
        pcall(function() c:stop(true) end)
    end
    vim.defer_fn(function()
        vim.g.forge_lsp_restarting = nil
        for _, b in ipairs(bufs) do
            if vim.api.nvim_buf_is_valid(b) then
                pcall(vim.api.nvim_exec_autocmds, "FileType", { buffer = b })
            end
        end
        vim.notify(
            "GOTOOLCHAIN = " .. ver .. " — gopls перезапущен.\n"
            .. "Версия подтянется в статуслайн (нужная toolchain скачается, если её нет).",
            vim.log.levels.INFO, { title = "Go" }
        )
    end, 600)
end

return M
