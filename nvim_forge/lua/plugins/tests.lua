-- Unit-test panel and runners for Rust / Go / Python.

local function nt()
    return require("neotest")
end

return {
    { "rouge8/neotest-rust", ft = "rust",
        commit = require('ide.backports').revision('neotest-rust'),
        build = function(plugin) require('ide.backports').run('neotest-rust', plugin.dir, 'apply') end },
    { "fredrikaverpil/neotest-golang", ft = "go", commit = "65b2be63c3de00e6f15c05388ebdc8d603dbd727" },
    { "nvim-neotest/neotest-python", ft = "python" },
    { 'nvim-neotest/neotest-jest', ft = { 'javascript', 'javascriptreact' }, commit = '0e7979d51301dfae5ef839d771bd28cf593fde3f' },

    {
        "nvim-neotest/neotest",
        commit = require('ide.backports').revision('neotest'),
        build = function(plugin) require('ide.backports').run('neotest', plugin.dir, 'apply') end,
        cmd = "Neotest",
        dependencies = {
            "nvim-neotest/nvim-nio",
            "nvim-lua/plenary.nvim",
            "antoinemadec/FixCursorHold.nvim",
            "nvim-treesitter/nvim-treesitter",
            "rouge8/neotest-rust",
            "fredrikaverpil/neotest-golang",
            "nvim-neotest/neotest-python",
            'nvim-neotest/neotest-jest',
        },
        keys = {
            { "<leader>Tp", function() require("ide").toggle("tests") end,     desc = "Tests: side panel" },
            -- Запуск тестов авто-открывает Test Output (ide/triggers.lua: test:run).
            { "<leader>Tt", function() nt().run.run(); require("ide").triggers.fire("test:run") end,                    desc = "Tests: run nearest" },
            { "<leader>Tf", function() nt().run.run(vim.fn.expand("%")); require("ide").triggers.fire("test:run") end,  desc = "Tests: run file" },
            { "<leader>TA", function() nt().forge_runner.all(); require("ide").triggers.fire("test:run") end,           desc = "Tests: run all" },
            { "<leader>Td", function() nt().run.run({ strategy = "dap" }) end, desc = "Tests: debug nearest" },
            { "<leader>Ts", function() nt().run.stop() end,                   desc = "Tests: stop" },
            { "<leader>Ta", function() nt().run.attach() end,                 desc = "Tests: attach" },
            { "<leader>To", function() nt().output.open({ enter = true }) end, desc = "Tests: output" },
            { "<leader>TO", function() require("ide").toggle("tests_output") end, desc = "Tests: output panel" },
            { "<leader>Tw", function() nt().watch.toggle(vim.fn.expand("%")) end, desc = "Tests: watch file" },
        },
        config = function()
            local adapters = {}

            local ok_rust, rust = pcall(require, "neotest-rust")
            if ok_rust then
                table.insert(adapters, rust({
                    args = { "--no-capture" },
                    dap_adapter = "codelldb",
                }))
            end

            local ok_go, go = pcall(require, "neotest-golang")
            if ok_go then
                table.insert(adapters, go({
                    -- spec: IDE-TEST-1/2 adapter формирует argv/nearest-фильтр.
                    -- JSON-файл исключает искажение результатов терминальным PTY.
                    runner = "gotestsum",
                    go_test_args = { "-v", "-count=1", "-timeout=60s" },
                    dap_mode = "manual",
                    -- Свежая таблица на запуск: adapter добавляет args/cwd.
                    dap_manual_config = function()
                        return { type = "go", name = "Debug Go test", request = "launch",
                            mode = "test", outputMode = "remote", args = { "-test.v" } }
                    end,
                }))
            end

            local ok_python, python = pcall(require, "neotest-python")
            if ok_python then
                table.insert(adapters, python({
                    dap = { justMyCode = false },
                    runner = "pytest",
                }))
            end

            local consumers = {}
            consumers.forge_runner = require('forge.test_runner')
            table.insert(adapters, require('forge.node').jest())
            table.insert(adapters, require('forge.bash').tests())
            table.insert(adapters, require('forge.sql_tests'))
            local ok_overseer, overseer_consumer = pcall(require, "neotest.consumers.overseer")
            if ok_overseer then
                consumers.overseer = overseer_consumer
            end

            require("neotest").setup({
                adapters = adapters,
                consumers = next(consumers) and consumers or nil,
                overseer = {
                    enabled = true,
                    force_default = false,
                },
                output = { open_on_run = false },
                quickfix = { open = false },
                summary = { mappings = { help = 'g?' } }, -- ? — общий panel help
            })

            -- То же правило, что и для LSP-диагностики (см. plugins/lsp.lua):
            -- текст упавшего теста не раскрывается сам и не раздвигает код.
            -- Остаются знак в gutter + подчёркивание; полный текст — по `gl`
            -- (оверлей показывает диагностику строки из ВСЕХ namespace'ов,
            -- включая neotest) либо в Test Output панели.
            local neotest_ns = vim.api.nvim_create_namespace("neotest")
            vim.diagnostic.config({
                virtual_text = false,
                virtual_lines = false,
            }, neotest_ns)
        end,
    },
}
