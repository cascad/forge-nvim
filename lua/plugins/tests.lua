-- Unit-test panel and runners for Rust / Go / Python.

local panels = require("config.panels")
local diagnostics = require("config.diagnostics")

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
            { "<leader>Tp", panels.toggle_tests,                              desc = "Tests: side panel" },
            { "<leader>Tt", function() nt().run.run() end,                    desc = "Tests: run nearest" },
            { "<leader>Tf", function() nt().run.run(vim.fn.expand("%")) end,  desc = "Tests: run file" },
            { "<leader>TA", function() nt().run.run(vim.fn.getcwd()) end,     desc = "Tests: run all" },
            { "<leader>Td", function() nt().run.run({ strategy = "dap" }) end, desc = "Tests: debug nearest" },
            { "<leader>Ts", function() nt().run.stop() end,                   desc = "Tests: stop" },
            { "<leader>Ta", function() nt().run.attach() end,                 desc = "Tests: attach" },
            { "<leader>To", function() nt().output.open({ enter = true }) end, desc = "Tests: output" },
            { "<leader>TO", panels.toggle_test_output,                        desc = "Tests: output panel" },
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

            local neotest_ns = vim.api.nvim_create_namespace("neotest")
            vim.diagnostic.config({
                virtual_text = false,
                virtual_lines = diagnostics.virtual_lines_current(),
            }, neotest_ns)
        end,
    },
}
