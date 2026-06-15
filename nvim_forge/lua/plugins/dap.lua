-- Дебаггер. Закрывает боль №4 из helix\PROBLEMS.md (DAP без UI):
--   * постоянная side-panel (variables / stack / watch / scopes / repl)
--   * inline-значения переменных в коде (virtual text)
--   * условные breakpoint'ы через UI
--   * F-клавиши как в VS Code Run-меню
--
-- Стек:
--   * mfussenegger/nvim-dap          — ядро
--   * rcarriga/nvim-dap-ui           — VS Code-style UI (см. plugins/dap-ui.lua):
--     layout 1 = scopes/watches/stacks/breakpoints (left sidebar);
--     layout 2 = console (bottom, PTY debuggee);
--     layout 3 = repl (bottom, interactive REPL).
--     dap-view убран: он рисовал всё в одном окне с табами, что не
--     подходило под VS Code-style разделение.
--   * theHamsta/nvim-dap-virtual-text — inline-значения
--   * leoluz/nvim-dap-go             — Go (delve)
--   * mfussenegger/nvim-dap-python   — Python (debugpy)
--   * Rust: codelldb adapter напрямую (без rustaceanvim).
--     rust-analyzer LSP поднимается обычным nvim-lspconfig в lsp.lua.
--
-- ПОЧЕМУ БЕЗ rustaceanvim:
--   rustaceanvim добавляет experimental/serverStatus, experimental/runnables
--   и собственный LSP-клиент с не до конца совместимыми capabilities
--   (в частности workspace.didChangeWatchedFiles.dynamicRegistration).
--   На маленьких проектах это вызывало 20-сек hang после первого `gd`
--   в std-буфер. Чистый nvim-lspconfig с теми же settings работает
--   как раньше — мгновенно.
--
-- codelldb берётся из PATH (у пользователя стоит в
-- %LocalAppData%\codelldb\adapter\codelldb.exe).

-- Resolve a tool installed by Mason. Returns absolute path or nil.
-- Used to bypass $PATH lookup when there are multiple competing copies of
-- the same tool on disk (e.g. user's own ~/go/bin/dlv vs Mason's pinned dlv).
-- Mason wraps binaries on Windows with .cmd shims; check all suffixes.
local function mason_bin(name)
    local data = vim.fn.stdpath("data")
    local candidates = {
        data .. "/mason/bin/" .. name .. ".cmd",
        data .. "/mason/bin/" .. name .. ".exe",
        data .. "/mason/bin/" .. name,
    }
    for _, candidate in ipairs(candidates) do
        if vim.fn.filereadable(candidate) == 1 then return candidate end
    end
    return nil
end

local function path_join(...)
    return table.concat({ ... }, "/")
end

local function executable_file(path)
    return path and path ~= "" and (vim.fn.executable(path) == 1 or vim.fn.filereadable(path) == 1)
end

local function add_executable_variants(add, dir, name, source)
    if not dir or dir == "" then return end
    local suffixes = vim.fn.has("win32") == 1 and { ".exe", ".cmd", ".bat" } or { "" }
    for _, suffix in ipairs(suffixes) do
        local candidate = path_join(vim.fs.normalize(dir), name .. suffix)
        if executable_file(candidate) then
            add(candidate, source)
        end
    end
end

local function go_env(name)
    if vim.fn.executable("go") ~= 1 then return nil end
    local out = vim.fn.system({ "go", "env", name })
    if vim.v.shell_error ~= 0 then return nil end
    return vim.trim(out)
end

local function parse_dlv_version(path)
    if not executable_file(path) then return nil end
    local out = vim.fn.system({ path, "version" })
    if vim.v.shell_error ~= 0 then return nil end
    local major, minor, patch = out:match("Version:%s*v?(%d+)%.(%d+)%.(%d+)")
    if not major then return nil end
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch),
        text = ("v%s.%s.%s"):format(major, minor, patch),
    }
end

local function compare_versions(a, b)
    if not a and not b then return 0 end
    if a and not b then return 1 end
    if b and not a then return -1 end
    for _, key in ipairs({ "major", "minor", "patch" }) do
        if a[key] ~= b[key] then
            return a[key] > b[key] and 1 or -1
        end
    end
    return 0
end

local function unique_dlv_candidates()
    local candidates, seen = {}, {}

    local function add(path, source)
        if not executable_file(path) then return end
        local normalized = vim.fs.normalize(path):gsub("\\", "/")
        if vim.fn.has("win32") == 1 then
            normalized = normalized:lower()
        end
        if seen[normalized] then return end
        seen[normalized] = true
        table.insert(candidates, {
            path = path,
            source = source,
            version = parse_dlv_version(path),
        })
    end

    local gobin = go_env("GOBIN")
    if gobin and gobin ~= "" then
        add_executable_variants(add, gobin, "dlv", "GOBIN")
    end

    local gopath = go_env("GOPATH")
    if gopath and gopath ~= "" then
        local sep = vim.fn.has("win32") == 1 and ";" or ":"
        for dir in gopath:gmatch("([^" .. sep .. "]+)") do
            add_executable_variants(add, path_join(dir, "bin"), "dlv", "GOPATH/bin")
        end
    end

    local path_dlv = vim.fn.exepath("dlv")
    if path_dlv and path_dlv ~= "" then
        add(path_dlv, "PATH")
    end

    local mason = mason_bin("dlv")
    if mason then
        add(mason, "Mason")
    end

    table.sort(candidates, function(a, b)
        local cmp = compare_versions(a.version, b.version)
        if cmp ~= 0 then return cmp > 0 end
        return a.source < b.source
    end)

    return candidates
end

local function resolve_dlv_path()
    local override = vim.g.forge_dlv_path or vim.env.FORGE_DLV_PATH or vim.env.DLV_PATH
    if override and override ~= "" then
        if executable_file(override) then return override end
        vim.notify("Configured dlv path is not executable: " .. override, vim.log.levels.WARN, { title = "DAP Go" })
    end

    local candidates = unique_dlv_candidates()
    if #candidates > 0 then return candidates[1].path end
    return "dlv"
end

local function show_dlv_info()
    local lines = { "Delve candidates:" }
    for _, candidate in ipairs(unique_dlv_candidates()) do
        table.insert(lines, ("  %s  %s  (%s)"):format(
            candidate.version and candidate.version.text or "unknown",
            candidate.path,
            candidate.source
        ))
    end
    if #lines == 1 then table.insert(lines, "  <none found>") end
    table.insert(lines, "Selected: " .. resolve_dlv_path())
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "DAP Go" })
end

local function codelldb_path()
    -- Сначала пробуем PATH (`where codelldb`).
    if vim.fn.executable("codelldb") == 1 then
        return vim.fn.exepath("codelldb")
    end
    -- Потом стандартное место установки vscode-lldb на Windows.
    local localappdata = vim.fn.expand("$LOCALAPPDATA")
    local guess = localappdata .. "/codelldb/adapter/codelldb.exe"
    if vim.fn.filereadable(guess) == 1 then return guess end
    -- Mason fallback (если решит когда-нибудь поставить).
    local mason = mason_bin("codelldb")
    if mason then return mason end
    return nil
end

local function cargo_root()
    local launch_buf = vim.g.user_dap_launch_buf
    local current_buf = type(launch_buf) == "number"
        and vim.api.nvim_buf_is_valid(launch_buf)
        and launch_buf
        or vim.api.nvim_get_current_buf()
    local current = vim.api.nvim_buf_get_name(current_buf)
    local start = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
    local cargo_toml = vim.fs.find("Cargo.toml", { upward = true, path = start })[1]
    return cargo_toml and vim.fs.dirname(cargo_toml) or vim.fn.getcwd()
end

local function normalize_path(path)
    if not path or path == "" then return "" end
    local normalized = vim.fs.normalize(path):gsub("\\", "/")
    if vim.fn.has("win32") == 1 then
        normalized = normalized:lower()
    end
    return normalized
end

local function dap_abort()
    local ok, dap = pcall(require, "dap")
    return ok and dap.ABORT or nil
end

local function rust_target_has_kind(target, kind)
    for _, value in ipairs(target.kind or {}) do
        if value == kind then return true end
    end
    return false
end

local function rust_target_exe(parsed, target, kind)
    local exe_dir = (parsed.target_directory or cargo_root() .. "/target") .. "/debug"
    if kind == "example" then exe_dir = exe_dir .. "/examples" end

    local exe = exe_dir .. "/" .. target.name
    if vim.fn.has("win32") == 1 then exe = exe .. ".exe" end
    return exe
end

local function rust_current_program()
    local root = cargo_root()
    local manifest_path = vim.fs.normalize(root .. "/Cargo.toml")
    local launch_buf = vim.g.user_dap_launch_buf
    local current_file = type(launch_buf) == "number"
        and vim.api.nvim_buf_is_valid(launch_buf)
        and vim.api.nvim_buf_get_name(launch_buf)
        or vim.api.nvim_buf_get_name(0)
    local meta = vim.fn.system({
        "cargo",
        "metadata",
        "--no-deps",
        "--format-version",
        "1",
        "--manifest-path",
        manifest_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("cargo metadata failed; cannot resolve debug binary", vim.log.levels.ERROR, { title = "DAP" })
        return dap_abort()
    end

    local ok, parsed = pcall(vim.fn.json_decode, meta)
    if not ok or type(parsed) ~= "table" then
        vim.notify("cargo metadata returned invalid JSON", vim.log.levels.ERROR, { title = "DAP" })
        return dap_abort()
    end

    local selected_pkg = nil
    for _, pkg in ipairs(parsed.packages or {}) do
        if vim.fs.normalize(pkg.manifest_path or "") == manifest_path then
            selected_pkg = pkg
            break
        end
    end
    selected_pkg = selected_pkg or (parsed.packages or {})[1]
    if not selected_pkg then
        vim.notify("No Cargo package found for debug", vim.log.levels.ERROR, { title = "DAP" })
        return dap_abort()
    end

    local candidates = {}
    for _, target in ipairs(selected_pkg.targets or {}) do
        if rust_target_has_kind(target, "bin") then
            table.insert(candidates, {
                kind = "bin",
                target = target,
                exe = rust_target_exe(parsed, target, "bin"),
            })
        elseif rust_target_has_kind(target, "example") then
            table.insert(candidates, {
                kind = "example",
                target = target,
                exe = rust_target_exe(parsed, target, "example"),
            })
        end
    end

    local normalized_current = normalize_path(current_file)
    for _, candidate in ipairs(candidates) do
        if normalize_path(candidate.target.src_path) == normalized_current then
            return candidate.exe
        end
    end

    for _, candidate in ipairs(candidates) do
        if candidate.kind == "bin" and candidate.target.name == selected_pkg.name then
            return candidate.exe
        end
    end

    if #candidates == 1 then
        return candidates[1].exe
    elseif #candidates > 1 then
        local names = vim.tbl_map(function(candidate)
            return candidate.target.name .. ":" .. candidate.kind
        end, candidates)
        vim.notify(
            "Multiple Cargo debug targets; using " .. names[1] .. ". Targets: " .. table.concat(names, ", "),
            vim.log.levels.WARN,
            { title = "DAP" }
        )
        return candidates[1].exe
    end

    vim.notify("No bin/example Cargo target found for debug", vim.log.levels.ERROR, { title = "DAP" })
    return dap_abort()
end

local ide_dap = require("ide.dap")

local function remember_launch_buffer()
    local ok, dap = pcall(require, "dap")
    if ok and dap.session() then return end

    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return end
    if vim.bo[buf].buftype ~= "" then return end
    -- Не запоминаем dap-ui-окна (scopes/watches/stacks/breakpoints/
    -- console/repl) как "launch buffer".
    local ft = vim.bo[buf].filetype
    if ft:match("^dapui_") or ft == "dap-repl" then return end

    vim.g.user_dap_launch_buf = buf
end

local function leave_terminal_mode()
    if vim.api.nvim_get_mode().mode:sub(1, 1) == "t" then
        vim.cmd("stopinsert")
    end
end

-- Strip JSONC (line + block comments, trailing commas) so we can feed
-- VS Code's launch.json into vim.json.decode without false positives.
-- String boundaries are tracked so // and /* inside string literals are kept.
local function strip_jsonc(text)
    local out, i, n = {}, 1, #text
    local in_str, esc = false, false
    while i <= n do
        local c = text:sub(i, i)
        if in_str then
            out[#out + 1] = c
            if esc then
                esc = false
            elseif c == "\\" then
                esc = true
            elseif c == '"' then
                in_str = false
            end
            i = i + 1
        else
            if c == '"' then
                in_str = true
                out[#out + 1] = c
                i = i + 1
            elseif c == "/" and text:sub(i + 1, i + 1) == "/" then
                local nl = text:find("\n", i + 2, true) or (n + 1)
                i = nl
            elseif c == "/" and text:sub(i + 1, i + 1) == "*" then
                local close = text:find("*/", i + 2, true)
                i = close and (close + 2) or (n + 1)
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
    end
    local cleaned = table.concat(out)
    cleaned = cleaned:gsub(",(%s*[%]}])", "%1")
    return cleaned
end

local function find_launch_json()
    local launch_buf = vim.g.user_dap_launch_buf
    local current_buf = type(launch_buf) == "number"
        and vim.api.nvim_buf_is_valid(launch_buf)
        and launch_buf
        or vim.api.nvim_get_current_buf()
    local current = vim.api.nvim_buf_get_name(current_buf)
    local start = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
    local hits = vim.fs.find(".vscode", { upward = true, path = start, type = "directory" })
    for _, dir in ipairs(hits) do
        local candidate = dir .. "/launch.json"
        if vim.fn.filereadable(candidate) == 1 then
            return candidate
        end
    end
    local cwd_path = vim.fn.getcwd() .. "/.vscode/launch.json"
    if vim.fn.filereadable(cwd_path) == 1 then return cwd_path end
    return nil
end

-- Load every config from .vscode/launch.json without any filtering.
-- Pre-pass strips JSONC + trailing commas, so the file parses on older nvim
-- builds whose vim.json.decode lacks `skip_comments`. Then hand off to
-- dap.ext.vscode._load_json: it gives us OS-overrides (windows / linux / osx
-- keys lifted onto the config) and ${input:promptString|pickString} support
-- via a __call metatable that nvim-dap invokes in prepare_config.
local function load_launch_configs()
    local path = find_launch_json()
    if not path then return nil end

    local raw = table.concat(vim.fn.readfile(path), "\n")
    local cleaned = strip_jsonc(raw)

    local ok_ext, ext = pcall(require, "dap.ext.vscode")
    if not ok_ext or type(ext._load_json) ~= "function" then
        vim.notify(
            "dap.ext.vscode._load_json unavailable; cannot load launch.json",
            vim.log.levels.WARN,
            { title = "DAP" }
        )
        return nil
    end

    local ok, configs = pcall(ext._load_json, cleaned)
    if not ok then
        vim.notify(
            ("Failed to parse %s: %s"):format(path, tostring(configs)),
            vim.log.levels.WARN,
            { title = "DAP" }
        )
        return nil
    end

    return configs, path
end

local function format_launch_choice(c)
    local name = c.name or "?"
    local type_ = c.type or "?"
    return ("%s  [%s]"):format(name, type_)
end

-- Какую секцию показать в bottom slot по типу адаптера/конфига.
--
-- Конвенция:
--   * codelldb (Rust/C/C++) → "terminal". integratedTerminal → нашу
--     dap-terminal-секцию (см. dap_terminal_win_cmd). Свежий PTY-buffer
--     на каждый запуск, без recycle-пула nvim-dap. На Windows это
--     единственный надёжный путь увидеть println!.
--   * любой адаптер с явным console="integratedTerminal" в launch.json
--     → тоже "terminal", потому что у нас глобально terminal_win_cmd
--     уже подменён, и любой runInTerminal попадёт в dap-terminal.
--   * delve (Go) и debugpy (Python) с internalConsole — output events
--     идут в dap-repl. Соответственно "repl".
local function section_for_config(cfg)
    local type_ = type(cfg) == "table" and cfg.type or cfg
    if type_ == "codelldb" then
        return "terminal"
    end
    if type(cfg) == "table" and cfg.console == "integratedTerminal" then
        return "terminal"
    end
    return "repl"
end

local function open_debug_for_config(cfg)
    -- Канонический момент «старт дебага» — через декларативный триггер
    -- (см. ide/triggers.lua: debug:start → debug-раскладка). Секция зависит
    -- от типа адаптера (console/repl/terminal).
    if cfg and cfg.type then
        require("ide").triggers.fire("debug:start", { section = section_for_config(cfg) })
    else
        ide_dap.open()
    end
end

-- ============================================================
-- DAP terminal buffer (для codelldb / runInTerminal).
-- ============================================================
--
-- Почему не nvim-dap-ui's console:
--   * dap-ui ставит `dap.defaults.fallback.terminal_win_cmd = get_buf`,
--     где get_buf возвращает ТОЛЬКО bufnr (без winnr). termopen без winnr
--     на Windows стартует ConPTY с фоллбэк-размерами и теряет первые
--     println!, потому что edgy в этот момент ещё двигает окно.
--   * nvim-dap session.lua держит pool переиспользуемых terminal-буферов.
--     На второй+ сессии `terminals.acquire` отдаёт recycled bufnr из пула
--     НАПРЯМУЮ, минуя terminal_win_cmd. termopen на recycled terminal-
--     mode буфере на Windows не переинициализирует ConPTY: stdout
--     codelldb (println!) теряется полностью.
--
-- Решение — копируем pre-edgy подход (с nvim-dap-view): на каждую
-- сессию заводим СВЕЖИЙ scratch-buffer, открываем его в bottom-split,
-- edgy ловит по `ft = "dap-terminal"` и кладёт в bottom edgebar.
-- termopen получает живые (bufnr, winnr) → ConPTY стартует корректно.
local _last_dap_terminal_buf = -1

local function reset_dap_terminal_buf()
    if vim.api.nvim_buf_is_valid(_last_dap_terminal_buf) then
        -- Сначала закрываем окна, показывающие старый buf, иначе после
        -- delete останется "пустое" окно в bottom edgebar и edgy полезет
        -- его двигать одновременно с открытием нового — race.
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_is_valid(win)
                and vim.api.nvim_win_get_buf(win) == _last_dap_terminal_buf then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
        pcall(vim.api.nvim_buf_delete, _last_dap_terminal_buf, { force = true })
    end
    _last_dap_terminal_buf = -1
end

local function dap_terminal_win_cmd(_config)
    -- Инвалидируем pool-entry в nvim-dap (старый buf уже невалиден если
    -- мы reset'нули его в run_debug_choice; на всякий случай ещё раз).
    if vim.api.nvim_buf_is_valid(_last_dap_terminal_buf) then
        pcall(vim.api.nvim_buf_delete, _last_dap_terminal_buf, { force = true })
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "dap-terminal"
    vim.bo[buf].buflisted = false
    _last_dap_terminal_buf = buf

    -- Открываем окно ВНИЗУ через `:botright sbuffer N`. Edgy ловит
    -- ft="dap-terminal" и перемещает окно в bottom edgebar (см. plugins/
    -- edgy.lua → bottom views). nvim-dap дальше делает nvim_buf_call(
    -- buf, () => termopen()) — ему важна высота окна для PTY size,
    -- поэтому возвращаем (buf, winnr). Фокус возвращаем в исходное
    -- окно, чтобы курсор не уехал из кода.
    local current_win = vim.api.nvim_get_current_win()
    local ok = pcall(vim.cmd, "botright sbuffer " .. buf)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(current_win) and current_win ~= win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
    if not ok then
        return buf
    end
    return buf, win
end

-- Запустить fn так, чтобы "текущим" буфером для всего внутри был наш
-- сохранённый source-буфер (vim.g.user_dap_launch_buf), а не dap-view.
-- ЗАЧЕМ: nvim-dap резолвит ${file}/${fileDirname}/${relativeFile} через
-- vim.fn.expand("%:p"), а наш overseer-шаблон cargo_root читает имя
-- текущего буфера. Если в момент запуска dap.run focus уже забрала
-- dap-view (потому что мы её открываем до dap.run для мгновенного UI),
-- ${file} превратится в "dap-view://main" и debugpy ловит "Invalid
-- argument", а cargo_root не найдёт Cargo.toml.
local function with_launch_buffer(fn)
    local buf = vim.g.user_dap_launch_buf
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
        return vim.api.nvim_buf_call(buf, fn)
    end
    return fn()
end

local function run_config(dap_mod, cfg)
    with_launch_buffer(function()
        dap_mod.run(cfg)
    end)
end

local function current_launch_filetype()
    return with_launch_buffer(function()
        return vim.bo.filetype
    end)
end

local function current_launch_path()
    return with_launch_buffer(function()
        return vim.api.nvim_buf_get_name(0)
    end)
end

local function split_args(input)
    input = vim.trim(input or "")
    if input == "" then return {} end

    local args, current = {}, {}
    local quote, escaped = nil, false
    for i = 1, #input do
        local ch = input:sub(i, i)
        if escaped then
            table.insert(current, ch)
            escaped = false
        elseif ch == "\\" and quote ~= "'" then
            escaped = true
        elseif quote then
            if ch == quote then
                quote = nil
            else
                table.insert(current, ch)
            end
        elseif ch == '"' or ch == "'" then
            quote = ch
        elseif ch:match("%s") then
            if #current > 0 then
                table.insert(args, table.concat(current))
                current = {}
            end
        else
            table.insert(current, ch)
        end
    end
    if escaped then table.insert(current, "\\") end
    if #current > 0 then table.insert(args, table.concat(current)) end
    return args
end

local function prompt_args(prompt)
    return function()
        if vim.ui.input then
            local co = coroutine.running()
            if co then
                vim.ui.input({ prompt = prompt .. ": ", default = "" }, function(result)
                    vim.schedule(function()
                        coroutine.resume(co, split_args(result or ""))
                    end)
                end)
                return coroutine.yield()
            end
        end
        return split_args(vim.fn.input(prompt .. ": "))
    end
end

local function path_from_env_or_global(global_name, env_name)
    local value = vim.g[global_name]
    if type(value) == "string" and value ~= "" then
        return vim.fn.expand(value)
    end

    value = vim.env[env_name]
    if type(value) == "string" and value ~= "" then
        return vim.fn.expand(value)
    end

    return nil
end

local function executable_path(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    path = vim.fn.expand(path)
    if vim.fn.executable(path) == 1 then
        return path
    end
    return nil
end

local function path_executable(name)
    if vim.fn.executable(name) ~= 1 then
        return nil
    end
    local resolved = vim.fn.exepath(name)
    return resolved ~= "" and resolved or name
end

local function python_in_env(env_dir)
    if not env_dir or env_dir == "" then
        return nil
    end
    if vim.fn.has("win32") == 1 then
        return env_dir .. "/Scripts/python.exe"
    end
    return env_dir .. "/bin/python"
end

local function debugpy_adapter_in_env(env_dir)
    if not env_dir or env_dir == "" then
        return nil
    end
    if vim.fn.has("win32") == 1 then
        return env_dir .. "/Scripts/debugpy-adapter.exe"
    end
    return env_dir .. "/bin/debugpy-adapter"
end

local function python_project_roots()
    local roots, seen = {}, {}
    local function add(path)
        if not path or path == "" then
            return
        end
        path = vim.fs.normalize(path)
        local key = normalize_path(path)
        if seen[key] then
            return
        end
        seen[key] = true
        table.insert(roots, path)
    end

    local current = current_launch_path()
    local start = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
    local marker = vim.fs.find({
        "pyproject.toml",
        "setup.py",
        "setup.cfg",
        "requirements.txt",
        "Pipfile",
        "poetry.lock",
        "uv.lock",
        ".git",
    }, { upward = true, path = start })[1]

    add(marker and vim.fs.dirname(marker) or start)
    add(vim.fn.getcwd())
    add(vim.fn.getcwd(0))

    local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
    for _, client in ipairs(get_clients({ bufnr = 0 })) do
        add(client.config and client.config.root_dir)
    end

    return roots
end

local function project_python()
    local explicit = executable_path(path_from_env_or_global("forge_python_path", "FORGE_PYTHON_PATH"))
    if explicit then
        return explicit
    end

    local venv = vim.env.VIRTUAL_ENV
    local venv_python = executable_path(python_in_env(venv))
    if venv_python then
        return venv_python
    end

    local conda = vim.env.CONDA_PREFIX
    local conda_python = executable_path(
        conda and (vim.fn.has("win32") == 1 and (conda .. "/python.exe") or (conda .. "/bin/python"))
    )
    if conda_python then
        return conda_python
    end

    for _, root in ipairs(python_project_roots()) do
        for _, folder in ipairs({ ".venv", "venv", ".env", "env" }) do
            local candidate = executable_path(python_in_env(root .. "/" .. folder))
            if candidate then
                return candidate
            end
        end
    end

    local from_path = path_executable("python3") or path_executable("python")
    if from_path then
        return from_path
    end

    return "python"
end

local function debugpy_adapter_executable()
    local explicit = executable_path(path_from_env_or_global("forge_debugpy_adapter", "FORGE_DEBUGPY_ADAPTER"))
    if explicit then
        return explicit
    end

    for _, root in ipairs(python_project_roots()) do
        for _, folder in ipairs({ ".venv", "venv", ".env", "env" }) do
            local candidate = executable_path(debugpy_adapter_in_env(root .. "/" .. folder))
            if candidate then
                return candidate
            end
        end
    end

    local from_path = path_executable("debugpy-adapter")
    if from_path then
        return from_path
    end

    local mason_adapter = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/Scripts/debugpy-adapter.exe"
    return executable_path(mason_adapter)
end

local function debugpy_adapter_python()
    local explicit = executable_path(path_from_env_or_global("forge_debugpy_python", "FORGE_DEBUGPY_PYTHON"))
    if explicit then
        return explicit
    end

    local mason_python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/Scripts/python.exe"
    return executable_path(mason_python) or project_python()
end

local function show_python_debug_info()
    local adapter = debugpy_adapter_executable()
    local lines = {
        "Python debug:",
        "  project python: " .. project_python(),
        "  debugpy adapter: " .. (adapter or "<none found; fallback to python -m debugpy.adapter>"),
        "  debugpy python fallback: " .. debugpy_adapter_python(),
        "",
        "Overrides:",
        "  vim.g.forge_python_path / $FORGE_PYTHON_PATH",
        "  vim.g.forge_debugpy_adapter / $FORGE_DEBUGPY_ADAPTER",
        "  vim.g.forge_debugpy_python / $FORGE_DEBUGPY_PYTHON",
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "DAP Python" })
end

local function python_debug_opts()
    return {
        console = "internalConsole",
        config = {
            redirectOutput = true,
            justMyCode = true,
        },
    }
end

local function keep_debugpy_adapter_inside_nvim(adapter_command)
    local dap = require("dap")

    local function mark_attached(adapter)
        if type(adapter) == "table" and adapter.type == "executable" then
            if adapter_command then
                adapter.command = adapter_command
                adapter.args = {}
            end
            adapter.options = adapter.options or {}
            adapter.options.detached = false
        end
        return adapter
    end

    local function wrap_adapter(adapter)
        if type(adapter) == "function" then
            return function(cb, config)
                adapter(function(resolved)
                    cb(mark_attached(resolved))
                end, config)
            end
        end
        return mark_attached(adapter)
    end

    local wrapped = wrap_adapter(dap.adapters.python)
    dap.adapters.python = wrapped
    dap.adapters.debugpy = wrapped
end

local function extend_config(base, fields)
    return vim.tbl_extend("force", vim.deepcopy(base), fields)
end

local function current_file_configs(ft)
    if current_launch_path() == "" then return {} end

    if ft == "rust" then
        local base = {
            type = "codelldb",
            request = "launch",
            program = rust_current_program,
            cwd = cargo_root,
            stopOnEntry = false,
            -- integratedTerminal: codelldb делает runInTerminal-запрос,
            -- nvim-dap создаёт PTY-буфер (через terminal_win_cmd, см.
            -- dap-ui's elements/console.lua), и весь stdout/stderr
            -- запущенной программы рендерится терминалом прямо в этом
            -- буфере (filetype `dapui_console`).
            --
            -- internalConsole для codelldb на Windows не работает — println!
            -- не доходит. Этот workaround — то же, что мы делали в pre-edgy
            -- конфиге (git c3fc6fb) с nvim-dap-view.
            console = "integratedTerminal",
            sourceLanguages = { "rust" },
            preLaunchTask = "cargo build (debug)",
        }
        return {
            extend_config(base, {
                name = "Current Rust file bin",
                args = {},
            }),
            extend_config(base, {
                name = "Current Rust file bin (args)",
                args = prompt_args("Rust CLI args"),
            }),
        }
    elseif ft == "go" then
        local base = {
            type = "go",
            request = "launch",
            mode = "debug",
            program = "${fileDirname}",
            cwd = "${workspaceFolder}",
            outputMode = "remote",
        }
        return {
            extend_config(base, {
                name = "Current Go package",
                args = {},
            }),
            extend_config(base, {
                name = "Current Go package (args)",
                args = prompt_args("Go CLI args"),
            }),
        }
    elseif ft == "python" then
        local base = {
            type = "debugpy",
            request = "launch",
            program = "${file}",
            cwd = "${workspaceFolder}",
            console = "internalConsole",
            redirectOutput = true,
            python = project_python,
            justMyCode = true,
        }
        return {
            extend_config(base, {
                name = "Current Python file",
                args = {},
            }),
            extend_config(base, {
                name = "Current Python file (args)",
                args = prompt_args("Python CLI args"),
            }),
        }
    end

    return {}
end

local function debug_choices(ft)
    local choices = {}
    local configs, path = load_launch_configs()
    for _, cfg in ipairs(configs or {}) do
        table.insert(choices, {
            source = "launch.json",
            path = path,
            config = cfg,
        })
    end
    for _, cfg in ipairs(current_file_configs(ft)) do
        table.insert(choices, {
            source = "current file",
            config = cfg,
        })
    end
    return choices, path
end

local function format_debug_choice(choice)
    local cfg = choice.config or {}
    return ("%s  [%s]  <%s>"):format(cfg.name or "?", cfg.type or "?", choice.source or "?")
end

local function run_debug_choice(dap_mod, choice)
    local cfg = choice.config
    if not cfg then return end
    open_debug_for_config(cfg)
    -- Свежий dap-terminal на каждый старт codelldb-сессии — фикс
    -- "println! теряется после первого запуска". См. комментарий
    -- у dap_terminal_win_cmd выше.
    if type(cfg) == "table" and cfg.type == "codelldb" then
        reset_dap_terminal_buf()
    end
    run_config(dap_mod, cfg)
end

local function dap_continue()
    leave_terminal_mode()
    remember_launch_buffer()
    -- Если сессия уже идёт — открываем правильную секцию для её типа
    -- (для Go это REPL, иначе Console). БЕЗ этого каждый F5/F10/F11
    -- во время Go-сессии перефокусировал бы dap-view на Console и
    -- сбивал юзера, который смотрит вывод в REPL.
    -- Если сессии нет — открываем ТОЛЬКО левый sidebar (без bottom),
    -- чтобы не было мерцания console→repl при запуске Python/Go.
    -- Bottom поднимется в event_initialized listener с правильной
    -- секцией.
    do
        local dap_mod = require("dap")
        local session = dap_mod.session()
        local cfg = session and session.config
        if cfg and cfg.type then
            ide_dap.show_section(section_for_config(cfg), false)
        else
            ide_dap.show_section(nil, false)
        end
    end
    vim.schedule(function()
        local dap = require("dap")
        if dap.session() then
            dap.continue()
            return
        end

        local choices, path = debug_choices(current_launch_filetype())
        if #choices > 0 then
            if #choices == 1 then
                run_debug_choice(dap, choices[1])
                return
            end

            local prompt = path
                and ("Debug configuration (" .. vim.fn.fnamemodify(path, ":.") .. "):")
                or "Debug configuration:"
            vim.ui.select(choices, {
                prompt = prompt,
                format_item = format_debug_choice,
            }, function(choice)
                if choice then
                    run_debug_choice(dap, choice)
                end
            end)
            return
        end

        with_launch_buffer(function()
            dap.continue()
        end)
    end)
end

-- Pick any config from .vscode/launch.json regardless of current filetype.
-- Useful when launching debug from a non-source buffer (README, git status,
-- terminal) or when the active session should target a different language
-- than the focused file's filetype.
local function dap_pick_any()
    leave_terminal_mode()
    remember_launch_buffer()
    -- То же что и в dap_continue: если сессия активна, открываем
    -- секцию её типа, чтобы не сбивать фокус. Без сессии — только
    -- sidebar, чтобы не было мерцания bottom при выборе адаптера.
    do
        local dap_mod = require("dap")
        local session = dap_mod.session()
        local cfg = session and session.config
        if cfg and cfg.type then
            ide_dap.show_section(section_for_config(cfg), false)
        else
            ide_dap.show_section(nil, false)
        end
    end
    vim.schedule(function()
        local dap = require("dap")
        local configs, path = load_launch_configs()
        if not configs or #configs == 0 then
            vim.notify(
                ".vscode/launch.json not found or empty",
                vim.log.levels.WARN,
                { title = "DAP" }
            )
            return
        end

        local function go(cfg)
            open_debug_for_config(cfg)
            if type(cfg) == "table" and cfg.type == "codelldb" then
                reset_dap_terminal_buf()
            end
            run_config(dap, cfg)
        end

        if #configs == 1 then
            go(configs[1])
            return
        end

        vim.ui.select(configs, {
            prompt = "Debug config (" .. vim.fn.fnamemodify(path, ":.") .. "):",
            format_item = format_launch_choice,
        }, function(choice)
            if choice then
                go(choice)
            end
        end)
    end)
end

local function dap_action(name)
    return function()
        leave_terminal_mode()
        vim.schedule(function()
            require("dap")[name]()
        end)
    end
end

local function dap_show_log()
    local paths = {}
    local seen = {}

    local function add(path)
        if not path or path == "" then return end
        path = vim.fs.normalize(path)
        if seen[path] then return end
        seen[path] = true
        table.insert(paths, path)
    end

    local ok, log = pcall(require, "dap.log")
    if ok then
        for _, logger in pairs(log._loggers or {}) do
            if type(logger.get_path) == "function" then
                add(logger:get_path())
            end
        end
        if vim.tbl_isempty(paths) then
            pcall(function()
                add(log.create_logger("dap.log"):get_path())
            end)
        end
    end

    for _, path in ipairs(vim.fn.globpath(vim.fn.stdpath("cache"), "dap*.log", false, true)) do
        add(path)
    end

    table.sort(paths)
    if #paths == 0 then
        vim.notify("No DAP log files found", vim.log.levels.WARN, { title = "DAP" })
    elseif #paths == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(paths[1]))
    else
        vim.ui.select(paths, {
            prompt = "DAP log:",
            format_item = function(path)
                return vim.fn.fnamemodify(path, ":t")
            end,
        }, function(path)
            if path then
                vim.cmd("edit " .. vim.fn.fnameescape(path))
            end
        end)
    end
end

local function dap_sign_icons()
    if vim.g.have_nerd_font then
        return {
            breakpoint = "",
            breakpoint_condition = "",
            breakpoint_rejected = "",
            log_point = "",
            stopped = "",
        }
    end

    return {
        breakpoint = "B",
        breakpoint_condition = "C",
        breakpoint_rejected = "R",
        log_point = "L",
        stopped = ">",
    }
end

return {
    -- =====================================================================
    -- Ядро DAP + UI
    -- =====================================================================
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",                -- см. plugins/dap-ui.lua
            "theHamsta/nvim-dap-virtual-text",
            "nvim-telescope/telescope-dap.nvim",
        },
        keys = {
            -- F-клавиши как в VS Code Run-меню
            { "<F5>",       dap_continue,                                        mode = { "n", "t" }, desc = "DAP: continue / start" },
            { "<S-F5>",     dap_action("terminate"),                             mode = { "n", "t" }, desc = "DAP: terminate" },
            { "<C-S-F5>",   dap_action("restart"),                               mode = { "n", "t" }, desc = "DAP: restart" },
            { "<F9>",       function() require("dap").toggle_breakpoint() end,  desc = "DAP: toggle breakpoint" },
            { "<F10>",      dap_action("step_over"),                             mode = { "n", "t" }, desc = "DAP: step over" },
            { "<F11>",      dap_action("step_into"),                             mode = { "n", "t" }, desc = "DAP: step into" },
            { "<S-F11>",    dap_action("step_out"),                              mode = { "n", "t" }, desc = "DAP: step out" },

            -- helix space.d (дублирует F-клавиши, чтобы не путаться)
            { "<leader>ds", dap_continue,                                        desc = "Debug: start/continue" },
            { "<leader>dc", dap_continue,                                        desc = "Debug: continue" },
            { "<leader>db", function() require("dap").toggle_breakpoint() end,  desc = "Debug: toggle breakpoint" },
            { "<leader>dB", function()
                vim.ui.input({ prompt = "Condition: " }, function(cond)
                    if cond and cond ~= "" then
                        require("dap").set_breakpoint(cond)
                    end
                end)
            end,                                                                  desc = "Debug: conditional breakpoint" },
            { "<leader>do", dap_action("step_over"),                             desc = "Debug: step over" },
            { "<leader>di", dap_action("step_into"),                             desc = "Debug: step into" },
            { "<leader>dO", dap_action("step_out"),                              desc = "Debug: step out" },
            { "<leader>dr", dap_action("restart"),                               desc = "Debug: restart" },
            { "<leader>dq", dap_action("terminate"),                             desc = "Debug: terminate" },
            { "<leader>dp", dap_action("pause"),                                 desc = "Debug: pause" },
            { "<leader>dl", function() require("dap").run_last() end,           desc = "Debug: run last" },
            { "<leader>dP", dap_pick_any,                                        desc = "Debug: pick any launch.json config" },
            { "<leader>dL", dap_show_log,                                      desc = "Debug: show logs" },
            { "<leader>dD", function() ide_dap.toggle() end,                     desc = "Debug: view" },
            { "<leader>du", function() ide_dap.toggle() end,                     desc = "Debug: toggle view" },
            { "<leader>de", function() require("dap.ui.widgets").hover() end,   desc = "Debug: eval hover" },
            { "<leader>dw", function()
                local input = vim.fn.input("Watch: ", vim.fn.expand("<cword>"))
                if input and input ~= "" then
                    require("dapui").elements.watches.add(input)
                    require("ide").show("dap.sidebar")
                end
            end,                                                                  desc = "Debug: watch expression" },
            { "<leader>dw", function()
                local prev_unnamed = vim.fn.getreg('"')
                vim.cmd('normal! gv"vy')
                local sel = vim.fn.getreg("v")
                vim.fn.setreg('"', prev_unnamed)
                if sel and sel ~= "" then
                    require("dapui").elements.watches.add(sel)
                    require("ide").show("dap.sidebar")
                end
            end, mode = "v",                                                      desc = "Debug: watch selection" },
            { "<leader>dR", function() ide_dap.show_repl() end,                desc = "Debug: REPL" },
            { "<C-S-d>",    function() ide_dap.toggle() end,                     desc = "Debug: view" },
        },
        config = function()
            local dap = require("dap")
            dap.set_log_level("TRACE")
            pcall(function()
                require("overseer").enable_dap(true)
            end)

            -- Keep nvim-dap's built-in variable expansion, but validate the
            -- final adapter config right after it. CodeLLDB used through raw
            -- DAP still requires `program`; VS Code's extension-only `cargo`
            -- shortcut is not enough here.
            do
                dap._user_expand_config_variables = dap._user_expand_config_variables
                    or dap.listeners.on_config["dap.expand_variable"]
                local expand_config_variables = dap._user_expand_config_variables
                dap.listeners.on_config["dap.expand_variable"] = function(config)
                    if expand_config_variables then
                        config = expand_config_variables(config)
                    end

                    if config.type == "codelldb" and config.request == "launch" then
                        local program = config.program
                        if program == nil or program == "" then
                            vim.notify(
                                ("DAP config %q has no `program`. nvim-dap/codelldb cannot launch VS Code-only `cargo` configs."):format(config.name or "?"),
                                vim.log.levels.ERROR,
                                { title = "DAP" }
                            )
                            config.program = dap.ABORT
                        elseif type(program) == "string" and program:find("${", 1, true) then
                            vim.notify(
                                ("DAP config %q has unresolved `program`: %s"):format(config.name or "?", program),
                                vim.log.levels.ERROR,
                                { title = "DAP" }
                            )
                            config.program = dap.ABORT
                        elseif type(program) == "string"
                            and (
                                program:gsub("\\", "/"):match("/target/debug/%.exe$")
                                or program:gsub("\\", "/"):match("/target/debug/$")
                            )
                        then
                            vim.notify(
                                ("DAP config %q resolved an empty Rust binary name. Open the src/bin/*.rs file you want to run."):format(config.name or "?"),
                                vim.log.levels.ERROR,
                                { title = "DAP" }
                            )
                            config.program = dap.ABORT
                        end
                    end

                    return config
                end
            end

            local function terminal_map(lhs, command, desc)
                vim.keymap.set(
                    "t",
                    lhs,
                    ("<C-\\><C-n><cmd>lua require('dap').%s()<CR>"):format(command),
                    { desc = desc, silent = true }
                )
            end

            -- Force F-keys to be handled by Neovim even when focus is inside a
            -- DAP terminal/console window. Without this, the second F5 can be
            -- sent to the debuggee or terminal instead of nvim-dap.
            terminal_map("<F5>", "continue", "DAP: continue / start")
            terminal_map("<S-F5>", "terminate", "DAP: terminate")
            terminal_map("<C-S-F5>", "restart", "DAP: restart")
            terminal_map("<F10>", "step_over", "DAP: step over")
            terminal_map("<F11>", "step_into", "DAP: step into")
            terminal_map("<S-F11>", "step_out", "DAP: step out")

            -- We load .vscode/launch.json ourselves in dap_continue() with a
            -- proper JSONC pre-pass (comments + trailing commas), then append
            -- generated current-file configs for the active source buffer.
            -- Disable nvim-dap's built-in provider so it does not double-load
            -- the same file with its stricter parser and append duplicates.
            dap.providers.configs["dap.launch.json"] = function()
                return {}
            end
            vim.api.nvim_create_user_command("DapShowLog", dap_show_log, {
                desc = "Open DAP log files",
                force = true,
            })

            -- ---------- Глушим заведомо безобидные warnings ----------
            -- debugpy.adapter на Windows при normal disconnect выходит с
            -- кодом 1 (известный квирк, не баг конфига). nvim-dap на это
            -- кидает WARN "command python of adapter debugpy exited with 1".
            -- Перехватываем dap.utils.notify и фильтруем такие сообщения.
            -- delve иногда тоже выходит ненулевым кодом при обычном завершении -
            -- держим тот же фильтр шире.
            do
                local utils = require("dap.utils")
                local original_notify = utils.notify
                local benign_patterns = {
                    "command `python` of adapter `debugpy` exited with %d+",
                    "command `python%d?%-?%d*` of adapter `debugpy` exited with %d+",
                    "command `[^`]*[Pp]ython[^`]*` of adapter `debugpy` exited with %d+",
                    "command `[^`]*debugpy%-adapter[^`]*` of adapter `debugpy` exited with %d+",
                    "command `dlv` of adapter `go` exited with %d+",
                    "command `dlv%.exe` of adapter `go` exited with %d+",
                }
                utils.notify = function(msg, log_level)
                    if log_level == vim.log.levels.WARN and type(msg) == "string" then
                        for _, pattern in ipairs(benign_patterns) do
                            if msg:match(pattern) then
                                return
                            end
                        end
                    end
                    if log_level == vim.log.levels.ERROR and type(msg) == "string" and msg:match("^Error on launch:") then
                        local session = dap.session()
                        local cfg = session and session.config
                        local name = cfg and cfg.name or "?"
                        msg = ("%s\nConfig: %s\nOpen details: <leader>dL or :DapShowLog"):format(msg, name)
                    end
                    return original_notify(msg, log_level)
                end
            end

            -- ---------- UI ----------
            local sign_icons = dap_sign_icons()

            require("nvim-dap-virtual-text").setup({
                enabled = true,
                clear_on_continue = true,
                commented = false,
                highlight_changed_variables = true,
                show_stop_reason = true,
                virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",
                display_callback = function(variable, _buf, _stackframe, _node, options)
                    local value = variable.value:gsub("%s+", " ")
                    if options.virt_text_pos == "inline" then
                        return " = " .. value
                    end
                    return variable.name .. " = " .. value
                end,
            })

            local function reset_dap_repl()
                pcall(function()
                    require("dap.repl").clear()
                end)
            end

            -- ВАЖНО: Console-секцию dap-ui самим трогать НЕЛЬЗЯ.
            -- nvim-dap recycles term-буферы через свой внутренний пул
            -- (terminals.acquire/release в dap/session.lua). Если мы делаем
            -- nvim_buf_delete(state.last_session_buf) - буфер исчезает, но
            -- в пуле остаётся ссылка на него. На следующем запуске
            -- terminals.acquire отдаёт невалидный bufnr, dap-ui ловит
            -- "Invalid buffer id". Стейл "No terminal for the current
            -- session" между сессиями dap-ui сам разрулит, если console
            -- сделан через layout с element=console.

            local function open_debug_view()
                reset_dap_repl()
                local session = dap.session()
                local cfg = session and session.config
                if cfg and cfg.type then
                    ide_dap.show_section(section_for_config(cfg), false)
                else
                    ide_dap.open()
                end
            end

            -- Debug mode stays visible after the program exits. Output remains
            -- readable, and leaving Debug is an explicit layout switch
            -- (<leader>mc or another <leader>m... mode).
            dap.defaults.fallback.focus_terminal = false
            dap.defaults.fallback.switchbuf = "usevisible,usetab,newtab"

            -- ПЕРЕЗАПИСЫВАЕМ dap-ui's terminal_win_cmd (см. elements/
            -- console.lua → `dap.defaults.fallback.terminal_win_cmd = get_buf`).
            -- Наш `dap_terminal_win_cmd` (выше в файле) каждый запуск
            -- codelldb создаёт СВЕЖИЙ scratch-buffer (ft=dap-terminal) и
            -- открывает его в bottom-split. Edgy ловит ft и кладёт в
            -- bottom edgebar (см. plugins/edgy.lua → views.bottom).
            -- termopen получает живые (bufnr, winnr) → ConPTY стартует
            -- корректно, println! не теряется. См. подробный комментарий
            -- у dap_terminal_win_cmd / reset_dap_terminal_buf.
            dap.defaults.fallback.terminal_win_cmd = dap_terminal_win_cmd

            dap.listeners.before.attach.dapview_config = reset_dap_repl
            dap.listeners.before.launch.dapview_config = reset_dap_repl
            -- Намеренно НЕ цепляем reset_dapui_console_buf на dap.listeners.before:
            -- listener выполняется СИНХРОННО в callback-обработчике сообщений
            -- от адаптера. nvim_buf_delete каскадно фиатит force_buffers
            -- autocmd dap-ui, тот лазит по окнам, делает set_current_buf —
            -- и весь этот фейерверк прилетает поверх асинхронного канала
            -- nvim-dap. Адаптер ждёт ответ → таймаут "Debug adapter didn't
            -- respond". Reset делаем ДО dap.run в run_debug_choice, см.
            -- его выше: тогда мы вне rpc-callback и без побочки.
            dap.listeners.after.event_initialized.dapview_config = open_debug_view

            -- VS Code-style: на КАЖДОЙ остановке исполнения (breakpoint,
            -- паника Rust/fatalpanic, исключение, step) гарантируем что
            -- левый debug-sidebar виден и в нём актуальные scopes/call
            -- stack. event_initialized срабатывает РОВНО ОДИН РАЗ при
            -- старте сессии — если программа стопается/паникует позже
            -- (а sidebar к тому моменту скрыт: юзер ушёл в код, edgy
            -- схлопнул окно, паника открыла stdlib-исходник поверх), без
            -- этого listener'а панель не появлялась — ровно баг, который
            -- описал юзер ("остановился на fatalpanic, но layout не висит").
            --
            -- Только sidebar (idempotent ide.show) — bottom (terminal/repl)
            -- НЕ трогаем: он уже поднят на init, а hide/show его на каждом
            -- стопе мигал бы выводом. reset_dap_repl тоже НЕ зовём —
            -- иначе на каждой остановке чистили бы вывод REPL.
            --
            -- vim.schedule — мы внутри rpc-callback от адаптера; любые
            -- синхронные манипуляции окнами здесь могут поймать таймаут
            -- "Debug adapter didn't respond" (см. коммент у before.launch).
            dap.listeners.after.event_stopped.forge_ensure_sidebar = function()
                vim.schedule(function()
                    if not require("dap").session() then return end
                    local ok, ide = pcall(require, "ide")
                    if ok then pcall(ide.show, "dap.sidebar") end
                end)
            end

            -- VS Code-style: после event_terminated/event_exited оставляем
            -- последний state (scopes/watches/stacks/breakpoints/call stack)
            -- видимым — это полезно для post-mortem inspection, и в VS Code
            -- работает так же. Чистка панелей произойдёт при следующем
            -- launch (reset_dap_repl + новая сессия перезатрёт scopes).
            dap.listeners.after.setBreakpoints.user_breakpoint_diagnostics = function(_, err, response, request)
                if err then
                    vim.notify("Error setting breakpoints: " .. tostring(err), vim.log.levels.ERROR, { title = "DAP" })
                    return
                end

                for index, bp in ipairs(response and response.breakpoints or {}) do
                    if bp.verified == false then
                        local source = request
                            and request.arguments
                            and request.arguments.source
                            and request.arguments.source.path
                            or "unknown source"
                        local message = bp.message and (": " .. bp.message) or ""
                        vim.notify(
                            ("Breakpoint rejected %s:%s%s"):format(source, bp.line or index, message),
                            vim.log.levels.WARN,
                            { title = "DAP" }
                        )
                    end
                end
            end

            -- ---------- Иконки в gutter ----------
            local sign = vim.fn.sign_define
            sign("DapBreakpoint",          { text = sign_icons.breakpoint,           texthl = "DiagnosticError",  numhl = "" })
            sign("DapBreakpointCondition", { text = sign_icons.breakpoint_condition, texthl = "DiagnosticWarn",   numhl = "" })
            sign("DapBreakpointRejected",  { text = sign_icons.breakpoint_rejected,  texthl = "DiagnosticError",  numhl = "" })
            sign("DapLogPoint",            { text = sign_icons.log_point,            texthl = "DiagnosticInfo",   numhl = "" })
            sign("DapStopped",             { text = sign_icons.stopped,              texthl = "DiagnosticWarn",   linehl = "Visual", numhl = "" })

            -- =================================================================
            -- codelldb adapter — для C / C++ / Rust.
            -- =================================================================
            local cl = codelldb_path()
            if cl then
                dap.adapters.codelldb = {
                    type = "server",
                    port = "${port}",
                    executable = {
                        command = cl,
                        args = { "--port", "${port}" },
                        detached = false,  -- Windows: detached=true иногда роняет дебаггер
                    },
                }

                for _, ft in ipairs({ "c", "cpp", "rust" }) do
                    dap.configurations[ft] = dap.configurations[ft] or {}
                    local launch_config = {
                        name = "codelldb: launch",
                        type = "codelldb",
                        request = "launch",
                        program = ft == "rust"
                            and rust_current_program
                            or function()
                                return vim.fn.input(
                                    "Path to executable: ",
                                    vim.fn.getcwd() .. "/", "file"
                                )
                            end,
                        cwd = ft == "rust" and cargo_root or "${workspaceFolder}",
                        stopOnEntry = false,
                        args = {},
                        -- Standard convention in this config: codelldb получает
                        -- PTY через runInTerminal -> dap-ui's `dapui_console`
                        -- буфер (см. terminal_win_cmd wrapper ниже). На
                        -- Windows codelldb с `internalConsole` теряет println!,
                        -- поэтому только integratedTerminal.
                        console = "integratedTerminal",
                    }
                    if ft == "rust" then
                        launch_config.preLaunchTask = "cargo build (debug)"
                        -- Enables CodeLLDB Rust data formatters from the active Rust toolchain.
                        launch_config.sourceLanguages = { "rust" }
                    end
                    table.insert(dap.configurations[ft], launch_config)
                end
            else
                vim.schedule(function()
                    vim.notify(
                        "codelldb not found in PATH or %LocalAppData%\\codelldb\\adapter\\.\n"
                        .. "Rust/C/C++ debugging will not work until you install it.",
                        vim.log.levels.WARN, { title = "DAP" }
                    )
                end)
            end

            -- telescope-dap расширение (frames / commands / breakpoints picker)
            pcall(function() require("telescope").load_extension("dap") end)
        end,
    },

    -- =====================================================================
    -- Go: nvim-dap-go (delve)
    -- =====================================================================
    {
        "leoluz/nvim-dap-go",
        ft = "go",
        dependencies = { "mfussenegger/nvim-dap" },
        opts = function()
            vim.api.nvim_create_user_command("DapGoDlvInfo", show_dlv_info, {
                desc = "Show Delve candidates and selected dlv path",
            })

            local dlv = resolve_dlv_path()
            return {
                dap_configurations = {
                    { type = "go", name = "Attach remote", mode = "remote", request = "attach" },
                },
                delve = {
                    path = dlv,
                    build_flags = "",
                },
            }
        end,
        keys = {
            { "<leader>dt", function() require("dap-go").debug_test() end, desc = "Debug: Go test under cursor", ft = "go" },
            { "<leader>dT", function() require("dap-go").debug_last_test() end, desc = "Debug: last Go test",       ft = "go" },
        },
    },

    -- =====================================================================
    -- Python: nvim-dap-python (debugpy через mason)
    -- =====================================================================
    {
        "mfussenegger/nvim-dap-python",
        ft = "python",
        dependencies = { "mfussenegger/nvim-dap" },
        config = function()
            local dap_python = require("dap-python")
            dap_python.resolve_python = project_python

            local adapter = debugpy_adapter_executable()
            dap_python.setup(debugpy_adapter_python(), {
                include_configs = false,
                console = "internalConsole",
                pythonPath = project_python,
            })
            keep_debugpy_adapter_inside_nvim(adapter)
            vim.api.nvim_create_user_command("DapPythonInfo", show_python_debug_info, {
                desc = "Show Python/debugpy paths selected by DAP",
            })
        end,
        keys = {
            { "<leader>dt", function() require("dap-python").test_method(python_debug_opts()) end, desc = "Debug: Python test method",   ft = "python" },
            { "<leader>dT", function() require("dap-python").test_class(python_debug_opts()) end,  desc = "Debug: Python test class",    ft = "python" },
        },
    },
}
