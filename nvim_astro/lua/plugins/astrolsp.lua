-- AstroLSP — фичи LSP, форматирование, маппинги при attach,
-- per-server конфиги и handler-ы.
-- Документация: `:h astrolsp`.
-- NOTE: рекомендуется поставить lua-language-server (`:LspInstall lua_ls`),
--       чтобы автокомплит и хинты работали прямо в этом файле.

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      codelens = true,
      inlay_hints = false, -- включи true, если хочешь inline-хинты типов
      semantic_tokens = true,
    },

    -- Форматирование при сохранении.
    formatting = {
      format_on_save = {
        enabled = true,
        allow_filetypes = {
          -- "go",
        },
        ignore_filetypes = {
          -- "python",
        },
      },
      disabled = {
        -- Отключить formatting capability у клиента (например, если хочешь
        -- форматить lua через stylua, а не lua_ls):
        -- "lua_ls",
      },
      timeout_ms = 1000,
    },

    -- LSP-сервера, которые уже стоят в системе (не через mason).
    servers = {
      -- "pyright",
    },

    -- Per-server конфиг (передаётся в vim.lsp.config).
    -- Клиент-специфичные настройки также можно класть в `lsp/<name>.lua`
    -- в корне конфига — см. `:h lsp-config`.
    config = {
      -- ["*"] = { capabilities = {} },

      -- Пример: расширенный rust-analyzer.
      -- rust_analyzer = {
      --   settings = {
      --     ["rust-analyzer"] = {
      --       cargo = { allFeatures = true },
      --       checkOnSave = { command = "clippy" },
      --     },
      --   },
      -- },
    },

    -- Кастомные handler-ы при подключении сервера.
    handlers = {
      -- ["*"] = function(server) vim.lsp.enable(server) end,
      -- rust_analyzer = false, -- false => не запускать этот сервер
    },

    -- Buffer-local автокоманды, навешиваемые при attach.
    autocmds = {
      lsp_codelens_refresh = {
        cond = "textDocument/codeLens",
        {
          event = { "InsertLeave", "BufEnter" },
          desc = "Refresh codelens (buffer)",
          callback = function(args)
            if require("astrolsp").config.features.codelens then
              vim.lsp.codelens.enable(true, { bufnr = args.buf })
            end
          end,
        },
      },
    },

    -- Маппинги, привязанные к LSP-буферу. `cond` может быть строкой
    -- (имя capability сервера) или функцией (client, bufnr) -> boolean.
    mappings = {
      n = {
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "Declaration of current symbol",
          cond = "textDocument/declaration",
        },
        ["<Leader>uY"] = {
          function() require("astrolsp.toggles").buffer_semantic_tokens() end,
          desc = "Toggle LSP semantic highlight (buffer)",
          cond = function(client)
            return client:supports_method "textDocument/semanticTokens/full"
              and vim.lsp.semantic_tokens ~= nil
          end,
        },
      },
    },

    -- Кастомный on_attach, выполняется ПОСЛЕ дефолтного.
    on_attach = function(client, bufnr) -- luacheck: ignore
      -- Пример: отключить semantic tokens для всех клиентов.
      -- client.server_capabilities.semanticTokensProvider = nil
    end,
  },
}
