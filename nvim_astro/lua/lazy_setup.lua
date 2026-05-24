require("lazy").setup({
  {
    "AstroNvim/AstroNvim",
    version = "^6", -- убери version, если хочешь nightly AstroNvim
    import = "astronvim.plugins",
    opts = {
      mapleader = " ",
      maplocalleader = ",",
      icons_enabled = true, -- ставь false, если нет Nerd Font
      pin_plugins = nil,
      update_notifications = true,
    },
  },
  { import = "community" },
  { import = "plugins" },
} --[[@as LazySpec]], {
  install = { colorscheme = { "astrodark", "habamax" } },
  ui = { backdrop = 100 },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "zipPlugin",
      },
    },
  },
} --[[@as LazyConfig]])
