-- Bootstrap lazy.nvim and load all plugin specs from `lua/plugins/`.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local out = vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git", lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = { { import = "plugins" } },
    defaults = {
        lazy    = false,    -- explicit per-spec; safer for a curated setup
        version = false,    -- always latest commit on tracked branch
    },
    install = { colorscheme = { "tokyonight", "habamax" } },
    checker = { enabled = true, notify = false },
    change_detection = { enabled = true, notify = false },
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
                "netrwPlugin",  -- replaced by nvim-ide Explorer
            },
        },
    },
    ui = { border = "rounded" },
})
