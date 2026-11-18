-- spec: IDE-BOOT-33 IDE-BOOT-36 IDE-BOOT-38. Native language discovery stays in consumers.
local M = {}
local cache, latest = {}, {}

function M.root(path)
    local implicit = not path or path == ''
    path = path and path ~= '' and path or vim.api.nvim_buf_get_name(0)
    if (path:match('^%w[%w+.-]*://') or implicit and vim.bo.buftype ~= '') and package.loaded.ide then
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if package.loaded.ide.is_main_window(win) then
                path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)); break
            end
        end
    end
    if path == '' or path:match('^%w[%w+.-]*://') then path = vim.fn.getcwd() end
    local stat = vim.uv.fs_stat(path)
    local directory = stat and stat.type == 'directory' and path or vim.fs.dirname(path) or vim.fn.getcwd()
    return vim.fs.root(directory, { '.fride', '.git' }) or directory or vim.fn.getcwd()
end

local function config(path)
    local stat, err, code = vim.uv.fs_stat(path)
    if not stat then
        if code == 'ENOENT' then return {} end
        return nil, err
    end
    if stat.type ~= 'file' or stat.size > 65536 then return nil, 'expected JSON file <=64KiB' end
    local stamp = table.concat({ stat.size, stat.mtime.sec, stat.mtime.nsec }, ':')
    if cache[path] and cache[path].stamp == stamp then return cache[path].tools, cache[path].error end
    local ok, value = pcall(function()
        local handle = assert(io.open(path, 'rb'))
        local raw = handle:read(65537); handle:close()
        assert(#raw <= 65536, 'JSON exceeds64KiB')
        local data = vim.json.decode(raw)
        assert(type(data) == 'table', 'expected JSON object')
        local tools = data.tools == nil and {} or data.tools
        assert(type(tools) == 'table', 'tools must be an object')
        for name, entry in pairs(tools) do
            assert(type(name) == 'string' and type(entry) == 'string' and entry ~= ''
                and not entry:find('%c'), 'tools entries must be nonempty path strings')
        end
        return tools
    end)
    cache[path] = { stamp = stamp, tools = ok and value or nil, error = not ok and tostring(value) or nil }
    return cache[path].tools, cache[path].error
end

function M.files(root)
    return {project=vim.fs.joinpath(M.root(root),'.fride/tools.json'),
        user=vim.fs.joinpath(vim.fn.stdpath('config'),'tools.json')}
end

-- Explicit settings edit; preserve other tools and unknown document metadata.
function M.save(id, value, scope, root)
    assert(scope=='project' or scope=='user','Expected user/project scope')
    assert(type(id)=='string' and id~='','Expected tool id')
    assert(value==nil or type(value)=='string' and value~='' and not value:find('%c'),'Expected path or nil')
    local path=M.files(root)[scope]
    local tools,err=config(path)
    if not tools then error('Tool paths ['..scope..': '..path..']: '..tostring(err),0) end
    local data={}
    if vim.uv.fs_stat(path) then
        local handle=assert(io.open(path,'rb'));local raw=handle:read(65537);handle:close()
        data=vim.json.decode(raw)
    end
    data.tools=vim.deepcopy(tools);data.tools[id]=value
    if vim.tbl_isempty(data.tools) then data.tools=vim.empty_dict() end
    vim.fn.mkdir(vim.fs.dirname(path),'p')
    local temp=path..'.'..vim.uv.os_getpid()..'.tmp'
    local ok,why=pcall(function()
        local handle=assert(io.open(temp,'wb'));assert(handle:write(vim.json.encode(data)..'\n'));assert(handle:close())
        assert(vim.uv.fs_rename(temp,path))
    end)
    if not ok then vim.uv.fs_unlink(temp);error('Tool paths ['..path..']: '..tostring(why),0) end
    cache[path]=nil
    return path
end

function M.current(id) return vim.deepcopy(latest[id]) end

local function record(id, path, source, root, err)
    local text = id .. ' | ' .. (err and ('ERROR: ' .. err) or path or 'not found')
        .. ' | ' .. source .. ' | project: ' .. root
    if not latest[id] or latest[id].text ~= text then
        local store = require('forge.log_store')
        if store.session then store.record(text, err and vim.log.levels.ERROR or vim.log.levels.INFO, 'Tool paths') end
    end
    latest[id] = { id = id, path = path, source = source, root = root, error = err, text = text }
    return path
end

function M.selected(id, path, source, root)
    return record(id, path, source, M.root(root))
end

local function selected_path(value, base, kind)
    local bare = not value:find('[/\\]') and value:sub(1, 1) ~= '~'
    if kind == 'executable' and bare then
        local found = vim.fn.exepath(value)
        if found ~= '' then return found end
    end
    local path = vim.fs.normalize(value)
    if not path:match('^[/\\]') and not path:match('^%a:[/\\]') then path = vim.fs.joinpath(base, path) end
    path = vim.fs.normalize(path)
    if kind == 'executable' then return vim.fn.executable(path) == 1 and path or nil end
    local stat = vim.uv.fs_stat(path)
    return stat and stat.type == (kind == 'directory' and 'directory' or 'file') and path or nil
end

-- Returns nil,false only when there is no explicit setting. Invalid settings throw.
function M.override(id, options)
    options = options or {}
    local root = M.root(options.root)
    local user = vim.fn.stdpath('config')
    local sources = {
        { path = vim.fs.joinpath(root, '.fride/tools.json'), base = root, scope = 'project' },
        { path = vim.fs.joinpath(user, 'tools.json'), base = user, scope = 'user' },
    }
    if options.scope == 'user' then table.remove(sources, 1) end
    local value, base, source
    local function fail(reason)
        local message = 'Tool paths: ' .. id .. ' [' .. source .. ']: ' .. reason
        record(id, nil, source, root, message)
        error(message, 0)
    end
    for _, entry in ipairs(sources) do
        local tools, err = config(entry.path)
        source = entry.scope .. ': ' .. entry.path
        if err then fail(err) end
        if tools[id] ~= nil then value, base = tools[id], entry.base; break end
    end
    if value == nil then
        local global = options.global and vim.g[options.global]
        local env = options.env and vim.env[options.env]
        if global ~= nil and global ~= '' then value, source = global, 'vim.g.' .. options.global
        elseif env and env ~= '' then value, source = env, '$' .. options.env end
        base = vim.fn.getcwd()
    end
    if value == nil then return nil, false end
    if type(value) ~= 'string' or value == '' or value:find('%c') then fail('expected a nonempty path string') end
    local path = selected_path(value, base, options.kind or 'executable')
    if path and options.validate then path = options.validate(path) end
    if not path then fail('invalid ' .. (options.kind or 'executable') .. ': ' .. value) end
    return record(id, path, source, root), true
end

function M.executable(id, options)
    options = options or {}
    local path, explicit = M.override(id, options)
    if explicit then return path end
    path = vim.fn.exepath(options.command or id)
    return M.selected(id, path ~= '' and path or nil, options.source or 'PATH/Mason', options.root)
end

function M.formatter_command(id)
    return function(_, ctx) return M.executable(id, {root=ctx.filename}) or id end
end

-- Keep the pinned native workspace resolver and RPC spawn options.
function M.lsp(server, id, options)
    options = options or {}
    local native = vim.lsp.config[server]
    local root_dir, command = native.root_dir, vim.deepcopy(native.cmd)
    assert(type(root_dir)=='function' and type(command)=='table', 'Expected native LSP config: '..server)
    vim.lsp.config(server, {
        root_dir = function(buf, on_dir)
            local file = vim.api.nvim_buf_get_name(buf)
            if not M.executable(id, {root=file}) then
                if options.missing and not vim.b[buf]['forge_missing_'..server] then
                    vim.b[buf]['forge_missing_'..server]=true
                    vim.schedule(function() vim.notify(options.missing, vim.log.levels.WARN, {title='LSP'}) end)
                end
                return
            end
            vim.b[buf]['forge_missing_'..server]=nil
            root_dir(buf, on_dir)
        end,
        cmd = function(dispatchers, config)
            local argv = vim.deepcopy(command)
            argv[1] = assert(M.executable(id, {root=config.root_dir}), id..' is not prepared')
            return vim.lsp.rpc.start(argv, dispatchers, {
                cwd=config.cmd_cwd, env=config.cmd_env, detached=config.detached,
            })
        end,
    })
    vim.lsp.enable(server)
end

function M.report()
    local checks = {
        { 'python', function() return require('forge.python').resolve({ M.root() }) end },
        { 'node', function() return require('forge.node').executable() end },
        { 'bash', function() return require('forge.bash_host').executable() end },
        { 'js-debug-adapter', function() return require('forge.node').debug_server() end },
        { 'bash-debug-adapter', function() return require('forge.bash_debug').entrypoint() end },
        { 'bats', function() return require('forge.bats').runner(vim.api.nvim_buf_get_name(0)) end },
        { 'sqruff', function() return require('forge.sql_language').tool('sqruff') end },
        { 'gopls', function() return M.executable('gopls') end },
        { 'rust-analyzer', function() return M.executable('rust-analyzer') end },
        { 'gofumpt', function() return M.executable('gofumpt') end },
        { 'golines', function() return M.executable('golines') end },
        { 'rustfmt', function() return M.executable('rustfmt') end },
        { 'codelldb', function() return require('forge.debug_tools').codelldb() end },
        { 'dlv', function() return require('forge.debug_tools').report_dlv() end },
    }
    local out = {}
    for _, check in ipairs(checks) do
        local ok, value = pcall(check[2])
        local entry = latest[check[1]]
        if not ok and (not entry or not entry.error) then record(check[1], nil, 'discovery', M.root(), tostring(value)) end
        out[#out + 1] = vim.deepcopy(latest[check[1]])
    end
    return out
end

function M.setup()
    vim.api.nvim_create_user_command('ForgeToolPaths', function()
        local entries = M.report()
        local store = require('forge.log_store')
        for _, entry in ipairs(entries) do store.record(entry.text, entry.error and 4 or 2, 'Tool paths') end
        vim.cmd('ForgeLogs events:Tool paths')
    end, { desc = 'Show current language tool paths in IDE Logs' })
end

return M
