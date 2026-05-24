-- AstroUI — colorscheme, highlight-оверрайды и иконки.
-- Документация: `:h astroui`

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    colorscheme = "astrodark",

    -- Точечные правки highlight-групп. Левая ветка `init` применяется
    -- ко всем темам, ветка с именем темы — только при её активации.
    highlights = {
      init = {
        -- Normal = { bg = "#000000" },
      },
      astrodark = {
        -- Normal = { bg = "#000000" },
      },
    },

    -- Кастомные иконки для статус-линии и пр.
    icons = {
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}
