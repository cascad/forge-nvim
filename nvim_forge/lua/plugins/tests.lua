-- Unit-test panel and runners for Rust / Go / Python.

local function nt()
    return require("neotest")
end

return {
    { "rouge8/neotest-rust", ft = "rust" },
    { "nvim-neotest/neotest-go", ft = "go" },
    { "nvim-neotest/neotest-python", ft = "python" },

    {
        "nvim-neotest/neotest",
        cmd = "Neotest",
        dependencies = {
            "nvim-neotest/nvim-nio",
            "nvim-lua/plenary.nvim",
            "antoinemadec/FixCursorHold.nvim",
            "nvim-treesitter/nvim-treesitter",
            "rouge8/neotest-rust",
            "nvim-neotest/neotest-go",
            "nvim-neotest/neotest-python",
        },
        keys = {
            { "<leader>Tp", function() require("ide").toggle("tests") end,     desc = "Tests: side panel" },
            -- Запуск тестов авто-открывает Test Output (ide/triggers.lua: test:run).
            { "<leader>Tt", function() nt().run.run(); require("ide").triggers.fire("test:run") end,                    desc = "Tests: run nearest" },
            { "<leader>Tf", function() nt().run.run(vim.fn.expand("%")); require("ide").triggers.fire("test:run") end,  desc = "Tests: run file" },
            { "<leader>TA", function() nt().run.run(vim.fn.getcwd()); require("ide").triggers.fire("test:run") end,     desc = "Tests: run all" },
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

            local ok_go, go = pcall(require, "neotest-go")
            if ok_go then
                table.insert(adapters, go({
                    experimental = { test_table = true },
                    recursive_run = true,
                    args = { "-count=1", "-timeout=60s" },
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
