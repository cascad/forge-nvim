-- spec: IDE-NODE-1 IDE-NODE-2 IDE-NODE-3 IDE-NODE-4.
-- Общая Node граница: executable + JS entrypoint, без shell/.cmd в argv.
local M = {}
local function file(path) return path and vim.fn.filereadable(path) == 1 end
local function join(...) return vim.fs.joinpath(...) end
local function warn(text, reason) require('forge.tool_paths').warn(text, reason, 'Node') end

function M.root(path)
    path = path and path ~= '' and path or vim.api.nvim_buf_get_name(0)
    if path == '' then return vim.fn.getcwd() end
    local package_root = vim.fs.root(path, { 'package.json' })
    if package_root then return package_root end
    -- spec: IDE-NODE-5. Language root уже каталог, его node_modules нельзя пропускать.
    local stat = vim.uv.fs_stat(path)
    return stat and stat.type == 'directory' and path or vim.fs.dirname(path) or vim.fn.getcwd()
end

function M.executable(path)
    local paths = require('forge.tool_paths')
    local selected, explicit = paths.override('node', {root=path,global='forge_node_executable',env='FORGE_NODE_EXECUTABLE'})
    if explicit then return selected end
    local found = vim.fn.exepath('node')
    return paths.selected('node', found ~= '' and found or nil, 'PATH', path)
end

function M.script(package, entry, path, bin)
    local paths=require('forge.tool_paths')
    local selected, explicit = paths.override(package, {root=path,kind='file'})
    if explicit then return selected end
    local function found(candidate,source) return paths.selected(package,candidate,source,path) end
    local root = M.root(path)
    local roots = { root }
    for parent in vim.fs.parents(root) do roots[#roots + 1] = parent end
    for _, dir in ipairs(roots) do
        local candidate = join(dir, 'node_modules', package, entry)
        if file(candidate) then return found(candidate,'project Node module') end
    end
    local shared = vim.g.forge_node_tools or vim.env.FORGE_NODE_TOOLS
    if shared and shared ~= '' then
        local candidate = join(shared, 'node_modules', package, entry)
        if file(candidate) then return found(candidate,'shared Node tools') end
    end
    local candidate = join(vim.fn.stdpath('data'), 'mason/packages', package, 'node_modules', package, entry)
    if file(candidate) then return found(candidate,'Mason Node module') end
    local executable = vim.fn.exepath(bin or package)
    if executable ~= '' then
        local real = vim.uv.fs_realpath(executable) or executable
        if real:gsub('\\', '/'):sub(-#entry) == entry then return found(real,'PATH JS entrypoint') end
        candidate = join(vim.fs.dirname(executable), 'node_modules', package, entry)
        if file(candidate) then return found(candidate,'PATH Node module') end
    end
    local node = M.executable()
    if node then
        for _, dir in ipairs({ vim.fs.dirname(node), vim.fs.dirname(vim.fs.dirname(node)) }) do
            for _, location in ipairs({ 'node_modules', 'lib/node_modules' }) do
                candidate = join(dir, location, package, entry)
                if file(candidate) then return found(candidate,'selected Node modules') end
            end
        end
    end
    return found(nil,'native JS discovery')
end

function M.command(package, entry, path, bin)
    local node, script = M.executable(path), M.script(package, entry, path, bin)
    if node and script then return { node, script } end
end

function M.setup_lsp(options)
    options=options or {server='ts_ls',package='typescript-language-server',entry='lib/cli.mjs',
        init_options={disableAutomaticTypingAcquisition=true},
        missing='JS/TS LSP не запущен. Проверь Node/typescript-language-server; :ForgeLogs.'}
    local server=options.server
    local native=vim.lsp.config[server]
    local original_root = native.root_dir
    vim.lsp.config(server, {
        init_options = options.init_options,
        root_dir = function(buf, on_dir)
            local function ready(root)
                local command = require('forge.tool_paths').lsp_guard(buf, server, function()
                    return M.command(options.package,options.entry,root or vim.api.nvim_buf_get_name(buf))
                end, options.missing)
                if command then on_dir(root) end
            end
            if type(original_root)=='function' then original_root(buf,ready)
            else ready(original_root or vim.fs.root(buf,native.root_markers)) end
        end,
        cmd = function(dispatchers, config)
            local command = assert(M.command(options.package,options.entry,config.root_dir),options.package..' отсутствует')
            command[#command + 1] = '--stdio'
            return vim.lsp.rpc.start(command,dispatchers,{cwd=config.cmd_cwd,env=config.cmd_env,detached=config.detached})
        end,
    })
    vim.lsp.enable(server) -- guarded root не запускает отсутствующие tools
end

function M.prettier()
    return {
        command = function(_, ctx)
            -- Conform resolves command before condition. Empty means unavailable.
            return require('forge.tool_paths').attempt(M.executable, ctx and ctx.filename) or ''
        end,
        prepend_args = function(_, ctx)
            local script = require('forge.tool_paths').attempt(function() return M.script('prettier', 'bin/prettier.cjs', ctx.dirname) end)
            return script and {script} or {}
        end,
        condition = function(_, ctx)
            return require('forge.tool_paths').attempt(function() return M.command('prettier', 'bin/prettier.cjs', ctx.dirname) end) ~= nil
        end,
    }
end

function M.debug_server()
    local paths = require('forge.tool_paths')
    local selected, explicit = paths.override('js-debug-adapter', {kind='file',global='forge_js_debug_server',env='FORGE_JS_DEBUG_SERVER'})
    if explicit then return selected end
    local candidate = join(vim.fn.stdpath('data'), 'mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js')
    return paths.selected('js-debug-adapter', file(candidate) and candidate or nil, 'Mason')
end

function M.debug_ready()
    local paths = require('forge.tool_paths')
    local node, reason = paths.attempt(M.executable)
    if not node then warn('Node.js не найден. Проверь Node/PATH или настройку; :ForgeLogs.', reason);return false end
    local script;script, reason = paths.attempt(M.debug_server)
    if not script then
        warn('js-debug adapter не найден. Проверь :MasonInstall js-debug-adapter или настройку; :ForgeLogs.', reason)
        return false
    end
    return true, node, script
end

function M.is_config(config) return type(config) == 'table' and (config.type == 'pwa-node' or config.type == 'node') end
function M.default_config(path)
    if not path:lower():match('%.m?js$') and not path:lower():match('%.cjs$') then return nil end
    return { name = 'Current Node file', type = 'pwa-node', request = 'launch', program = path,
        cwd = M.root(path), console = 'internalConsole',
        outputCapture = 'std', autoAttachChildProcesses = false, skipFiles = { '<node_internals>/**' } }
end

function M.setup_dap(dap)
    local function adapter(callback)
        local ready, node, script = M.debug_ready()
        if not ready then return end
        callback({ type = 'server', host = '127.0.0.1', port = '${port}',
            executable = { command = node, args = { script, '${port}', '127.0.0.1' }, detached = false },
            enrich_config = function(config, done)
                local copy = vim.deepcopy(config);copy.type = 'pwa-node'
                copy.runtimeExecutable = copy.runtimeExecutable or node
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
    local node, reason = require('forge.tool_paths').attempt(M.executable, path)
    if not node then warn('Node.js не найден. Проверь Node/PATH или настройку; :ForgeLogs.', reason);return end
    return start_task('Node: ' .. vim.fs.basename(path), { node, path }, M.root(path))
end

function M.run_script()
    require('ide').focus_main()
    local root = M.root()
    local ok, package = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(join(root, 'package.json')), '\n')) end)
    if not ok or type(package.scripts) ~= 'table' or vim.tbl_isempty(package.scripts) then warn('NodeRun: нет package.json со scripts.');return end
    local command, reason = require('forge.tool_paths').attempt(function() return M.command('npm', 'bin/npm-cli.js', root) end)
    if not command then warn('NodeRun: Node/npm не найдены. Проверь настройку; :ForgeLogs.', reason);return end
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
        local command, reason = require('forge.tool_paths').attempt(function() return M.command('jest', 'bin/jest.js', args.tree:data().path) end)
        if not command then warn('Jest/Node не найден. Проверь проект и настройку; :ForgeLogs.', reason);return nil end
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
