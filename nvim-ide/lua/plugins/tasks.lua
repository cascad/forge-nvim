-- Overseer — task runner. Wraps :make, npm scripts, cargo, go test, ...
-- Templates auto-detected per project type.

return {
    {
        "stevearc/overseer.nvim",
        cmd = {
            "OverseerOpen", "OverseerClose", "OverseerToggle", "OverseerRun",
            "OverseerInfo", "OverseerBuild", "OverseerQuickAction", "OverseerTaskAction",
        },
        keys = {
            { "<leader>rr", "<cmd>OverseerRun<CR>",           desc = "Task: run" },
            { "<leader>rT", "<cmd>OverseerToggle<CR>",        desc = "Task: toggle list" },
            { "<leader>rb", "<cmd>OverseerBuild<CR>",         desc = "Task: build" },
            { "<leader>rA", "<cmd>OverseerQuickAction<CR>",   desc = "Task: action on last" },
            { "<leader>rI", "<cmd>OverseerInfo<CR>",          desc = "Task: info" },
        },
        opts = {
            strategy = "terminal",
            templates = { "builtin", "user" },
            task_list = {
                direction = "bottom",
                bindings = {
                    ["?"] = "ShowHelp",
                    ["<CR>"] = "RunAction",
                    ["<C-e>"] = "Edit",
                    ["o"] = "Open",
                    ["<C-v>"] = "OpenVsplit",
                    ["<C-s>"] = "OpenSplit",
                    ["<C-q>"] = "OpenQuickFix",
                    ["p"] = "TogglePreview",
                    ["<C-l>"] = "IncreaseDetail",
                    ["<C-h>"] = "DecreaseDetail",
                    ["L"] = "IncreaseAllDetail",
                    ["H"] = "DecreaseAllDetail",
                    ["["] = "DecreaseWidth",
                    ["]"] = "IncreaseWidth",
                    ["{"] = "PrevTask",
                    ["}"] = "NextTask",
                },
            },
            component_aliases = {
                default = {
                    "display_duration",
                    "on_output_summarize",
                    "on_exit_set_status",
                    "on_complete_notify",
                    { "on_complete_dispose", timeout = 300 },
                },
            },
        },
    },
}
