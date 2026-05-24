-- AstroCore — единая точка для опций vim, автокоманд, маппингов,
-- настроек treesitter и фичей AstroNvim.
-- Документация: `:h astrocore`

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },

    diagnostics = {
      virtual_text = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
    },

    -- Treesitter настраивается через astrocore (nvim-treesitter v1+).
    treesitter = {
      highlight = true,
      indent = true,
      auto_install = true,
      ensure_installed = {
        -- Базовое
        "lua",
        "vim",
        "vimdoc",
        "query",
        "regex",
        -- Целевые языки профиля
        "rust",
        "go",
        "gomod",
        "gosum",
        "python",
        -- Конфиги/данные
        "json",
        "jsonc",
        "yaml",
        "toml",
        "markdown",
        "markdown_inline",
        "bash",
        "dockerfile",
        "gitignore",
        "gitcommit",
        "diff",
      },
    },

    filetypes = {
      -- см. `:h vim.filetype.add`
      -- extension = { foo = "fooscript" },
    },

    options = {
      opt = {
        relativenumber = true,
        number = true,
        spell = false,
        signcolumn = "yes",
        wrap = false,
        scrolloff = 8,
        sidescrolloff = 8,
        cursorline = true,
        splitright = true,
        splitbelow = true,
        undofile = true,
        timeoutlen = 300,
        updatetime = 200,
      },
      g = {
        -- mapleader и maplocalleader выставляются в opts AstroNvim
        -- внутри lazy_setup.lua, здесь дублировать не нужно.
      },
    },

    -- Маппинги.
    -- Все mapping-таблицы дополняют дефолтные AstroNvim. Чтобы
    -- отключить дефолтный маппинг — присвой ему `false`.
    mappings = {
      n = {
        -- Навигация по буферам
        ["]b"] = {
          function() require("astrocore.buffer").nav(vim.v.count1) end,
          desc = "Next buffer",
        },
        ["[b"] = {
          function() require("astrocore.buffer").nav(-vim.v.count1) end,
          desc = "Previous buffer",
        },

        -- Закрыть буфер из tabline (через picker)
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- Группы для which-key (только описания, без действий)
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- Примеры отключения дефолтных маппингов:
        -- ["<C-s>"] = false,
      },
      t = {
        -- Выход из terminal mode по <C-/>
        -- ["<C-/>"] = { "<C-\\><C-n>", desc = "Leave terminal mode" },
      },
    },
  },
}
