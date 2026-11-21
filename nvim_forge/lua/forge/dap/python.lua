-- Python interpreter/debugpy resolution and native adapter options.
local context = require("forge.dap.context")
local normalize_path = context.normalize_path
local current_launch_path = context.current_launch_path

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

local function venv_executable(env_dir, name)
    if not env_dir or env_dir == "" then
        return nil
    end
    if vim.fn.has("win32") == 1 then
        return env_dir .. "/Scripts/" .. name .. ".exe"
    end
    return env_dir .. "/bin/" .. name
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
    return require('forge.python').resolve(python_project_roots())
end

-- spec: IDE-PY-3. DAP option coroutines resolve before the adapter is started.
local function launch_python()
    local python = project_python()
    local cwd = vim.fn.getcwd()
    return coroutine.create(function(co)
        require('forge.runtime_sdk').probe('python', python, function(sdk, issue)
            vim.schedule(function()
                local dap = require('dap')
                if normalize_path(vim.fn.getcwd()) ~= normalize_path(cwd) then
                    coroutine.resume(co, dap.ABORT)
                    return
                end
                if not sdk then
                    require('forge.log_store').record(
                        'Current Python file: ' .. python .. '\n' .. tostring(issue),
                        vim.log.levels.ERROR, 'DAP Python')
                    require('fidget').notify('Python SDK не запускается. Подробнее: Space w i.',
                        vim.log.levels.ERROR, { title = 'DAP Python' })
                end
                coroutine.resume(co, sdk and sdk.executable or dap.ABORT)
            end)
        end, cwd)
    end)
end

local function debugpy_adapter_executable()
    local explicit = executable_path(path_from_env_or_global("forge_debugpy_adapter", "FORGE_DEBUGPY_ADAPTER"))
    if explicit then
        return explicit
    end

    for _, root in ipairs(python_project_roots()) do
        for _, folder in ipairs({ ".venv", "venv", ".env", "env" }) do
            local candidate = executable_path(venv_executable(root .. "/" .. folder, "debugpy-adapter"))
            if candidate then
                return candidate
            end
        end
    end

    local from_path = path_executable("debugpy-adapter")
    if from_path then
        return from_path
    end

    local mason_adapter = venv_executable(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv", "debugpy-adapter")
    return executable_path(mason_adapter)
end

local function debugpy_adapter_python()
    local explicit = executable_path(path_from_env_or_global("forge_debugpy_python", "FORGE_DEBUGPY_PYTHON"))
    if explicit then
        return explicit
    end

    local mason_python = venv_executable(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv", "python")
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
            -- spec: IDE-DAP-8. Native budget включает cold initialize и launch debugpy.
            adapter.options.initialize_timeout_sec = 30
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

return {
    project_python = project_python,
    launch_python = launch_python,
    debugpy_adapter_executable = debugpy_adapter_executable,
    debugpy_adapter_python = debugpy_adapter_python,
    show_python_debug_info = show_python_debug_info,
    python_debug_opts = python_debug_opts,
    keep_debugpy_adapter_inside_nvim = keep_debugpy_adapter_inside_nvim,
}
