-- spec: IDE-BOOT-9 IDE-BOOT-15. Явная подготовка; native +command errors сами дают exit0.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
package.path = root .. '/lua/?.lua;' .. package.path
local stage = arg[1]
local ok, err = xpcall(function()
    if stage == 'plugins' then
        local backports = require('ide.backports')
        local directory = vim.fn.stdpath('data') .. '/lazy'
        local prepared, report = pcall(require('forge.plugin_setup').prepare, function()
            -- Known backports are tracked modifications. Native restore must
            -- see original files; unknown changes still fail closed.
            backports.all(directory, 'revert')
        end)
        -- A failed restore must not leave the previous kit's known patches
        -- reverted in the shared fride data directory. Preserve first error.
        local applied, apply_error = pcall(backports.all, directory, 'apply')
        if not prepared then
            error(tostring(report) .. (not applied and ('\nBackport restore: ' .. tostring(apply_error)) or ''), 0)
        end
        assert(applied, apply_error)
        io.stdout:write('Plugin readiness: ' .. vim.json.encode(report) .. '\n')
        local checked = backports.all(directory, 'check')
        io.stdout:write('Backports checked: ' .. vim.json.encode(checked) .. '\n')
    elseif stage == 'parsers' then
        local runtime = require('forge.parser_runtime')
        local report
        if runtime.site() then
            report = runtime.check(require('forge.tool_catalog').parsers())
        else
            vim.cmd('ForgeTreesitterInstall')
            report = require('forge.setup_readiness').parsers(require('forge.tool_catalog').parsers())
        end
        io.stdout:write('Parser readiness: ' .. vim.json.encode(report) .. '\n')
    elseif stage == 'tools' then
        -- Only this explicit setup process: never download a language SDK
        -- while building IDE tools through Mason's native Go/Cargo providers.
        vim.env.GOTOOLCHAIN = 'local'
        vim.env.RUSTUP_AUTO_INSTALL = '0'
        vim.cmd('Lazy load mason-tool-installer.nvim')
        local catalog = require('forge.tool_catalog')
        local readiness = require('forge.setup_readiness')
        readiness.build_sdks(catalog.mason(), catalog.versions())
        local profile = require('forge.install_profile')
        if profile.selected('sql') then
            io.stdout:write('SQL native readiness: '..vim.json.encode(require('forge.native_tools').check_sql())..'\n')
        end
        vim.cmd('MasonToolsInstallSync')
        if profile.selected('bash') then
            io.stdout:write('Bash debug patch: '..require('forge.bash_debug').prepare_installed()..'\n')
        end
        local report = readiness.tools(catalog.mason(), catalog.versions())
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
