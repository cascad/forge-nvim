-- forge/go.lua — показ и переключение версии Go (toolchain).
--
-- Статуслайн читает выбранный режим/последнюю явно запрошенную версию.
-- Запуск Go возможен только по GoVersion/GoToolchain, не от перерисовки.
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

local version_cache, cache_context = "", nil
local query_id = 0

local function context_key()
    return table.concat({ vim.fn.getcwd(), vim.env.GOTOOLCHAIN or "",
        vim.env.PATH or "", vim.env.GOENV or "" }, "\0")
end

---Последняя явно подтверждённая версия в текущем контексте, без subprocess.
function M.version()
    return cache_context == context_key() and version_cache or ""
end

---Явно запросить версию; callback получает исходный context и реальный result.
function M.refresh(callback)
    query_id = query_id + 1
    local id, key = query_id, context_key()
    local context = { cwd = vim.fn.getcwd(), toolchain = M.current_toolchain() }
    version_cache, cache_context = "", key
    local function finish(out)
        vim.schedule(function()
            local version = out.code == 0 and (out.stdout or ""):match("go(%d+%.%d+%.?%d*)") or ""
            version = version or ""
            if id == query_id and key == context_key() then
                version_cache = version
                pcall(vim.cmd, "redrawstatus")
            end
            if callback then callback(version, context, out) end
        end)
    end
    if vim.fn.executable("go") ~= 1 then
        finish({ code = -1, stderr = "go не найден в PATH" })
        return
    end
    -- Явное действие сохраняет обычные Go/GOTOOLCHAIN правила, включая выбор SDK.
    local ok, err = pcall(vim.system, { "go", "version" }, { text = true, timeout = 15000 }, finish)
    if not ok then finish({ code = -1, stderr = tostring(err) }) end
end

---Выбранный env GOTOOLCHAIN; при отсутствии режим определяет сам Go/GOENV.
function M.current_toolchain()
    local tc = vim.env.GOTOOLCHAIN
    if tc and tc ~= "" then return tc end
    return "default (Go environment)"
end

---Метка для статуслайна: «Go 1.23.3» либо «Go 1.25.0*» (звёздочка =
---задан явный GOTOOLCHAIN-оверрайд, т.е. версия принудительная).
function M.label()
    local v = M.version()
    local tc = vim.env.GOTOOLCHAIN
    if v == "" then return "Go " .. (tc and tc ~= "" and tc or "default") end
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
