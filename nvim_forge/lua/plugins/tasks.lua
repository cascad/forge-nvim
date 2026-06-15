-- Task runner/job layer. Overseer owns build/run/test jobs and integrates
-- with nvim-dap preLaunchTask, so DAP configs do not shell out manually.

local function source_buffer()
    local launch_buf = vim.g.user_dap_launch_buf
    if type(launch_buf) == "number" and vim.api.nvim_buf_is_valid(launch_buf) then
        return launch_buf
    end
    return vim.api.nvim_get_current_buf()
end

local function cargo_root_from_path(path)
    local start = path and path ~= "" and path or vim.fn.getcwd()
    local cargo_toml = vim.fs.find("Cargo.toml", { upward = true, path = start })[1]
    return cargo_toml and vim.fs.dirname(cargo_toml) or start
end

local function cargo_root()
    local current = vim.api.nvim_buf_get_name(source_buffer())
    local start = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
    return cargo_root_from_path(start)
end

local function cwd_from_launch_config(launch_config)
    if type(launch_config) ~= "table" or type(launch_config.cwd) ~= "string" then
        return cargo_root()
    end

    local cwd = launch_config.cwd
    if cwd:find("${workspaceFolder}", 1, true) then
        cwd = cwd:gsub("%${workspaceFolder}", cargo_root())
    end
    if cwd:find("${", 1, true) then
        return cargo_root()
    end

    return cargo_root_from_path(vim.fs.normalize(cwd))
end

return {
    {
        "stevearc/overseer.nvim",
        lazy = false,
        cmd = {
            "OverseerOpen",
            "OverseerClose",
            "OverseerToggle",
            "OverseerRun",
            "OverseerShell",
            "OverseerTaskAction",
        },
        keys = {
            { "<leader>jj", function() require("ide").apply_layout("jobs") end,  desc = "Jobs: panel" },
            -- Запуск задачи/сборки авто-открывает Tasks (ide/triggers.lua: task:run).
            { "<leader>jr", function() vim.cmd("OverseerRun"); require("ide").triggers.fire("task:run") end,   desc = "Jobs: run task" },
            { "<leader>jt", "<cmd>OverseerToggle bottom<CR>",   desc = "Jobs: toggle panel" },
            { "<leader>ja", "<cmd>OverseerTaskAction<CR>",      desc = "Jobs: task action" },
            { "<leader>js", function() vim.cmd("OverseerShell"); require("ide").triggers.fire("task:run") end, desc = "Jobs: shell task" },
        },
        opts = {
            dap = true,
            output = {
                use_terminal = true,
                preserve_output = false,
            },
            task_list = {
                direction = "bottom",
                min_height = 8,
                max_height = { 22, 0.25 },
                keymaps = {
                    ["q"] = { "<cmd>OverseerClose<CR>", desc = "Close task list" },
                },
            },
        },
        config = function(_, opts)
            local overseer = require("overseer")
            local vscode = require("overseer.vscode")
            overseer.setup(opts)

            overseer.register_template({
                name = "cargo build (debug)",
                builder = function(params)
                    local launch_config = params and params[vscode.LAUNCH_CONFIG_KEY]
                    local cwd = cwd_from_launch_config(launch_config)
                    return {
                        name = "cargo build (debug)",
                        cmd = { "cargo" },
                        args = { "build" },
                        cwd = cwd,
                        components = {
                            { "on_output_quickfix", open = false },
                            "on_exit_set_status",
                        },
                    }
                end,
            })
        end,
    },
}
