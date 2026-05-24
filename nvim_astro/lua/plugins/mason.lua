-- Кастомизация Mason: список инструментов, которые должны быть
-- установлены автоматически при первом запуске (через mason-tool-installer).
--
-- Имена пакетов смотри в `:Mason` или на https://mason-registry.dev.
-- Большую часть нужного уже подтягивают astrocommunity language packs
-- из lua/community.lua — здесь только то, чего там нет, либо то, что
-- мы хотим иметь гарантированно вне зависимости от паков.

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        -- LSP
        "lua-language-server",

        -- Formatters / linters
        "stylua",

        -- Debug adapters
        "debugpy",

        -- Прочее
        "tree-sitter-cli",
      },
    },
  },
}
