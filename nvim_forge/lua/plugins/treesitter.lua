-- Treesitter for Neovim 0.12+.
--
-- nvim-treesitter `master` is archived for Neovim 0.11 compatibility and is
-- known to crash on Neovim 0.12 markdown injections with:
--   attempt to call method 'range' (a nil value)
--
-- The normal path is the rewritten `main` branch. The legacy branch below is a
-- compatibility bridge for machines that have not run Lazy sync yet.

local languages = {
    "rust", "go", "gomod", "gosum", "gowork",
    "python",
    "lua", "luadoc", "luap",
    "vim", "vimdoc", "query",
    "markdown", "markdown_inline",
    "json", "yaml", "toml",
    "bash", "regex",
    "c", "cpp", "cmake",
    "html", "css", "javascript", "typescript",
    "diff", "git_config", "gitcommit", "gitignore", "gitattributes",
    "dockerfile",
}

local ignored_filetypes = {
    [""] = true,
    alpha = true,
    dashboard = true,
    ["neo-tree"] = true,
    ["dap-repl"] = true,
    ["dap-view"] = true,
    ["dap-view-term"] = true,
    ["OverseerList"] = true,
    qf = true,
    help = true,
    man = true,
    aerial = true,
}

local function slow_rust_file(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(bufnr)
    local is_rust = vim.bo[bufnr].filetype == "rust" or path:lower():match("%.rs$")
    if not is_rust then
        return false
    end

    local ok_external, rust_external = pcall(require, "config.rust_external")
    if ok_external and rust_external.mark(bufnr) then
        return true
    end

    local ok, lines = pcall(vim.api.nvim_buf_line_count, bufnr)
    return ok and lines > 2500
end

local function should_skip_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return true
    end
    if vim.bo[bufnr].buftype ~= "" then
        return true
    end
    if ignored_filetypes[vim.bo[bufnr].filetype] then
        return true
    end
    return slow_rust_file(bufnr)
end

local function ensure_tree_sitter_cli_on_path()
    if vim.fn.executable("tree-sitter") == 1 then
        return true
    end

    if vim.fn.has("win32") ~= 1 then
        return false
    end

    local localappdata = vim.env.LOCALAPPDATA
    if not localappdata or localappdata == "" then
        return false
    end

    local pattern = localappdata
        .. [[\Microsoft\WinGet\Packages\tree-sitter.tree-sitter-cli_*\tree-sitter.exe]]
    local matches = vim.fn.glob(pattern, false, true)
    local exe = matches and matches[1]
    if not exe or exe == "" then
        return false
    end

    vim.env.PATH = vim.fn.fnamemodify(exe, ":h") .. ";" .. vim.env.PATH
    return vim.fn.executable("tree-sitter") == 1
end

local function setup_textobjects()
    local ok, textobjects = pcall(require, "nvim-treesitter-textobjects")
    if ok and type(textobjects.setup) == "function" then
        textobjects.setup({
            select = { lookahead = true },
            move = { set_jumps = true },
        })
    end

    local function select_textobject(capture)
        return function()
            if should_skip_buffer(0) then return end
            local ok_select, select = pcall(require, "nvim-treesitter-textobjects.select")
            if ok_select then
                pcall(select.select_textobject, capture, "textobjects")
            end
        end
    end

    local function move_textobject(method, capture)
        return function()
            if should_skip_buffer(0) then return end
            local ok_move, move = pcall(require, "nvim-treesitter-textobjects.move")
            if ok_move and type(move[method]) == "function" then
                pcall(move[method], capture, "textobjects")
            end
        end
    end

    local function swap_textobject(method, capture)
        return function()
            if should_skip_buffer(0) then return end
            local ok_swap, swap = pcall(require, "nvim-treesitter-textobjects.swap")
            if ok_swap and type(swap[method]) == "function" then
                pcall(swap[method], capture)
            end
        end
    end

    vim.keymap.set({ "x", "o" }, "af", select_textobject("@function.outer"), { desc = "outer function" })
    vim.keymap.set({ "x", "o" }, "if", select_textobject("@function.inner"), { desc = "inner function" })
    vim.keymap.set({ "x", "o" }, "ac", select_textobject("@class.outer"),    { desc = "outer class" })
    vim.keymap.set({ "x", "o" }, "ic", select_textobject("@class.inner"),    { desc = "inner class" })
    vim.keymap.set({ "x", "o" }, "aa", select_textobject("@parameter.outer"), { desc = "outer parameter" })
    vim.keymap.set({ "x", "o" }, "ia", select_textobject("@parameter.inner"), { desc = "inner parameter" })
    vim.keymap.set({ "x", "o" }, "aC", select_textobject("@comment.outer"),  { desc = "comment" })

    vim.keymap.set({ "n", "x", "o" }, "]f", move_textobject("goto_next_start", "@function.outer"), { desc = "next function" })
    vim.keymap.set({ "n", "x", "o" }, "]c", move_textobject("goto_next_start", "@class.outer"),    { desc = "next class" })
    vim.keymap.set({ "n", "x", "o" }, "[f", move_textobject("goto_previous_start", "@function.outer"), { desc = "prev function" })
    vim.keymap.set({ "n", "x", "o" }, "[c", move_textobject("goto_previous_start", "@class.outer"),    { desc = "prev class" })

    vim.keymap.set("n", "<leader>cs", swap_textobject("swap_next", "@parameter.inner"),     { desc = "Swap next parameter" })
    vim.keymap.set("n", "<leader>cS", swap_textobject("swap_previous", "@parameter.inner"), { desc = "Swap previous parameter" })
end

local function setup_main()
    local ts = require("nvim-treesitter")
    ts.setup()
    pcall(vim.treesitter.language.register, "json", "jsonc")

    if type(ts.install) == "function" then
        vim.api.nvim_create_user_command("ForgeTreesitterInstall", function()
            ts.install(languages):wait(300000)
        end, { desc = "Install forge-nvim Treesitter parsers" })

        if ensure_tree_sitter_cli_on_path() then
            ts.install(languages)
        end
    end

    setup_textobjects()

    local function attach(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        if should_skip_buffer(bufnr) then
            pcall(vim.treesitter.stop, bufnr)
            return
        end

        local ok_start = pcall(vim.treesitter.start, bufnr)
        if not ok_start then
            return
        end

        if vim.bo[bufnr].filetype ~= "python" and type(ts.indentexpr) == "function" then
            vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end

    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitterStart", { clear = true }),
        callback = function(args)
            attach(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("UserTreesitterReattach", { clear = true }),
        callback = function(args)
            attach(args.buf)
        end,
    })

    local function apply_folds(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        if should_skip_buffer(bufnr) then
            vim.wo.foldmethod = "manual"
            vim.wo.foldexpr = "0"
            return
        end

        vim.wo.foldmethod = "expr"
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter", "FileType" }, {
        group = vim.api.nvim_create_augroup("UserTreesitterFolds", { clear = true }),
        callback = function(args)
            apply_folds(args.buf)
        end,
    })

    attach(0)
    apply_folds(0)
    vim.opt.foldenable = false
end

local function setup_legacy()
    -- Temporary bridge for an installed pre-0.12 nvim-treesitter checkout. The
    -- old markdown injection queries are the known crash source on Neovim 0.12,
    -- so markdown highlighting is disabled only in this legacy path.
    local ok_configs, configs = pcall(require, "nvim-treesitter.configs")
    if not ok_configs then
        return
    end

    local function legacy_disable(lang, bufnr)
        return lang == "markdown" or lang == "markdown_inline" or should_skip_buffer(bufnr)
    end

    configs.setup({
        ensure_installed = languages,
        auto_install = true,
        sync_install = false,
        highlight = {
            enable = true,
            disable = legacy_disable,
            additional_vim_regex_highlighting = false,
        },
        indent = {
            enable = true,
            disable = function(lang, bufnr)
                return lang == "python" or legacy_disable(lang, bufnr)
            end,
        },
        incremental_selection = {
            enable = true,
            keymaps = {
                init_selection    = "<S-A-k>",
                node_incremental  = "<S-A-k>",
                scope_incremental = "<S-A-l>",
                node_decremental  = "<S-A-j>",
            },
        },
        textobjects = {
            select = {
                enable = true,
                disable = legacy_disable,
                lookahead = true,
                keymaps = {
                    ["af"] = { query = "@function.outer", desc = "outer function" },
                    ["if"] = { query = "@function.inner", desc = "inner function" },
                    ["ac"] = { query = "@class.outer",    desc = "outer class" },
                    ["ic"] = { query = "@class.inner",    desc = "inner class" },
                    ["aa"] = { query = "@parameter.outer", desc = "outer parameter" },
                    ["ia"] = { query = "@parameter.inner", desc = "inner parameter" },
                    ["aC"] = { query = "@comment.outer",  desc = "comment" },
                },
            },
            move = {
                enable = true,
                disable = legacy_disable,
                set_jumps = true,
                goto_next_start = {
                    ["]f"] = { query = "@function.outer", desc = "next function" },
                    ["]c"] = { query = "@class.outer",    desc = "next class" },
                },
                goto_previous_start = {
                    ["[f"] = { query = "@function.outer", desc = "prev function" },
                    ["[c"] = { query = "@class.outer",    desc = "prev class" },
                },
            },
            swap = {
                enable = true,
                disable = legacy_disable,
                swap_next     = { ["<leader>cs"] = "@parameter.inner" },
                swap_previous = { ["<leader>cS"] = "@parameter.inner" },
            },
        },
    })

    vim.api.nvim_create_user_command("ForgeTreesitterInstall", function()
        vim.cmd("TSUpdate")
    end, { desc = "Install forge-nvim Treesitter parsers" })
end

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        dependencies = {
            { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
        },
        cmd = { "TSUpdate", "TSInstall", "TSInstallSync", "TSUninstall" },
        config = function()
            local ok, ts = pcall(require, "nvim-treesitter")
            if ok and type(ts.install) == "function" then
                setup_main()
            else
                setup_legacy()
            end
        end,
    },
}
