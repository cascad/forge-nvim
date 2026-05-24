-- Точка расширения: сюда (или в новый файл в этой же папке `plugins/`)
-- кладутся пользовательские плагины и переопределения дефолтных.
-- Каждый LazySpec-элемент — отдельный плагин или override существующего.
--
-- Примеры закомментированы. Раскомментируй то, что нужно, или пиши своё.

---@type LazySpec
return {
  -- ===== Добавление новых плагинов =====
  --
  -- {
  --   "ray-x/lsp_signature.nvim",
  --   event = "BufRead",
  --   config = function() require("lsp_signature").setup() end,
  -- },
  --
  -- "andweeb/presence.nvim",

  -- ===== Переопределение дефолтных плагинов AstroNvim =====
  --
  -- Кастомизация dashboard (snacks.nvim) — заголовок:
  -- {
  --   "folke/snacks.nvim",
  --   opts = {
  --     dashboard = {
  --       preset = {
  --         header = table.concat({
  --           " █████  ███████ ████████ ██████   ██████ ",
  --           "██   ██ ██         ██    ██   ██ ██    ██",
  --           "███████ ███████    ██    ██████  ██    ██",
  --           "██   ██      ██    ██    ██   ██ ██    ██",
  --           "██   ██ ███████    ██    ██   ██  ██████ ",
  --           "",
  --           "███    ██ ██    ██ ██ ███    ███",
  --           "████   ██ ██    ██ ██ ████  ████",
  --           "██ ██  ██ ██    ██ ██ ██ ████ ██",
  --           "██  ██ ██  ██  ██  ██ ██  ██  ██",
  --           "██   ████   ████   ██ ██      ██",
  --         }, "\n"),
  --       },
  --     },
  --   },
  -- },

  -- ===== Отключение дефолтного плагина =====
  --
  -- { "max397574/better-escape.nvim", enabled = false },

  -- ===== Расширение настройки уже подключённого плагина =====
  --
  -- Дополнить дефолтный config, не перетирая его целиком:
  -- {
  --   "L3MON4D3/LuaSnip",
  --   config = function(plugin, opts)
  --     local luasnip = require "luasnip"
  --     luasnip.filetype_extend("javascript", { "javascriptreact" })
  --     require "astronvim.plugins.configs.luasnip" (plugin, opts)
  --   end,
  -- },
}
