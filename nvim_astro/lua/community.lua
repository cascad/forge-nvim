-- AstroCommunity: готовые "language packs" и тематические модули.
-- Каждый pack под капотом подключает связку из LSP + Treesitter +
-- formatter/linter + (где применимо) DAP. Это идиоматичный способ
-- расширять AstroNvim — добавил строку и поехали.
--
-- Полный список:
--   https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity
--
-- Этот файл импортируется в `lazy_setup.lua` ДО папки `plugins/`, чтобы
-- пользовательские override-ы из `lua/plugins/*.lua` имели приоритет.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Базовые языки: Lua нужен для самого конфига.
  { import = "astrocommunity.pack.lua" },

  -- Целевой профиль forge-nvim: Rust / Go / Python.
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.python-ruff" }, -- ruff вместо pylint/black

  -- Данные, конфиги, скрипты — почти всегда нужны.
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.docker" },

  -- Полезные recipes из astrocommunity (по умолчанию выключены):
  -- { import = "astrocommunity.recipes.disable-tabline" },
  -- { import = "astrocommunity.recipes.disable-winbar" },

  -- Примеры альтернативных тем (по умолчанию остаётся astrodark из astroui.lua):
  -- { import = "astrocommunity.colorscheme.catppuccin" },
  -- { import = "astrocommunity.colorscheme.tokyonight-nvim" },
  -- { import = "astrocommunity.colorscheme.gruvbox-nvim" },

  -- AI / copilot — раскомментируй на свой вкус:
  -- { import = "astrocommunity.completion.copilot-lua-cmp" },

  -- Дополнительные DAP-инструменты, тестовые ранеры и т.п.:
  -- { import = "astrocommunity.test.neotest" },
  -- { import = "astrocommunity.debugging.nvim-dap-virtual-text" },
}
