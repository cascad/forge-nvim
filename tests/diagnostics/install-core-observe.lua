-- spec: IDE-BOOT-30 IDE-BOOT-31. Full config, no specs/stages/LSP substitutes.
local base, round = arg[1], tonumber(arg[2])
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local artifacts = base .. '/round-' .. round
vim.fn.mkdir(artifacts, 'p')
local rpc = require('editor_rpc').start({vim.v.progpath, '--headless', '--embed', '-i', 'NONE',
    '--cmd', 'lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)', '-u', vim.env.FRIDE_CONFIG .. '/init.lua'},
    {cwd = base .. '/project', env = vim.fn.environ(), clear_env = true, artifacts = artifacts, timeout = 90000})
local function lua(code, args) return rpc:request('nvim_exec_lua', {code, args or {}}) end
local function wait_for(name, predicate, timeout)
    local deadline, last = vim.uv.hrtime() + timeout * 1000000
    repeat
        local ok, value = pcall(predicate)
        if ok and value then return value end
        if not ok then last = tostring(value) end
        vim.wait(30)
    until vim.uv.hrtime() >= deadline
    error(name .. (last and (': ' .. last) or ''))
end
local info = {round = round}
local ok, err = xpcall(function()
    rpc:request('nvim_ui_attach', {120, 40, {rgb = true, ext_linegrid = true}})
    wait_for('startup', function() return lua('return vim.v.vim_did_enter == 1') end, 5000)
    info.startup = lua([[return {app=vim.env.NVIM_APPNAME,config=vim.env.FRIDE_CONFIG,
        missing=require('lazy.core.config').options.install.missing,errmsg=vim.v.errmsg}]])
    assert(info.startup.app == 'fride' and info.startup.missing == false, vim.inspect(info.startup))
    if round == 3 then
        info.missing = lua([[local p=require('lazy.core.config').plugins['grug-far.nvim']
            return {installed=p._.installed,path=p.dir,exists=vim.fn.isdirectory(p.dir)==1}]])
        assert(not info.missing.installed and not info.missing.exists, 'Startup reinstalled missing plugin')
        return
    end
    assert(info.startup.errmsg == '', info.startup.errmsg)
    rpc:request('nvim_command', {'Neotree filesystem left'})
    info.files = wait_for('Files panel', function()
        return lua([[if vim.bo.filetype~='neo-tree' then return false end
            local text=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' ')
            return text:find('main.lua',1,true) and text or false]])
    end, 5000)
    rpc:request('nvim_command', {'Neotree close'})
    local function picker(keys, query, file)
        rpc:request('nvim_input', {keys})
        wait_for('Telescope prompt', function() return lua("return vim.bo.filetype=='TelescopePrompt'") end, 5000)
        rpc:request('nvim_input', {query})
        wait_for('Telescope selected matching entry', function()
            return lua([[local file,query=...
                local state=require('telescope.actions.state')
                local e=state.get_selected_entry()
                return state.get_current_line()==query and e
                    and tostring(e.filename or e.value):find(file,1,true) ~= nil]], {file, query})
        end, 5000)
        rpc:request('nvim_input', {'<CR>'})
        wait_for('Telescope opens file', function()
            return lua('return vim.api.nvim_buf_get_name(0):find(...,1,true) ~= nil', {file})
        end, 3000)
    end
    picker('<C-p>', 'main.lua', 'main.lua')
    local opened_at = vim.uv.hrtime()
    info.lsp = wait_for('Native Lua LSP attaches', function()
        return lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='lua_ls'})) do
            if c.initialized then return {name=c.name,cmd=c.config.cmd,root=c.root_dir,
                library=c.config.settings.Lua.workspace.library or {},runtime=vim.env.VIMRUNTIME} end
        end return false]])
    end, 45000)
    info.lsp.attach_ms = (vim.uv.hrtime() - opened_at) / 1e6
    if round == 4 then
        assert(#info.lsp.library == 1 and info.lsp.library[1] == info.lsp.runtime, vim.inspect(info.lsp))
        return
    end
    assert(#info.lsp.library == 0, 'IDE overrides explicit project library: ' .. vim.inspect(info.lsp.library))
    if round == 5 then return end
    if round == 1 then
        info.diagnostic = wait_for('Lua type mismatch diagnostic', function()
            return lua([[for _,d in ipairs(vim.diagnostic.get(0)) do
                if d.code=='assign-type-mismatch' then return {code=d.code,message=d.message} end
            end return false]])
        end, 20000)
        info.diagnostic.elapsed_ms = (vim.uv.hrtime() - opened_at) / 1e6
        rpc:request('nvim_input', {'<Esc>gg0j0cclocal value = "ready"<Esc>:write<CR>'})
        wait_for('Edit/save', function()
            return lua([[return not vim.bo.modified and table.concat(vim.fn.readfile(vim.api.nvim_buf_get_name(0)),' '):find('ready',1,true) ~= nil]])
        end, 5000)
        wait_for('Diagnostic clears after edit', function()
            return lua([[for _,d in ipairs(vim.diagnostic.get(0)) do
                if d.code=='assign-type-mismatch' then return false end
            end return true]])
        end, 10000)
    else
        assert(lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('ready',1,true) ~= nil]]), 'Saved edit lost on restart')
    end
    picker(' fg', 'FRIDE_CORE_NEEDLE', 'notes.txt')
    info.search = lua('return {path=vim.api.nvim_buf_get_name(0),line=vim.api.nvim_win_get_cursor(0)[1]}')
    assert(info.search.line == 2, 'Grep did not open the matching line')
    info.errors = lua([[local errors={}
        for _,e in ipairs(require('forge.log_store').entries()) do
            if e.level>=vim.log.levels.ERROR then errors[#errors+1]=e.message end
        end return errors]])
    assert(#info.errors == 0, vim.inspect(info.errors))
    assert(#rpc.api_errors == 0, vim.inspect(rpc.api_errors))
end, debug.traceback)
info.ok, info.error = ok, not ok and tostring(err) or nil
local observed, state = pcall(lua, [[return {cwd=vim.fn.getcwd(),file=vim.api.nvim_buf_get_name(0),
    diagnostics=vim.diagnostic.get(0),clients=vim.tbl_map(function(c)
        return {name=c.name,initialized=c.initialized,settings=c.config.settings}
    end,vim.lsp.get_clients({bufnr=0})),messages=vim.api.nvim_exec2('messages',{output=true}).output}]])
if observed then info.state = state end
vim.fn.writefile({vim.json.encode(info)}, artifacts .. '/report.json')
vim.fn.writefile(rpc:screen_lines(), artifacts .. '/screen.txt')
vim.fn.writefile(vim.split(table.concat(rpc.stderr), '\n'), artifacts .. '/stderr.txt')
local stopped, cleanup = pcall(require('editor_process').stop, rpc, artifacts, info.error)
if not ok or not stopped or not cleanup.ok or cleanup.exit_code ~= 0 then
    io.stderr:write(tostring(err or cleanup) .. '\n'); vim.cmd('cquit 1')
end
vim.cmd('qa!')
