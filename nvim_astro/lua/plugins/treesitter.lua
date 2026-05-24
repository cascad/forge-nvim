-- Treesitter в AstroNvim v5+ настраивается через astrocore.treesitter
-- (см. lua/plugins/astrocore.lua), потому что nvim-treesitter теперь
-- только утилита для скачивания парсеров. Этот файл оставлен как
-- стандартный override-слот: тут можно дополнительно расширять
-- ensure_installed, не трогая основной astrocore.

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      -- Дополнительные парсеры. Список из astrocore.lua + всё, что добавишь здесь.
      ensure_installed = {
        -- "html",
        -- "css",
        -- "tsx",
        -- "javascript",
        -- "typescript",
      },
    },
  },
}
