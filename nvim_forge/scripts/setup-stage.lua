-- spec: IDE-BOOT-9 IDE-BOOT-15. Явная подготовка; native +command errors сами дают exit0.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
package.path = root .. '/lua/?.lua;' .. package.path
local stage = arg[1]
local ok, err = xpcall(function()
    if stage == 'plugins' then
        vim.cmd('Lazy! restore')
        local backports = require('ide.backports')
        local directory = vim.fn.stdpath('data') .. '/lazy'
        backports.all(directory, 'apply')
        local checked = backports.all(directory, 'check')
        io.stdout:write('Backports checked: ' .. vim.json.encode(checked) .. '\n')
    elseif stage == 'parsers' then
        vim.cmd('ForgeTreesitterInstall')
        local report = require('forge.setup_readiness').parsers(require('forge.tool_catalog').parsers())
        io.stdout:write('Parser readiness: ' .. vim.json.encode(report) .. '\n')
    elseif stage == 'tools' then
        vim.cmd('Lazy load mason-tool-installer.nvim')
        vim.cmd('MasonToolsInstallSync')
        local report = require('forge.setup_readiness').tools(require('forge.tool_catalog').mason())
        io.stdout:write('Tool readiness: ' .. vim.json.encode(report) .. '\n')
    else
        error('Unknown setup stage: ' .. tostring(stage))
    end
end, debug.traceback)
if not ok then
    io.stderr:write('Setup stage ' .. tostring(stage) .. ' failed: ' .. tostring(err) .. '\n')
    vim.cmd('cquit 1')
else
    io.stdout:write('Setup stage ' .. stage .. ' done.\n')
    vim.cmd('qa!')
end
