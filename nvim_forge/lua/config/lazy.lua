-- Bootstrap lazy.nvim. Канонический сниппет из docs.
-- https://lazy.folke.io/installation

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    install = {
        -- Не пытаемся подцепить какую-то стороннюю тему до загрузки catppuccin.
        colorscheme = { "catppuccin", "habamax" },
    },
    checker = {
        -- Не дёргать update раз в час — раздражает. Только по запросу `:Lazy update`.
        enabled = false,
    },
    change_detection = {
        notify = false,
    },
    rocks = {
        -- luarocks/hererocks нам не нужен ни для одного плагина — иначе
        -- :checkhealth lazy ругается на отсутствующий luarocks.
        enabled = false,
    },
    performance = {
        rtp = {
            -- Глобально дисейблим встроенные плагины, которые мы не используем.
            -- Стартап ускоряется на 10–20мс, и в :checkhealth тише.
            disabled_plugins = {
                "gzip", "matchit", "matchparen", "netrwPlugin",
                "tarPlugin", "tohtml", "tutor", "zipPlugin",
            },
        },
    },
    ui = {
        border = "rounded",
    },
})

-- Глобальный шорткат на UI-инспектор плагинов
vim.keymap.set("n", "<leader>L", "<cmd>Lazy<CR>",  { desc = "Lazy UI" })
vim.keymap.set("n", "<leader>M", "<cmd>Mason<CR>", { desc = "Mason UI" })
