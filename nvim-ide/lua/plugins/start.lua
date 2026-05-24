-- Start screen + project switching + session persistence.
-- Three tightly-coupled plugins kept in one file.

return {
    -- =========================================================
    -- project.nvim — detects project roots, tracks recents.
    -- =========================================================
    {
        "ahmedkhalf/project.nvim",
        main = "project_nvim",          -- module name differs from repo name
        event = "VeryLazy",
        dependencies = { "nvim-telescope/telescope.nvim" },
        keys = {
            { "<leader>op", "<cmd>Telescope projects<CR>", desc = "Open: recent project" },
        },
        opts = {
            detection_methods = { "lsp", "pattern" },
            patterns = {
                ".git", "Cargo.toml", "go.mod", "pyproject.toml",
                "package.json", "setup.py", ".project-root", "Makefile",
            },
            manual_mode  = false,
            show_hidden  = false,
            silent_chdir = true,
            scope_chdir  = "global",
            datapath     = vim.fn.stdpath("data"),
            exclude_dirs = {
                "~/.cargo/*", "~/.rustup/*", "*/.cargo/*", "*/.rustup/*",
                "*/rustlib/src/*", "~/.cache/*",
                "*/node_modules/*", "*/.venv/*", "*/venv/*",
                "*/__pycache__/*", "*/target/*",
            },
        },
        config = function(_, opts)
            require("project_nvim").setup(opts)

            -- Patch deprecated lsp.get_active_clients() → get_clients().
            local ok, project = pcall(require, "project_nvim.project")
            if ok and vim.lsp.get_clients then
                project.find_lsp_root = function()
                    local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
                    local clients = vim.lsp.get_clients({ bufnr = 0 })
                    if #clients == 0 then return nil end
                    local cfg = require("project_nvim.config")
                    for _, client in ipairs(clients) do
                        local fts = client.config.filetypes
                        if fts and vim.tbl_contains(fts, ft)
                           and not vim.tbl_contains(cfg.options.ignore_lsp, client.name) then
                            return client.config.root_dir, client.name
                        end
                    end
                end
            end

            local ok_t, telescope = pcall(require, "telescope")
            if ok_t then pcall(telescope.load_extension, "projects") end
        end,
    },

    -- =========================================================
    -- persistence — auto-save / restore session per cwd.
    -- =========================================================
    {
        "folke/persistence.nvim",
        event = "BufReadPre",
        opts = { branch = true, need = 1 },
        keys = {
            { "<leader>qs", function() require("persistence").load() end,                  desc = "Session: restore (cwd)" },
            { "<leader>qS", function() require("persistence").select() end,                desc = "Session: select" },
            { "<leader>ql", function() require("persistence").load({ last = true }) end,   desc = "Session: restore last" },
            { "<leader>qd", function() require("persistence").stop() end,                  desc = "Session: don't save" },
        },
    },

    -- =========================================================
    -- alpha-nvim — start screen. Minimal buttons, no custom plumbing.
    -- =========================================================
    {
        "goolord/alpha-nvim",
        event = "VimEnter",
        cmd = "Alpha",
        dependencies = {
            "ahmedkhalf/project.nvim",
            "folke/persistence.nvim",
            "nvim-telescope/telescope.nvim",
            "echasnovski/mini.icons",
        },
        keys = {
            { "<leader>oh", "<cmd>Alpha<CR>", desc = "Open: home (alpha)" },
        },
        config = function()
            local dashboard = require("alpha.themes.dashboard")

            dashboard.section.header.val = {
                "",
                "          N V I M  -  I D E         ",
                "",
            }

            dashboard.section.buttons.val = {
                dashboard.button("p", "  Recent projects",        "<cmd>Telescope projects<CR>"),
                dashboard.button("r", "  Restore session (cwd)",  "<cmd>lua require('persistence').load()<CR>"),
                dashboard.button("R", "  Restore last session",   "<cmd>lua require('persistence').load({ last = true })<CR>"),
                dashboard.button("f", "  Find file",              "<cmd>Telescope find_files<CR>"),
                dashboard.button("g", "  Live grep",              "<cmd>Telescope live_grep<CR>"),
                dashboard.button("o", "  Recent files",           "<cmd>Telescope oldfiles<CR>"),
                dashboard.button("e", "  New file",               "<cmd>enew<CR>"),
                dashboard.button("L", "  Lazy",                   "<cmd>Lazy<CR>"),
                dashboard.button("M", "  Mason",                  "<cmd>Mason<CR>"),
                dashboard.button("q", "  Quit",                   "<cmd>qa<CR>"),
            }

            dashboard.section.footer.val = "  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p:~")

            dashboard.config.opts.noautocmd = true
            require("alpha").setup(dashboard.config)
        end,
    },
}
