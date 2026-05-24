-- DAP — Debug Adapter Protocol. nvim-dap is the engine, dap-ui is the UI.
--
-- Adapters/binaries (codelldb, delve, debugpy, js-debug) are installed
-- via mason; mason-nvim-dap auto-wires them to nvim-dap.

return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
            "theHamsta/nvim-dap-virtual-text",
            "jay-babu/mason-nvim-dap.nvim",
            "leoluz/nvim-dap-go",
            "mfussenegger/nvim-dap-python",
        },
        keys = {
            { "<leader>db", function() require("dap").toggle_breakpoint() end,                 desc = "Debug: toggle breakpoint" },
            { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Cond: ")) end, desc = "Debug: cond breakpoint" },
            { "<leader>dc", function() require("dap").continue() end,                          desc = "Debug: continue/start" },
            { "<leader>di", function() require("dap").step_into() end,                         desc = "Debug: step into" },
            { "<leader>do", function() require("dap").step_over() end,                         desc = "Debug: step over" },
            { "<leader>dO", function() require("dap").step_out() end,                          desc = "Debug: step out" },
            { "<leader>dr", function() require("dap").repl.toggle() end,                       desc = "Debug: REPL" },
            { "<leader>dl", function() require("dap").run_last() end,                          desc = "Debug: run last" },
            { "<leader>dt", function() require("dap").terminate() end,                         desc = "Debug: terminate" },
            { "<leader>du", function() require("dapui").toggle() end,                          desc = "Debug: toggle UI" },
            { "<leader>de", function() require("dapui").eval() end, mode = { "n", "v" },       desc = "Debug: eval" },
            { "<leader>dh", function() require("dap.ui.widgets").hover() end,                  desc = "Debug: hover" },
        },
        config = function()
            local dap = require("dap")

            local sign = vim.fn.sign_define
            sign("DapBreakpoint",          { text = "●", texthl = "DiagnosticError", linehl = "",        numhl = "" })
            sign("DapBreakpointCondition", { text = "◐", texthl = "DiagnosticWarn",  linehl = "",        numhl = "" })
            sign("DapLogPoint",            { text = "◆", texthl = "DiagnosticInfo",  linehl = "",        numhl = "" })
            sign("DapStopped",             { text = "▶", texthl = "DiagnosticOk",    linehl = "Visual",  numhl = "" })

            -- Lazy-require dapui inside listeners. A top-level
            -- `require("dapui")` during dap's config triggers a load loop
            -- because nvim-dap-ui's own setup pulls fragments of dap that
            -- aren't fully initialised yet. Deferring the require until
            -- a session is actually starting/ending breaks the cycle.
            dap.listeners.after.event_initialized["user"] = function() require("dapui").open() end
            dap.listeners.before.event_terminated["user"] = function() require("dapui").close() end
            dap.listeners.before.event_exited["user"]     = function() require("dapui").close() end
        end,
    },

    {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {
            layouts = {
                {
                    elements = {
                        { id = "scopes",      size = 0.30 },
                        { id = "breakpoints", size = 0.20 },
                        { id = "stacks",      size = 0.25 },
                        { id = "watches",     size = 0.25 },
                    },
                    position = "left",
                    size = 40,
                },
                {
                    elements = {
                        { id = "repl",    size = 0.5 },
                        { id = "console", size = 0.5 },
                    },
                    position = "bottom",
                    size = 12,
                },
            },
            floating = { border = "rounded" },
            controls = { enabled = true },
        },
    },

    {
        "theHamsta/nvim-dap-virtual-text",
        opts = { commented = true },
    },

    {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
        cmd = { "DapInstall", "DapUninstall" },
        opts = {
            automatic_installation = true,
            ensure_installed = { "codelldb", "delve", "debugpy" },
            handlers = {
                -- Дефолтный handler для всех адаптеров — это mason-nvim-dap
                -- сам регистрирует `dap.adapters.<name>` с путями из Mason.
                function(config) require("mason-nvim-dap").default_setup(config) end,

                -- ВАЖНО: для python НЕ даём mason-nvim-dap делать default_setup.
                -- Иначе он впишет в `dap.adapters.python` жёсткий путь
                -- `…/mason/packages/debugpy/venv/Scripts/python.exe`,
                -- даже если Mason этот пакет не дотащил, и любое
                -- срабатывание DAP-проверки кричит ENOENT.
                -- `dap-python.setup(...)` ниже регистрирует adapter
                -- с умным resolver'ом — оставляем эту работу ему.
                python = function() end,
            },
        },
    },

    {
        "leoluz/nvim-dap-go",
        ft = "go",
        opts = {},
    },

    {
        "mfussenegger/nvim-dap-python",
        ft = "python",
        config = function()
            -- Логика resolver'ов скопирована (упрощённо) из forge-nvim:
            -- debuggee запускается ПРОЕКТНЫМ python (из .venv с зависимостями),
            -- а debugpy-adapter — Mason-овским если есть, иначе тем же
            -- проектным (там обычно есть pip install debugpy), иначе
            -- debugpy-adapter из PATH.
            -- Переопределить вручную можно через:
            --   vim.g.forge_python_path / $FORGE_PYTHON_PATH       — путь к python для debuggee
            --   vim.g.forge_debugpy_runner / $FORGE_DEBUGPY_RUNNER — путь к python для запуска debugpy.adapter

            local is_win = vim.fn.has("win32") == 1

            local function executable_path(p)
                if not p or p == "" then return nil end
                if vim.fn.executable(p) == 1 or vim.fn.filereadable(p) == 1 then
                    return p
                end
                return nil
            end

            local function override(gvar, envvar)
                local v = vim.g[gvar]
                if type(v) == "string" and v ~= "" then return v end
                v = vim.env[envvar]
                if type(v) == "string" and v ~= "" then return v end
                return nil
            end

            local function python_in_env(env_dir)
                if not env_dir or env_dir == "" then return nil end
                return is_win and (env_dir .. "/Scripts/python.exe")
                              or  (env_dir .. "/bin/python")
            end

            local function debugpy_adapter_in_env(env_dir)
                if not env_dir or env_dir == "" then return nil end
                return is_win and (env_dir .. "/Scripts/debugpy-adapter.exe")
                              or  (env_dir .. "/bin/debugpy-adapter")
            end

            local function project_roots()
                local roots, seen = {}, {}
                local function add(path)
                    if not path or path == "" then return end
                    path = vim.fs.normalize(path)
                    if seen[path] then return end
                    seen[path] = true
                    table.insert(roots, path)
                end

                local current = vim.api.nvim_buf_get_name(0)
                local start = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
                local marker = vim.fs.find({
                    "pyproject.toml", "setup.py", "setup.cfg",
                    "requirements.txt", "Pipfile",
                    "poetry.lock", "uv.lock", ".git",
                }, { upward = true, path = start })[1]
                add(marker and vim.fs.dirname(marker) or start)
                add(vim.fn.getcwd())
                return roots
            end

            -- Возвращает {path, source} или nil. Прозрачно показывает, откуда
            -- именно был выбран python — для :DapPythonInfo.
            local function project_python_with_source()
                local explicit = executable_path(override("forge_python_path", "FORGE_PYTHON_PATH"))
                if explicit then return { path = explicit, source = "vim.g.forge_python_path / $FORGE_PYTHON_PATH" } end

                local venv = vim.env.VIRTUAL_ENV
                local p = executable_path(python_in_env(venv))
                if p then return { path = p, source = "$VIRTUAL_ENV (" .. venv .. ")" } end

                local conda = vim.env.CONDA_PREFIX
                if conda then
                    local cp = is_win and (conda .. "/python.exe") or (conda .. "/bin/python")
                    local cpe = executable_path(cp)
                    if cpe then return { path = cpe, source = "$CONDA_PREFIX (" .. conda .. ")" } end
                end

                for _, root in ipairs(project_roots()) do
                    for _, folder in ipairs({ ".venv", "venv", ".env", "env" }) do
                        local cand = executable_path(python_in_env(root .. "/" .. folder))
                        if cand then
                            return { path = cand, source = "project venv: " .. root .. "/" .. folder }
                        end
                    end
                end

                local fallback = vim.fn.exepath("python3")
                if fallback == "" then fallback = vim.fn.exepath("python") end
                if fallback ~= "" then
                    return { path = fallback, source = "$PATH fallback (no project venv found)" }
                end
                return { path = "python", source = "literal fallback" }
            end

            local function project_python()
                return project_python_with_source().path
            end

            local function debugpy_adapter()
                for _, root in ipairs(project_roots()) do
                    for _, folder in ipairs({ ".venv", "venv", ".env", "env" }) do
                        local cand = executable_path(debugpy_adapter_in_env(root .. "/" .. folder))
                        if cand then return cand end
                    end
                end
                local from_path = vim.fn.exepath("debugpy-adapter")
                if from_path ~= "" then return from_path end
                local mason = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv"
                return executable_path(debugpy_adapter_in_env(mason))
            end

            local function debugpy_runner_python()
                local explicit = executable_path(override("forge_debugpy_runner", "FORGE_DEBUGPY_RUNNER"))
                if explicit then return explicit end

                local mason = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv"
                local masonp = executable_path(python_in_env(mason))
                if masonp then return masonp end

                -- Mason не дотащил debugpy — берём проектный python.
                -- В этом venv должен быть установлен пакет `debugpy`
                -- (`pip install debugpy` / `uv add --dev debugpy`).
                return project_python()
            end

            local dap_python = require("dap-python")
            dap_python.resolve_python = project_python
            dap_python.setup(debugpy_runner_python())

            -- Читает pyvenv.cfg рядом с venv'овским python.exe / bin/python.
            -- Возвращает { home, executable, version, ... } или nil.
            local function read_pyvenv_cfg_for(python_path)
                if not python_path then return nil end
                -- python_path вида .../venv/Scripts/python.exe или .../venv/bin/python
                local scripts_or_bin = vim.fs.dirname(python_path)
                if not scripts_or_bin then return nil end
                local venv_root = vim.fs.dirname(scripts_or_bin)
                if not venv_root then return nil end
                local cfg = venv_root .. "/pyvenv.cfg"
                if vim.fn.filereadable(cfg) ~= 1 then return nil end

                local out = { __path = cfg }
                for line in io.lines(cfg) do
                    local k, v = line:match("^%s*([%w_%-]+)%s*=%s*(.-)%s*$")
                    if k then out[k] = v end
                end
                return out
            end

            -- Возвращает массив warning-строк, если венв скорее всего сломан.
            local function venv_warnings(python_path)
                local cfg = read_pyvenv_cfg_for(python_path)
                if not cfg then return {} end
                local warns = {}
                local home = cfg.home or ""
                local base_executable = cfg["base-executable"] or cfg.executable or ""

                -- Признаки CI-сборщика MSYS2 (классический "broken on host machine"):
                -- pyvenv.cfg ссылается на пути MSYS2-runner'а (home/base-executable
                -- содержат "msys64"), которых на пользовательской машине физически
                -- нет — venv считается сломанным.
                local function looks_msys2_ci(p)
                    if p == "" then return false end
                    local lp = p:lower()
                    return lp:find("msys64", 1, true) ~= nil
                end

                if looks_msys2_ci(home) or looks_msys2_ci(base_executable) then
                    table.insert(warns, "venv looks broken: pyvenv.cfg указывает на msys64-python.")
                    table.insert(warns, "  pyvenv.cfg:        " .. cfg.__path)
                    if home ~= ""            then table.insert(warns, "  home             = " .. home) end
                    if base_executable ~= "" then table.insert(warns, "  base-executable  = " .. base_executable) end
                    table.insert(warns, "  Пересоздай venv: rmdir venv && py -3 -m venv venv && venv\\Scripts\\pip install debugpy")
                end

                -- Проверяем, что заявленный base-executable реально существует.
                if base_executable ~= "" and vim.fn.filereadable(base_executable) ~= 1 then
                    table.insert(warns, "venv base-executable не существует: " .. base_executable)
                end

                return warns
            end

            -- Собираем отчёт о состоянии python/debugpy resolver'а.
            local function build_python_report()
                local picked  = project_python_with_source()
                local runner  = debugpy_runner_python()
                local adapter = debugpy_adapter() or "<not found>"

                local lines = {
                    "Python debug:",
                    "  debuggee python  : " .. picked.path,
                    "    chosen by      : " .. picked.source,
                    "  debugpy runner   : " .. runner,
                    "  debugpy-adapter  : " .. adapter,
                    "",
                    "Project roots scanned for .venv / venv / .env / env:",
                }

                for _, root in ipairs(project_roots()) do
                    table.insert(lines, "  - " .. root)
                    for _, folder in ipairs({ ".venv", "venv", ".env", "env" }) do
                        local candidate = python_in_env(root .. "/" .. folder)
                        local found = executable_path(candidate) and "ok" or "no"
                        table.insert(lines, ("      %s/%s  [%s]"):format(root, folder, found))
                    end
                end

                table.insert(lines, "")
                table.insert(lines, "Environment:")
                table.insert(lines, "  $VIRTUAL_ENV = " .. (vim.env.VIRTUAL_ENV or "<unset>"))
                table.insert(lines, "  $CONDA_PREFIX = " .. (vim.env.CONDA_PREFIX or "<unset>"))
                table.insert(lines, "  current buffer = " .. (vim.api.nvim_buf_get_name(0)))
                table.insert(lines, "  cwd = " .. vim.fn.getcwd())
                table.insert(lines, "")
                table.insert(lines, "Overrides:")
                table.insert(lines, "  :let g:forge_python_path = '/abs/path/to/python(.exe)'  -- python для debuggee")
                table.insert(lines, "  :let g:forge_debugpy_runner = '...'                     -- python для запуска debugpy.adapter")

                if picked.source:match("PATH fallback") or picked.source == "literal fallback" then
                    table.insert(lines, "")
                    table.insert(lines, "WARNING: используется python из PATH — в нём, скорее всего, нет debugpy.")
                    table.insert(lines, "         Поставь .venv в корне проекта или укажи vim.g.forge_python_path.")
                end

                local warns = venv_warnings(picked.path)
                if #warns > 0 then
                    table.insert(lines, "")
                    for _, w in ipairs(warns) do table.insert(lines, "WARNING: " .. w) end
                end

                return lines
            end

            -- Открывает scratch-буфер с произвольным содержимым.
            -- Удобнее чем :messages / vim.notify, когда нужно скопировать
            -- многострочный текст (особенно если win32yank ругается на UTF-8
            -- — в scratch-буфере работает и yy, и мышиное выделение).
            local function open_scratch(title, lines)
                vim.cmd("botright new")
                local buf = vim.api.nvim_get_current_buf()
                vim.bo[buf].buftype   = "nofile"
                vim.bo[buf].bufhidden = "wipe"
                vim.bo[buf].swapfile  = false
                vim.bo[buf].buflisted = false
                vim.api.nvim_buf_set_name(buf, title)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.bo[buf].modifiable = false
                vim.bo[buf].readonly   = true
                vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>",
                    { noremap = true, silent = true, desc = "Close scratch buffer" })
            end

            -- :DapPythonInfo            — короткое уведомление через vim.notify
            -- :DapPythonInfo!           — отчёт в отдельный scratch-буфер (q = закрыть)
            vim.api.nvim_create_user_command("DapPythonInfo", function(args)
                local lines = build_python_report()
                if args.bang then
                    open_scratch("[DapPythonInfo]", lines)
                else
                    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "DAP Python" })
                end
            end, {
                bang = true,
                desc = "Show Python/debugpy paths chosen by DAP (use ! for scratch buffer)",
            })

            -- :DapPythonDoctor — фактически дёрнуть выбранный python, проверить
            -- наличие stdlib и пакета debugpy. Вывод — в scratch-буфер.
            -- Полезно когда `:DapPythonInfo` говорит «всё ок», а DAP всё равно падает.
            vim.api.nvim_create_user_command("DapPythonDoctor", function()
                local picked  = project_python_with_source()
                local runner  = debugpy_runner_python()
                local exe     = picked.path

                local function probe(py, code, label)
                    local out, err
                    if vim.fn.executable(py) ~= 1 and vim.fn.filereadable(py) ~= 1 then
                        return { ok = false, label = label, code = -1,
                                 stderr = "executable not found: " .. py }
                    end
                    out = vim.fn.system({ py, "-c", code })
                    err = vim.v.shell_error
                    return {
                        ok     = err == 0,
                        label  = label,
                        code   = err,
                        stdout = vim.trim(out or ""),
                    }
                end

                local lines = {
                    "DapPythonDoctor — реальная проверка выбранных интерпретаторов.",
                    "",
                    "[1] Debuggee python:",
                    "    path : " .. exe,
                }

                local function append_probe(p)
                    table.insert(lines, ("    %s: exit=%d"):format(p.label, p.code))
                    if p.stdout and p.stdout ~= "" then
                        for _, l in ipairs(vim.split(p.stdout, "\n", { plain = true })) do
                            table.insert(lines, "      " .. l)
                        end
                    end
                    if p.stderr then
                        table.insert(lines, "      " .. p.stderr)
                    end
                end

                append_probe(probe(exe,
                    "import sys, encodings; print(sys.version); print(sys.executable)",
                    "stdlib import"))
                append_probe(probe(exe,
                    "import debugpy; print('debugpy', debugpy.__version__)",
                    "debugpy import"))

                if runner ~= exe then
                    table.insert(lines, "")
                    table.insert(lines, "[2] debugpy runner python:")
                    table.insert(lines, "    path : " .. runner)
                    append_probe(probe(runner,
                        "import sys, encodings; print(sys.version); print(sys.executable)",
                        "stdlib import"))
                    append_probe(probe(runner,
                        "import debugpy; print('debugpy', debugpy.__version__)",
                        "debugpy import"))
                end

                local cfg = read_pyvenv_cfg_for(exe)
                if cfg then
                    table.insert(lines, "")
                    table.insert(lines, "pyvenv.cfg (" .. cfg.__path .. "):")
                    for k, v in pairs(cfg) do
                        if k ~= "__path" then
                            table.insert(lines, ("  %s = %s"):format(k, tostring(v)))
                        end
                    end
                end

                local warns = venv_warnings(exe)
                if #warns > 0 then
                    table.insert(lines, "")
                    for _, w in ipairs(warns) do table.insert(lines, "WARNING: " .. w) end
                end

                open_scratch("[DapPythonDoctor]", lines)
            end, { desc = "Probe selected python + debugpy. Open report in scratch buffer." })
        end,
    },
}
