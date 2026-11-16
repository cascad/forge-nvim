local base = arg[1]
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local artifacts = base .. '/picker'
vim.fn.mkdir(artifacts, 'p')
local rpc = require('editor_rpc').start({vim.v.progpath, '--headless', '--embed', '-i', 'NONE',
    '--cmd', 'lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)', '-u', vim.env.FRIDE_CONFIG .. '/init.lua'},
    {cwd = base .. '/project', env = vim.fn.environ(), clear_env = true, artifacts = artifacts})
local function lua(code, args)
    local mode = rpc:request('nvim_get_mode', {})
    assert(not mode.blocking and mode.mode ~= 'r?', 'Editor awaits input: ' .. table.concat(rpc:screen_lines(), '\n'))
    return rpc:request('nvim_exec_lua', {code, args or {}})
end
local function wait_for(description, predicate, timeout)
    -- As in editor:wait, RPC predicates must run outside vim.wait callbacks:
    -- a nested event loop can re-enter the predicate while awaiting its reply.
    local deadline = vim.uv.hrtime() + timeout * 1000000
    local last_error
    repeat
        local ok, ready = pcall(predicate)
        if ok and ready then return end
        if not ok then last_error = tostring(ready) end
        vim.wait(20)
    until vim.uv.hrtime() >= deadline
    error(description .. (last_error and (': ' .. last_error) or ''))
end
local ok, err = xpcall(function()
    rpc:request('nvim_ui_attach', {120, 40, {rgb = true, ext_linegrid = true}})
    local info = lua([[
        require('config.options')
        local deps = assert(vim.env.FORGE_E2E_DEPS)
        for _, name in ipairs({'plenary.nvim', 'telescope.nvim', 'nvim-web-devicons', 'telescope-ui-select.nvim'}) do
            vim.opt.rtp:prepend(deps .. '/lazy/' .. name)
        end
        local path = vim.fn.exepath('rg')
        assert(vim.fs.normalize(path):find(vim.fs.normalize(vim.env.FRIDE_RUNTIME .. '/search/bin/'), 1, true) == 1,
            'System rg shadowed delivered binary: ' .. path)
        assert(vim.fn.executable('fd') == 0, 'Test requires rg fallback without fd')
        local result = vim.system({path, '--version'}, {text = true}):wait(5000)
        assert(result.code == 0 and result.stdout:find('ripgrep 15.2.0', 1, true), result.stderr)
        local specs = require('plugins.telescope')
        for _, spec in ipairs(specs) do
            if spec[1] == 'nvim-telescope/telescope.nvim' then spec.config(spec, spec.opts()) end
        end
        return {rg = path, version = result.stdout}
    ]])
    local function picker_matches()
        return lua([[
            local state = require('telescope.actions.state')
            local picker = state.get_current_picker(vim.api.nvim_get_current_buf())
            local result = {}
            if picker and picker.manager then
                for entry in picker.manager:iter() do
                    result[#result + 1] = {filename = entry.filename or entry.value, lnum = entry.lnum}
                end
            end
            return result
        ]])
    end
    local function search(kind, query, expected_line)
        lua("require('telescope.builtin')." .. kind .. "({previewer=false})")
        -- Telescope schedules startinsert; let it run before real input.
        wait_for('Picker insert mode', function() return rpc:request('nvim_get_mode', {}).mode:sub(1, 1) == 'i' end, 3000)
        rpc:request('nvim_input', {query})
        local matches
        wait_for('Expected unique picker result', function()
            matches = picker_matches()
            return #matches == 1 and matches[1].filename:gsub('\\', '/'):find('найти файл.txt', 1, true) ~= nil
        end, 5000)
        wait_for('Picker selected entry', function()
            return lua("return require('telescope.actions.state').get_selected_entry() ~= nil")
        end, 3000)
        rpc:request('nvim_input', {'<CR>'})
        local opened
        wait_for('Picker opened expected file/line', function()
            opened = lua("return {path=vim.api.nvim_buf_get_name(0),line=vim.api.nvim_win_get_cursor(0)[1]}")
            return opened.path:gsub('\\', '/'):find('найти файл.txt', 1, true) ~= nil and opened.line == expected_line
        end, 3000)
        return {matches = matches, opened = opened}
    end
    info.files = search('find_files', 'найти', 1)
    info.grep = search('live_grep', 'FRIDE_SEARCH_NEEDLE', 2)
    vim.fn.writefile({vim.json.encode(info)}, base .. '/search.json')
end, debug.traceback)
local stopped, stop_error = pcall(require('editor_process').stop, rpc, artifacts, not ok and tostring(err) or nil)
vim.fn.writefile(vim.split(table.concat(rpc.stderr), '\n'), artifacts .. '/stderr.log')
vim.fn.writefile(rpc:screen_lines(), artifacts .. '/screen.txt')
if not ok or not stopped or not stop_error.ok or stop_error.exit_code ~= 0 or stop_error.exit_signal ~= 0 then
    io.stderr:write(tostring(err or stop_error) .. '\n')
    vim.cmd('cquit 1')
end
vim.cmd('qa!')
