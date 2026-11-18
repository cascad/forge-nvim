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
        io.stdout:write('Setup SDK selection: '..vim.json.encode(require('forge.setup_sdks').prepare())..'\n')
        -- Explicit tools-only choice; apply before Mason captures its environment.
        local policy=vim.env.FRIDE_SETUP_GO_TOOLCHAIN or 'local'
        assert(policy=='local' or policy=='auto','Invalid FRIDE_SETUP_GO_TOOLCHAIN: '..policy)
        local process=package.loaded['mason-core.process']
        if process then
            local captured
            for _,entry in ipairs(process.graft_env({})) do
                if entry:sub(1,12)=='GOTOOLCHAIN=' then captured=entry:sub(13) end
            end
            assert(captured==policy,
                'Go build policy must be applied before Mason initialization; rerun explicit setup.')
        end
        vim.env.GOTOOLCHAIN = policy
        vim.env.RUSTUP_AUTO_INSTALL = '0'
        io.stdout:write('Go build toolchain policy: '..policy..' (project SDK unchanged)\n')
        vim.cmd('Lazy load mason-tool-installer.nvim')
        local catalog = require('forge.tool_catalog')
        if vim.tbl_contains(catalog.mason(),'rust-analyzer') then
            io.stdout:write('Rust test tool readiness: '..vim.json.encode(require('forge.nextest').check())..'\n')
        end
        local readiness = require('forge.setup_readiness')
        local external = require('forge.setup_tools')
        local plan = external.plan(catalog.mason())
        local version_policy=catalog.install_policy()
        local version_options={preserve_versions=version_policy=='preserve'}
        io.stdout:write('IDE tool versions: '..version_policy..'\n')
        io.stdout:write('External IDE tools: '..vim.json.encode(plan.external)..'\n')
        readiness.build_sdks(plan.mason, catalog.versions(),version_options)
        local native = require('forge.native_tools')
        -- An explicitly supplied old bundle may include additional SQL tools.
        -- A basic SQL selection does not require that bundle.
        if native.owned('sqls') or native.owned('forge-sqltest') then
            io.stdout:write('SQL native readiness: '..vim.json.encode(native.check_sql())..'\n')
        end
        if #plan.mason>0 then vim.cmd('MasonToolsInstallSync') end
        local report = readiness.tools(plan.mason, catalog.versions(),version_options)
        report.external=external.check(plan.external).external
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
