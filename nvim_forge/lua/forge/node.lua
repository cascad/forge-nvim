-- spec: IDE-NODE-1 IDE-NODE-2 IDE-NODE-3 IDE-NODE-4.
-- Общая Node граница: executable + JS entrypoint, без shell/.cmd в argv.
local M = {}
local function file(path) return path and vim.fn.filereadable(path) == 1 end
local function join(...) return vim.fs.joinpath(...) end
local function warn(text) vim.notify(text, vim.log.levels.WARN, { title = 'Node' }) end

function M.root(path)
    path = path and path ~= '' and path or vim.api.nvim_buf_get_name(0)
    if path == '' then return vim.fn.getcwd() end
    return vim.fs.root(path, { 'package.json' }) or vim.fs.dirname(path) or vim.fn.getcwd()
end

function M.executable()
    local explicit = vim.g.forge_node_executable or vim.env.FORGE_NODE_EXECUTABLE
    if explicit and explicit ~= '' then return vim.fn.executable(explicit) == 1 and explicit or nil end
    local found = vim.fn.exepath('node')
    return found ~= '' and found or nil
end

function M.script(package, entry, path, bin)
    local root = M.root(path)
    local roots = { root }
    for parent in vim.fs.parents(root) do roots[#roots + 1] = parent end
    for _, dir in ipairs(roots) do
        local candidate = join(dir, 'node_modules', package, entry)
        if file(candidate) then return candidate end
    end
    local shared = vim.g.forge_node_tools or vim.env.FORGE_NODE_TOOLS
    if shared and shared ~= '' then
        local candidate = join(shared, 'node_modules', package, entry)
        if file(candidate) then return candidate end
    end
    local candidate = join(vim.fn.stdpath('data'), 'mason/packages', package, 'node_modules', package, entry)
    if file(candidate) then return candidate end
    local executable = vim.fn.exepath(bin or package)
    if executable ~= '' then
        local real = vim.uv.fs_realpath(executable) or executable
        if real:gsub('\\', '/'):sub(-#entry) == entry then return real end
        candidate = join(vim.fs.dirname(executable), 'node_modules', package, entry)
        if file(candidate) then return candidate end
    end
    local node = M.executable()
    if node then
        for _, dir in ipairs({ vim.fs.dirname(node), vim.fs.dirname(vim.fs.dirname(node)) }) do
            for _, location in ipairs({ 'node_modules', 'lib/node_modules' }) do
                candidate = join(dir, location, package, entry)
                if file(candidate) then return candidate end
            end
        end
    end
end

function M.command(package, entry, path, bin)
    local node, script = M.executable(), M.script(package, entry, path, bin)
    if node and script then return { node, script } end
end

function M.setup_lsp()
    local original_root = vim.lsp.config.ts_ls.root_dir
    vim.lsp.config('ts_ls', {
        init_options = { disableAutomaticTypingAcquisition = true },
        root_dir = function(buf, on_dir)
            original_root(buf, function(root)
                if M.command('typescript-language-server', 'lib/cli.mjs', root or vim.api.nvim_buf_get_name(buf)) then on_dir(root) end
            end)
        end,
        cmd = function(dispatchers, config)
            local command = assert(M.command('typescript-language-server', 'lib/cli.mjs', config.root_dir), 'TypeScript Language Server отсутствует')
            command[#command + 1] = '--stdio'
            return vim.lsp.rpc.start(command, dispatchers)
        end,
    })
    vim.lsp.enable('ts_ls') -- guarded root не запускает отсутствующие tools
end

function M.prettier()
    return {
        command = function() return M.executable() or 'node' end,
        prepend_args = function(_, ctx) return { M.script('prettier', 'bin/prettier.cjs', ctx.dirname) or '__missing_prettier__' } end,
        condition = function(_, ctx) return M.command('prettier', 'bin/prettier.cjs', ctx.dirname) ~= nil end,
    }
end

function M.debug_server()
    local explicit = vim.g.forge_js_debug_server or vim.env.FORGE_JS_DEBUG_SERVER
    if explicit and explicit ~= '' then return file(explicit) and explicit or nil end
    local candidate = join(vim.fn.stdpath('data'), 'mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js')
    return file(candidate) and candidate or nil
end

function M.debug_ready()
    if not M.executable() then warn('Node.js не найден. Установи Node.js и добавь node в PATH.');return false end
    if not M.debug_server() then
        warn('js-debug adapter не найден. Явно выполни :MasonInstall js-debug-adapter или задай FORGE_JS_DEBUG_SERVER (dapDebugServer.js).')
        return false
    end
    return true
end

function M.is_config(config) return type(config) == 'table' and (config.type == 'pwa-node' or config.type == 'node') end
function M.default_config(path)
    if not path:lower():match('%.m?js$') and not path:lower():match('%.cjs$') then return nil end
    return { name = 'Current Node file', type = 'pwa-node', request = 'launch', program = path,
        cwd = M.root(path), runtimeExecutable = M.executable() or 'node', console = 'internalConsole',
        outputCapture = 'std', autoAttachChildProcesses = false, skipFiles = { '<node_internals>/**' } }
end

function M.setup_dap(dap)
    local function adapter(callback)
        if not M.debug_ready() then return end
        callback({ type = 'server', host = '127.0.0.1', port = '${port}',
            executable = { command = M.executable(), args = { M.debug_server(), '${port}', '127.0.0.1' }, detached = false },
            enrich_config = function(config, done)
                local copy = vim.deepcopy(config);copy.type = 'pwa-node'
                copy.runtimeExecutable = copy.runtimeExecutable or M.executable()
                copy.console = copy.console or 'internalConsole'
                copy.outputCapture = copy.outputCapture or 'std'
                done(copy)
            end,
        })
    end
    dap.adapters['pwa-node'], dap.adapters.node = adapter, adapter
end

local function start_task(name, command, cwd)
    local task = require('overseer').new_task({ name = name, cmd = command, cwd = cwd, components = { 'default' } })
    task:start();require('ide').triggers.fire('task:run')
    return task
end

function M.run_file()
    require('ide').focus_main()
    local path = vim.api.nvim_buf_get_name(0)
    if not M.default_config(path) then warn('NodeRunFile: нужен сохранённый .js/.cjs/.mjs; для JSX/TS используй package script.');return end
    if not M.executable() then warn('Node.js не найден в PATH.');return end
    return start_task('Node: ' .. vim.fs.basename(path), { M.executable(), path }, M.root(path))
end

function M.run_script()
    require('ide').focus_main()
    local root = M.root()
    local ok, package = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(join(root, 'package.json')), '\n')) end)
    if not ok or type(package.scripts) ~= 'table' or vim.tbl_isempty(package.scripts) then warn('NodeRun: нет package.json со scripts.');return end
    local command = M.command('npm', 'bin/npm-cli.js', root)
    if not command then warn('NodeRun: Node/npm не найдены. Установи Node.js с npm.');return end
    local names = vim.tbl_keys(package.scripts);table.sort(names)
    vim.ui.select(names, { prompt = 'Node package script:' }, function(name)
        if name then start_task('npm: ' .. name, vim.list_extend(vim.deepcopy(command), { 'run', name }), root) end
    end)
end

local jest_adapter
function M.jest()
    if jest_adapter then return jest_adapter end
    local adapter = require('neotest-jest')({ jestCommand = 'node', cwd = function(path)
            require('nio').scheduler();return M.root(path)
        end,
        strategy_config = function(config, args)
            if args.strategy == 'dap' then
                require('nio').scheduler() -- callback после async file I/O
                config.program = M.script('jest', 'bin/jest.js', args.tree:data().path)
                config.runtimeExecutable = M.executable()
                config.console, config.outputCapture = 'internalConsole', 'std'
                config.autoAttachChildProcesses = false
            end
            return config
        end,
    })
    local build = adapter.build_spec
    adapter.build_spec = function(args)
        require('nio').scheduler()
        local command = M.command('jest', 'bin/jest.js', args.tree:data().path)
        if not command then warn('Jest/Node не найден. Установи Jest в проекте (npm install --save-dev jest).');return nil end
        if args.strategy == 'dap' and not M.debug_ready() then return nil end
        local spec = build(args)
        require('nio').scheduler()
        spec.command = vim.list_extend(command, vim.list_slice(spec.command, 2))
        -- Native adapter превращает путь в regex. Jest сравнивает его с
        -- платформенными путями; literal path не требует regex escaping.
        local path = args.tree:data().path
        spec.command[#spec.command] = path
        table.insert(spec.command, #spec.command, vim.fn.isdirectory(path) == 1 and '--roots' or '--runTestsByPath')
        if args.strategy == 'dap' then spec.strategy.args = vim.list_slice(spec.command, 3) end
        return spec
    end
    jest_adapter = adapter
    return adapter
end
return M
