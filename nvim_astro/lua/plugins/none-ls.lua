-- none-ls (форк null-ls) — мост для подключения форматтеров и линтеров,
-- не имеющих LSP, в общий LSP-интерфейс.
--
-- Список встроенных источников:
--   https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/formatting
--   https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
--
-- Большую часть форматтеров уже подключают astrocommunity packs из
-- lua/community.lua. Здесь — место для собственных источников.

---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    -- local null_ls = require "null-ls"
    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      -- null_ls.builtins.formatting.stylua,
      -- null_ls.builtins.formatting.prettier,
    })
  end,
}
