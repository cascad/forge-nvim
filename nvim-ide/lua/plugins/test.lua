-- Neotest — language-agnostic test runner UI.
-- Adapters per language; runs via real test binaries with structured output.

return {
    {
        "nvim-neotest/neotest",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "antoinemadec/FixCursorHold.nvim",
            "nvim-neotest/nvim-nio",
            "nvim-treesitter/nvim-treesitter",
            "rouge8/neotest-rust",
            "nvim-neotest/neotest-go",
            "nvim-neotest/neotest-python",
        },
        keys = {
            { "<leader>rt", function() require("neotest").run.run() end,                              desc = "Test: run nearest" },
            { "<leader>rf", function() require("neotest").run.run(vim.fn.expand("%")) end,            desc = "Test: run file" },
            { "<leader>rs", function() require("neotest").run.run(vim.fn.getcwd()) end,               desc = "Test: run suite" },
            { "<leader>rl", function() require("neotest").run.run_last() end,                         desc = "Test: run last" },
            { "<leader>rd", function() require("neotest").run.run({ strategy = "dap" }) end,          desc = "Test: debug nearest" },
            { "<leader>rk", function() require("neotest").run.stop() end,                             desc = "Test: stop" },
            { "<leader>ra", function() require("neotest").run.attach() end,                           desc = "Test: attach" },
            { "<leader>rS", function() require("neotest").summary.toggle() end,                       desc = "Test: summary toggle" },
            { "<leader>ro", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Test: output (float)" },
            { "<leader>rO", function() require("neotest").output_panel.toggle() end,                  desc = "Test: output panel" },
            { "]r",         function() require("neotest").jump.next({ status = "failed" }) end,       desc = "Test: next failed" },
            { "[r",         function() require("neotest").jump.prev({ status = "failed" }) end,       desc = "Test: prev failed" },
        },
        config = function()
            require("neotest").setup({
                adapters = {
                    require("neotest-rust"),
                    require("neotest-go"),
                    require("neotest-python")({
                        dap = { justMyCode = false },
                        runner = "pytest",
                    }),
                },
                output = { open_on_run = false },
                quickfix = { open = false },
                status = { virtual_text = true, signs = true },
                summary = {
                    animated = false,
                    mappings = {
                        expand     = { "<CR>", "<2-LeftMouse>" },
                        expand_all = "e",
                        run        = "r",
                        output     = "o",
                        stop       = "u",
                        attach     = "a",
                        jumpto     = "i",
                        mark       = "m",
                        target     = "t",
                    },
                },
                icons = {
                    failed       = "",
                    passed       = "",
                    running      = "",
                    running_animated = { "/", "|", "\\", "-" },
                    skipped      = "○",
                    unknown      = "?",
                    watching     = "",
                },
            })
        end,
    },
}
