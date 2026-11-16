-- Owned native process subtree for explicit installer acceptance commands.
local root, base = unpack(arg)
package.path = root .. '/tests/lib/?.lua;' .. package.path
local artifacts = base .. '/controller'
vim.fn.mkdir(artifacts, 'p')
local request = vim.json.decode(table.concat(vim.fn.readfile(base .. '/command.json'), '\n'))
local timeout = request.timeout or 60000
local rpc = require('editor_rpc').start({vim.v.progpath, '--headless', '--embed', '-u', 'NONE', '-i', 'NONE'},
    {cwd = root, env = vim.fn.environ(), clear_env = true, artifacts = artifacts, timeout = timeout + 15000})
local ok, err = xpcall(function()
    rpc:request('nvim_exec_lua', {[[
        local request, base = ...
        if vim.fn.has('win32') == 1 then vim.uv.os_setpriority(vim.fn.getpid(), 10) end
        local function record(_, data)
            if data then local f = assert(io.open(base .. '/output.txt', 'ab')); f:write(data); f:close() end
        end
        _G.install_command_result = nil
        vim.system(request.argv, {stdout = record, stderr = record}, function(result)
            vim.schedule(function()
                _G.install_command_result = {code = result.code, signal = result.signal}
                vim.fn.writefile({vim.json.encode(_G.install_command_result)}, base .. '/result.json')
            end)
        end)
    ]], {request, base}})
    local deadline = vim.uv.hrtime() + timeout * 1000000
    repeat
        if rpc:request('nvim_exec_lua', {'return _G.install_command_result', {}}) ~= vim.NIL then return end
        vim.wait(50)
    until vim.uv.hrtime() >= deadline
    error('Explicit command deadline exceeded: ' .. timeout)
end, debug.traceback)
local stopped, cleanup = pcall(require('editor_process').stop, rpc, artifacts, not ok and tostring(err) or nil)
if not ok or not stopped or not cleanup.ok then
    io.stderr:write(tostring(err or cleanup) .. '\n'); vim.cmd('cquit 1')
end
vim.cmd('qa!')
