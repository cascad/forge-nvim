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
-- codelldb готовится Mason на Windows/macOS/Linux. Существующий PATH и
-- прежнее пользовательское Windows location остаются доступными.

local go_targets = require("forge.dap.go")
local resolve_dlv_path = go_targets.resolve_dlv_path
local show_dlv_info = go_targets.show_dlv_info

local function debug_tool_root(launch)
    if launch and type(launch.cwd)=='string' and vim.fn.isdirectory(launch.cwd)==1 then return launch.cwd end
    local buf=vim.g.user_dap_launch_buf
    if type(buf)=='number' and vim.api.nvim_buf_is_valid(buf) then return vim.api.nvim_buf_get_name(buf) end
end

local codelldb_path = require('forge.debug_tools').codelldb

local rust_targets = require("forge.dap.rust")
local cargo_root = rust_targets.cargo_root
local rust_current_program = rust_targets.rust_current_program

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
local section_for_config = ide_dap.output_section

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
    ide_dap.remember_output('terminal')
    -- Инвалидируем pool-entry в nvim-dap (старый buf уже невалиден если
    -- мы reset'нули его в run_config; на всякий случай ещё раз).
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
local launch_context = require("forge.dap.context")
local with_launch_buffer = launch_context.with_launch_buffer

local function run_config(dap_mod, cfg)
    if not cfg then return end
    open_debug_for_config(cfg)
    -- Свежий PTY перед каждым codelldb запуском, вне RPC callback адаптера.
    if type(cfg) == "table" and cfg.type == "codelldb" then
        reset_dap_terminal_buf()
    end
    if require('forge.node').is_config(cfg) and not require('forge.node').debug_ready() then return end
    with_launch_buffer(function()
        dap_mod.run(cfg)
    end)
end

local function current_launch_filetype()
    return with_launch_buffer(function()
        return vim.bo.filetype
    end)
end

local current_launch_path = launch_context.current_launch_path

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

local python_targets = require("forge.dap.python")
local project_python = python_targets.project_python
local debugpy_adapter_executable = python_targets.debugpy_adapter_executable
local debugpy_adapter_python = python_targets.debugpy_adapter_python
local show_python_debug_info = python_targets.show_python_debug_info
local python_debug_opts = python_targets.python_debug_opts
local keep_debugpy_adapter_inside_nvim = python_targets.keep_debugpy_adapter_inside_nvim

local function extend_config(base, fields)
    return vim.tbl_extend("force", vim.deepcopy(base), fields)
end

local function current_file_configs(ft)
    if current_launch_path() == "" then return {} end

    if ft == 'javascript' then
        local config = require('forge.node').default_config(current_launch_path())
        return config and { config } or {}
    elseif ft == 'sh' then
        return { require('forge.bash_debug').default_config(current_launch_path()) }
    elseif ft == "rust" then
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

local function prepare_debug_action()
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
    local session = require("dap").session()
    local cfg = session and session.config
    if cfg and cfg.type then
        ide_dap.show_section(section_for_config(cfg), false, true)
    else
        ide_dap.show_section(nil, false)
    end
end

local function dap_continue()
    prepare_debug_action()
    vim.schedule(function()
        local dap = require("dap")
        if dap.session() then
            dap.continue()
            return
        end

        local choices, path = debug_choices(current_launch_filetype())
        if #choices > 0 then
            if #choices == 1 then
                run_config(dap, choices[1].config)
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
                    run_config(dap, choice.config)
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
    prepare_debug_action()
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

        if #configs == 1 then
            run_config(dap, configs[1])
            return
        end

        vim.ui.select(configs, {
            prompt = "Debug config (" .. vim.fn.fnamemodify(path, ":.") .. "):",
            format_item = format_launch_choice,
        }, function(choice)
            if choice then
                run_config(dap, choice)
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
        cmd = { "BashDebugPrepare" },
        commit = require('ide.backports').revision('nvim-dap'),
        build = function(plugin) require('ide.backports').run('nvim-dap', plugin.dir, 'apply') end,
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
            { "<leader>de", function() require("forge.dap_hover").open() end,   desc = "Debug: eval hover" },
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
            require("forge.dap_hover").setup()
            dap.set_log_level("TRACE")
            pcall(function()
                require("overseer").enable_dap(true)
            end)

            -- true ПОСЛЕ event_initialized текущей сессии. Нужно, чтобы
            -- отличить ШТАТНЫЙ выход delve (после успешного запуска —
            -- глушим warning) от ПАДЕНИЯ НА СТАРТЕ (ошибка сборки → delve
            -- выходит ДО инициализации; такое НЕ глушим, иначе «нижняя панель
            -- просто не открылась» молча — ровно жалоба юзера). Сбрасывается
            -- на старте сессии (before.initialize — см. listeners ниже).
            local session_initialized = false
            -- true, если для текущей сессии уже показали "Error on launch:" —
            -- тогда синтетический "Delve не смог..." НЕ дублируем.
            local launch_error_shown = false

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
            require('forge.node').setup_dap(dap)
            vim.api.nvim_create_user_command("DapShowLog", dap_show_log, {
                desc = "Open DAP log files",
                force = true,
            })

            -- ---------- Диагностика запуска ----------
            -- spec: IDE-DAP-6. Штатный stdio close различает backend (IDE-053).
            -- Его unexpected WARN передаём в UI; Go/TCP имеет отдельную policy.
            do
                local utils = require("dap.utils")
                local original_notify = utils.notify
                -- delve тоже выходит ненулевым кодом при ОБЫЧНОМ завершении —
                -- но ТОЛЬКО эти глушим, и ТОЛЬКО если сессия успела
                -- инициализироваться. Если delve выпал ДО инициализации —
                -- это ошибка сборки/старта: показываем, иначе панель «молча
                -- не открылась».
                local adapter_exit_patterns = {
                    "command `dlv` of adapter `go` exited with %d+",
                    "command `dlv%.exe` of adapter `go` exited with %d+",
                }
                utils.notify = function(msg, log_level)
                    if log_level == vim.log.levels.WARN and type(msg) == "string" then
                        for _, pattern in ipairs(adapter_exit_patterns) do
                            if msg:match(pattern) then
                                if session_initialized then
                                    return -- штатное завершение после запуска
                                end
                                if launch_error_shown then
                                    return -- уже показали "Error on launch:" — не дублируем
                                end
                                -- падение на старте без "Error on launch" →
                                -- НЕ глушим, поясняем (иначе панель «молча не открылась»).
                                vim.schedule(function()
                                    vim.notify(
                                        "Delve не смог запустить Go-программу (ошибка сборки/пути?).\n"
                                        .. "Нижняя панель не открылась, т.к. сессия не стартовала.\n"
                                        .. "Детали: <leader>dL или :DapShowLog",
                                        vim.log.levels.ERROR, { title = "DAP Go" }
                                    )
                                end)
                                return
                            end
                        end
                    end
                    if log_level == vim.log.levels.ERROR and type(msg) == "string" and msg:match("^Error on launch:") then
                        launch_error_shown = true
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

            -- IDE-DAP-1: nvim-dap сам очищает REPL перед initialize.
            -- Повторная очистка на initialized/ответ launch стирала ранние
            -- output events (в том числе сообщение Delve о сборке).

            -- ВАЖНО: Console-секцию dap-ui самим трогать НЕЛЬЗЯ.
            -- nvim-dap recycles term-буферы через свой внутренний пул
            -- (terminals.acquire/release в dap/session.lua). Если мы делаем
            -- nvim_buf_delete(state.last_session_buf) - буфер исчезает, но
            -- в пуле остаётся ссылка на него. На следующем запуске
            -- terminals.acquire отдаёт невалидный bufnr, dap-ui ловит
            -- "Invalid buffer id". Стейл "No terminal for the current
            -- session" между сессиями dap-ui сам разрулит, если console
            -- сделан через layout с element=console.

            -- spec: IDE-PANEL-14. Auto-open follows initialized/stopped and
            -- runInTerminal. Explicit hide lasts until a new real DAP event.
            local function open_debug_view()
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

            -- Сброс флагов сессии — на before.initialize, а НЕ before.launch.
            -- ВАЖНО (иначе спам ложными ошибками): nvim-dap зовёт before.<cmd>
            -- на ОТВЕТ запроса, а не на отправку. delve шлёт событие
            -- `initialized` СРАЗУ после ответа на `initialize` и ДО ответа на
            -- `launch`. Значит порядок такой: initialize-ответ →
            -- before.initialize (сброс в false) → событие initialized
            -- (after.event_initialized → true) → launch-ответ. Если бы сброс
            -- висел на before.launch, он бы занулял флаг УЖЕ ПОСЛЕ
            -- event_initialized — и при штатном завершении (delve выходит
            -- ненулевым кодом) мы бы каждый раз орали ложным "Delve не смог...".
            dap.listeners.before.initialize.forge_session_flag = function()
                session_initialized = false
                launch_error_shown = false
            end
            -- Намеренно НЕ цепляем reset_dapui_console_buf на dap.listeners.before:
            -- listener выполняется СИНХРОННО в callback-обработчике сообщений
            -- от адаптера. nvim_buf_delete каскадно фиатит force_buffers
            -- autocmd dap-ui, тот лазит по окнам, делает set_current_buf —
            -- и весь этот фейерверк прилетает поверх асинхронного канала
            -- nvim-dap. Адаптер ждёт ответ → таймаут "Debug adapter didn't
            -- respond". Reset делаем ДО dap.run в run_config, см.
            -- его выше: тогда мы вне rpc-callback и без побочки.
            dap.listeners.after.event_initialized.forge_session_flag = function() session_initialized = true end
            dap.listeners.after.event_initialized.dapview_config = open_debug_view
            require("forge.dap_output").setup(dap)

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
            -- Восстанавливаем только отсутствующие компоненты: ide.show
            -- идемпотентен. Вывод при остановке не очищаем.
            --
            -- vim.schedule — мы внутри rpc-callback от адаптера; любые
            -- синхронные манипуляции окнами здесь могут поймать таймаут
            -- "Debug adapter didn't respond" (см. коммент у before.launch).
            dap.listeners.after.event_stopped.forge_ensure_sidebar = function(stopped_session)
                vim.schedule(function()
                    -- nvim-dap fills stopped_thread_id after an asynchronous
                    -- threads response. The real stopped event is authoritative.
                    if require("dap").session() ~= stopped_session then return end
                    local ok, ide = pcall(require, "ide")
                    if ok then pcall(ide.show, "dap.sidebar") end
                    local section = section_for_config(stopped_session.config)
                    -- PTY принадлежит runInTerminal; сами не создаём
                    -- новый терминал и не закрываем уже полученный вывод.
                    if ok then pcall(ide.show, "dap." .. section) end
                end)
            end

            -- VS Code-style: после event_terminated/event_exited оставляем
            -- последний state (scopes/watches/stacks/breakpoints/call stack)
            -- видимым — это полезно для post-mortem inspection, и в VS Code
            -- работает так же. Чистка панелей произойдёт при следующем
            -- initialize (nvim-dap очистит REPL, новая сессия обновит scopes).
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
            require('forge.bash_debug').setup(dap)
            -- spec: IDE-DAP-4 поиск нужен при запуске, не при загрузке Go/DAP.
            dap.adapters.codelldb = function(on_config,launch)
                local cl = codelldb_path(debug_tool_root(launch))
                if not cl then
                    vim.notify(
                        "codelldb not found (checked PATH, %LocalAppData%\\codelldb\\adapter\\, Mason).\n"
                        .. "Rust/C/C++ debugging will not work until it is installed.\n"
                        .. "macOS/Linux: установи через :MasonToolsInstall; "
                        .. "если не поставился — :MasonInstall codelldb.\n"
                        .. "Windows: положи codelldb в PATH или %LocalAppData%\\codelldb\\adapter\\.",
                        vim.log.levels.WARN, { title = "DAP" }
                    )
                    return
                end
                on_config({
                    type = "server",
                    port = "${port}",
                    executable = {
                        command = cl,
                        args = { "--port", "${port}" },
                        detached = false,  -- Windows: detached=true иногда роняет дебаггер
                    },
                })
            end

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
                    -- codelldb получает PTY через runInTerminal. На Windows
                    -- internalConsole теряет println!, поэтому integratedTerminal.
                    console = "integratedTerminal",
                }
                if ft == "rust" then
                    launch_config.preLaunchTask = "cargo build (debug)"
                    launch_config.sourceLanguages = { "rust" }
                end
                table.insert(dap.configurations[ft], launch_config)
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

            return {
                dap_configurations = {
                    { type = "go", name = "Attach remote", mode = "remote", request = "attach" },
                },
                delve = {
                    build_flags = "",
                },
            }
        end,
        config = function(_, opts)
            require("dap-go").setup(opts)
            local dap = require("dap")
            local original = dap.adapters.go
            -- spec: IDE-BOOT-4. Публичная adapter-граница вызывается при запуске,
            -- не на FileType; upstream template и его port/options не мутируем.
            dap.adapters.go = function(callback, launch)
                original(function(adapter)
                    local resolved = vim.deepcopy(adapter)
                    -- dap.async.run reuses the caller coroutine. Neotest owns
                    -- its nio coroutine, so native probe yields must start
                    -- from the main loop rather than yield into nio's protocol.
                    vim.schedule(function()
                        require("dap.async").run(function()
                            if resolved.executable then resolved.executable.command = resolve_dlv_path(nil,debug_tool_root(launch)) end
                            callback(resolved)
                        end)
                    end)
                end, launch)
            end
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
