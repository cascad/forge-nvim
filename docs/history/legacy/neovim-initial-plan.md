# Neovim — план настройки и анализ стека

Цель: IDE для Rust / Go / Python с дебаггером, IDE-style go-to,
постоянными side-panel'ями и теми же Ctrl/Alt-биндингами VS Code,
которые уже зашиты в `..\settings.json` / `..\keybindings.json` и
`..\helix\config.toml`.

`README.md` — высокоуровневое «зачем». Этот файл — **что и в каком
порядке делаем**, плюс правки относительно того, что было намечено в
README на 2026.

---

## 1. Корректировки относительно README

| В README | Чем заменяется и почему |
|---|---|
| `ruff_lsp` | Просто `ruff` (через lspconfig). `ruff_lsp` заархивирован, LSP теперь встроен в `ruff server` |
| `rust_analyzer` через nvim-lspconfig | **Не настраивать** напрямую: `rustaceanvim` сам поднимает rust-analyzer. Двойная регистрация → два LSP-клиента на буфер |
| `pyright` | Оставляем (можно в любой момент сменить на `basedpyright` — drop-in) |
| `telescope-fzf-native` build = `make` | Build через **cmake** (Windows-friendly, у нас есть clang) |
| Только базовый набор | Добавлены под цель «IDE-feel»: `trouble.nvim`, `aerial.nvim`, `glance.nvim`, `fidget.nvim`, `vim-illuminate`, `nvim-navic` + `barbecue.nvim` |

**`codelldb` уже в PATH** (`%LocalAppData%\codelldb\adapter\codelldb.exe`)
→ rustaceanvim подхватит автоматически, mason его дополнительно ставить
**не будет** (исключаем из mason-tool-installer).

---

## 2. Стек (финальный)

### Ядро
- **Менеджер плагинов**: `lazy.nvim`
- **Tool-installer**: `mason.nvim` + `mason-lspconfig.nvim` + `WhoIsSethDaniel/mason-tool-installer.nvim`
- **LSP конфиги**: `nvim-lspconfig` + `folke/neodev.nvim` (для lua_ls в контексте Neovim API)

### LSP-серверы (mason ставит)
- `rust-analyzer` (через rustaceanvim)
- `gopls`
- `pyright`
- `ruff` (LSP + линтер + форматтер для Python)
- `lua-language-server`

### Completion
- `hrsh7th/nvim-cmp`
- `hrsh7th/cmp-nvim-lsp`, `cmp-buffer`, `cmp-path`, `cmp-cmdline`, `cmp-nvim-lsp-signature-help`
- `L3MON4D3/LuaSnip` + `saadparwaiz1/cmp_luasnip` + `rafamadriz/friendly-snippets`

### Treesitter
- `nvim-treesitter/nvim-treesitter` (rust, go, python, lua, vim, vimdoc, markdown, json, toml, yaml, bash)
- `nvim-treesitter/nvim-treesitter-textobjects`

### Поиск / навигация
- `nvim-telescope/telescope.nvim`
- `nvim-telescope/telescope-fzf-native.nvim` (cmake build)
- `nvim-neo-tree/neo-tree.nvim` + nui + plenary + nvim-web-devicons

### Дебаггер
- `mfussenegger/nvim-dap`
- `rcarriga/nvim-dap-ui` + `nvim-neotest/nvim-nio`
- `theHamsta/nvim-dap-virtual-text`
- `mrcjkb/rustaceanvim` (Rust LSP+DAP в одном)
- `leoluz/nvim-dap-go`
- `mfussenegger/nvim-dap-python`

### Форматтер / линтер
- `stevearc/conform.nvim` (rustfmt, gofumpt+goimports, ruff_format+ruff_organize_imports, stylua)

### IDE-feel
- `folke/trouble.nvim` — постоянная панель Problems / References / Quickfix
- `stevearc/aerial.nvim` — outline текущего файла (Structure window)
- `dnlhc/glance.nvim` — peek definition / references / implementations
- `j-hui/fidget.nvim` — индикатор LSP-progress («rust-analyzer indexing…»)
- `RRethy/vim-illuminate` — подсветка всех вхождений символа под курсором
- `SmiteshP/nvim-navic` + `utilyre/barbecue.nvim` — breadcrumbs

### Git
- `lewis6991/gitsigns.nvim`

### UI
- `folke/which-key.nvim`
- `nvim-lualine/lualine.nvim`
- `akinsho/bufferline.nvim` (VS Code-style табы)
- `catppuccin/nvim` (тема, контрастная подсветка fuzzy-матчей)
- `nvim-tree/nvim-web-devicons`

### Editor mechanics
- `windwp/nvim-autopairs`
- `kylechui/nvim-surround`
- `numToStr/Comment.nvim`
- `folke/persistence.nvim` (сессии)
- `okuuva/auto-save.nvim` (autosave 200ms — то же поведение, что в `settings.json`)

---

## 3. Структура файлов

```
F:\claude_code\vim\nvim\
├── README.md           ← общий «зачем» (был раньше)
├── PLAN.md             ← этот файл
├── INSTALL_WINDOWS.md  ← winget-команды + симлинк
├── QUICKSTART.md       ← шпаргалка биндингов
├── .gitignore
├── init.lua
└── lua\
    ├── config\
    │   ├── options.lua
    │   ├── keymaps.lua
    │   └── lazy.lua
    └── plugins\
        ├── lsp.lua
        ├── completion.lua
        ├── telescope.lua
        ├── neo-tree.lua
        ├── dap.lua
        ├── treesitter.lua
        ├── format.lua
        ├── git.lua
        ├── ide.lua
        ├── ui.lua
        └── editor.lua
```

---

## 4. Что переезжает из VS Code / Helix 1:1

Источник | Что | Куда в Neovim
---|---|---
`settings.json` `files.autoSaveDelay: 200` | Autosave 200мс | `auto-save.nvim`, condition по `vim.bo.modified`
`settings.json` `editor.cursorSurroundingLines: 999` | Курсор по центру | `vim.opt.scrolloff = 999`
`settings.json` `editor.formatOnSave: true` | Format on save | `conform.nvim` `format_on_save = { lsp_fallback = true, timeout_ms = 500 }`
`settings.json` `vim.handleKeys: <C-*>: false` | Ctrl-биндинги работают как в Windows | `lua/config/keymaps.lua`, секция «VS Code Ctrl»
`settings.json` `editor.suggest.insertMode: replace` | Replace вместо insert | `nvim-cmp` `confirm({ select = true, behavior = ConfirmBehavior.Replace })`
`settings.json` `[go] formatOnSave + organizeImports` | Go: фмт + импорты | `conform.nvim` formatters_by_ft `go = { "goimports", "gofumpt" }`
`settings.json` `rust-analyzer.check.command: clippy` | Clippy on save | `rustaceanvim` `server.default_settings.['rust-analyzer'].check.command = "clippy"`
`keybindings.json` Ctrl+J/K в suggest | next/prev в popup | `cmp` mapping `<C-j>` / `<C-k>` → `select_next/prev_item`
`keybindings.json` Shift+Alt+K/J | smart-select expand/shrink | `treesitter-textobjects` incremental_selection
`keybindings.json` Alt+[ / Alt+] | jumplist back/forward | `<A-[>` → `<C-o>`, `<A-]>` → `<C-i>`
`keybindings.json` Alt+J | reveal definition | `<A-j>` → `vim.lsp.buf.definition`
`keybindings.json` Alt+Win+L | format document | `<S-A-f>` → `conform.format()` (Win-key в TUI ловится плохо, переезжает на Shift+Alt+F)
`keybindings.json` Ctrl+Enter | run selection in terminal | `<C-CR>` в visual: `:'<,'>w !pwsh`
`helix` Space-leader (f/l/d/g/w/B/T) | Тот же набор leader-маршрутов | `which-key` секции

---

## 5. Порядок выполнения (slice-by-slice)

Каждый шаг → `:checkhealth` → git commit. Откатываемся точечно при поломке.

1. **Инфраструктура**: `init.lua` + `config/lazy.lua` + `config/options.lua` + `config/keymaps.lua`. Запуск без плагинов. `:checkhealth` зелёный.
2. **Mason + LSP**: `plugins/lsp.lua` с `lua_ls` only. Открыть сам конфиг — `gd`, hover, diagnostics на Lua.
3. **Языки**: добавить `gopls`, `pyright`, `ruff`, `rustaceanvim`. Открыть реальный проект каждого языка → проверить go-to.
4. **Completion**: `plugins/completion.lua`. Проверить `<C-Space>`, Tab, snippet-расширение.
5. **Treesitter**: `plugins/treesitter.lua`. Подсветка, `<S-A-K/J>` incremental select.
6. **Навигация**: `plugins/telescope.lua` + `plugins/neo-tree.lua`. Ctrl+P, Space-f-g, дерево.
7. **DAP**: `plugins/dap.lua`. Поставить breakpoint в Rust/Go/Python, F5, увидеть UI с переменными.
8. **IDE-feel**: `plugins/ide.lua` (trouble, glance, aerial, fidget, illuminate, navic).
9. **Полировка**: `plugins/format.lua`, `git.lua`, `ui.lua`, `editor.lua`, тема, бренчмарки `:Lazy profile`.

---

## 6. Что не делаем (зафиксировано)

- Не используем готовые distro (LazyVim/Kickstart/NvChad).
- Не плодим плагины — каждый закрывает конкретную боль.
- Не VimScript — только Lua.
- Не настраиваем `rust_analyzer` через `nvim-lspconfig`, если стоит `rustaceanvim`.
- Не ставим `codelldb` через mason — он уже есть в PATH.
- Не пишем кастомный snippet engine — только `LuaSnip` + `friendly-snippets`.

---

## 7. Реалистичные ограничения (не лечатся)

| Ограничение | Workaround |
|---|---|
| Rust async-stack в codelldb беднее JetBrains | Параллельно держать RustRover для тяжёлой отладки async |
| Test-runner UI без «зелёных галочек в gutter» как в IDE | `neotest` даёт signs + список, привычка ломается, но работает |
| Refactoring уровня «Extract method» только в Rust (через rust-analyzer code actions); в Go/Python — слабо | Сложные рефакторинги — IDE / `:%s/.../.../gc` |
| `which-key` не показывает все возможные нажатия — только зарегистрированные | Регистрировать важные группы явно через `which-key.add()` |

---

## 8. Установка

См. `INSTALL_WINDOWS.md`. Кратко:

1. `winget install Neovim.Neovim BurntSushi.ripgrep.MSVC sharkdp.fd`
2. `mklink /D "%LocalAppData%\nvim" "F:\claude_code\vim\nvim"` (из admin cmd, **один раз**).
3. `nvim` → lazy.nvim сам забутстрапится → плагины поставятся.
4. `:Mason` → проверить, что зелёные галочки у gopls/pyright/ruff/rust-analyzer/debugpy/delve/gofumpt/goimports/stylua.
5. `:checkhealth` → smoke-test всех подсистем.

---

## 9. Ежедневная шпаргалка

См. `QUICKSTART.md`.
