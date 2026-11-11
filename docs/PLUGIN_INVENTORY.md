# Инвентарь плагинов — IDE-080, 2026-11-10

Обновление2026-11-11 после e00bcea: состав/pins те же67. Свежий plain text
profile Windows/Ubuntu загрузил45 plugins, installs0; первоначальный idle28
ниже — другая фаза. Актуальные решения после Files/Logs/pilot и6 plugin
backports/13 files — в начале [FEATURE_REVIEW](FEATURE_REVIEW.md).

Живой Lazy config и lock содержат одинаковые 67 имён. В idle тестовом снимке загружены 28, установок при запуске 0. Это инвентарь, а не benchmark старта. Оценки — предложения для review; рабочие плагины не удалялись.

Источник: .tests/feature-review-runtime.json, editor artifact 3322136536400. Команда: `<nvim> -l tests/diagnostics/inspect-plugins.lua`. Цена фич, доказательства и открытые вопросы — [FEATURE_REVIEW.md](FEATURE_REVIEW.md).

Уточнение review: `loaded`/pin не доказывают готовность native-компонента.
В проверенном Windows SDK fzf-native есть в Lazy, но DLL отсутствует; Ubuntu
исключает его условием cmake. Picker работает на fallback, ускорение не
подтверждено. Детали — IDE-081 в FEATURE_REVIEW; pins остаются прежними.

| Plugin | Роль | Оценка | Прямые dependencies | Pin |
|---|---|---|---|---|
| [Comment.nvim](https://github.com/numToStr/Comment.nvim.git) | Editor helpers | оценить штатные альтернативы без потери ввода | — | e30b7f2008e5 |
| [FixCursorHold.nvim](https://github.com/antoinemadec/FixCursorHold.nvim.git) | Tests и language adapters | ядро; dependency не отдельная фича | — | 1900f89dc17c |
| [LuaSnip](https://github.com/L3MON4D3/LuaSnip.git) | Completion и snippets | ядро ввода | friendly-snippets | 642b0c595e11 |
| [aerial.nvim](https://github.com/stevearc/aerial.nvim.git) | Outline | явно запрошено | nvim-treesitter, nvim-web-devicons | 645d108a5242 |
| [alpha-nvim](https://github.com/goolord/alpha-nvim.git) | Dashboard/recents | дополнительный workflow | nvim-web-devicons, persistence.nvim, project.nvim | 6c6a89d5b068 |
| [auto-save.nvim](https://github.com/okuuva/auto-save.nvim.git) | Autosave | политика редактирования, не косметика | — | 9aabcb839622 |
| [barbecue.nvim](https://github.com/utilyre/barbecue.nvim.git) | Breadcrumbs | кандидат для сравнения без этой фичи | nvim-navic, nvim-web-devicons | 3e31404f0b93 |
| [bufferline.nvim](https://github.com/akinsho/bufferline.nvim.git) | Файловые вкладки | ядро | nvim-web-devicons | 655133c3b4c3 |
| [catppuccin](https://github.com/catppuccin/nvim.git) | Theme/statusline/icons/indent | UX, не отдельный language backend | — | 426dbebe06b5 |
| [cmp-buffer](https://github.com/hrsh7th/cmp-buffer.git) | Completion и snippets | ядро ввода | — | b74fab3656ee |
| [cmp-cmdline](https://github.com/hrsh7th/cmp-cmdline.git) | Completion и snippets | ядро ввода | — | d126061b624e |
| [cmp-nvim-lsp](https://github.com/hrsh7th/cmp-nvim-lsp.git) | Completion и snippets | ядро ввода | — | cbc7b02bb99f |
| [cmp-nvim-lsp-signature-help](https://github.com/hrsh7th/cmp-nvim-lsp-signature-help.git) | Completion и snippets | ядро ввода | — | fd3e882e5695 |
| [cmp-path](https://github.com/hrsh7th/cmp-path.git) | Completion и snippets | ядро ввода | — | c642487086db |
| [cmp_luasnip](https://github.com/saadparwaiz1/cmp_luasnip.git) | Completion и snippets | ядро ввода | — | 98d9cb5c2c38 |
| [conform.nvim](https://github.com/stevearc/conform.nvim.git) | Format | ядро | — | dca1a190aa85 |
| [diffview.nvim](https://github.com/sindrets/diffview.nvim.git) | Git diff/история/merge | ядро, сверить границы с Neogit | nvim-web-devicons | 4516612fe98f |
| [edgy.nvim](https://github.com/folke/edgy.nvim.git) | Размещение панелей | ядро, проверить ownership с ide | — | 8bfd2808994a |
| [fidget.nvim](https://github.com/j-hui/fidget.nvim.git) | LSP progress | UX, проверить видимость/нагрузку | — | 889e2e96edef |
| [friendly-snippets](https://github.com/rafamadriz/friendly-snippets.git) | Completion и snippets | ядро ввода | — | 6cd7280adead |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim.git) | Git hunk signs/actions | ядро | — | dd3f588bacbe |
| [glance.nvim](https://github.com/dnlhc/glance.nvim.git) | Peek UI | кандидат на сокращение способов навигации | — | bf86d8b79dce |
| [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim.git) | Interactive поиск/замена | отдельная фича, оценить повседневную пользу | — | 21790e59dd01 |
| [indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim.git) | Theme/statusline/icons/indent | UX, не отдельный language backend | — | d28a3f70721c |
| [lazy.nvim](https://github.com/folke/lazy.nvim.git) | Plugin manager / библиотеки | техническая зависимость, не отдельная фича | — | 85c7ff3711b7 |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim.git) | Theme/statusline/icons/indent | UX, не отдельный language backend | catppuccin, nvim-web-devicons | 131a558e13f9 |
| [mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim.git) | LSP и setup | ядро / настройка инструментов | mason.nvim, nvim-lspconfig | 51feb0ada33d |
| [mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim.git) | LSP и setup | ядро / настройка инструментов | mason.nvim | 443f1ef8b5e6 |
| [mason.nvim](https://github.com/williamboman/mason.nvim.git) | LSP и setup | ядро / настройка инструментов | — | e54f5bf5f12c |
| [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim.git) | Дерево файлов | ядро | nui.nvim, nvim-web-devicons, plenary.nvim | 84c75e7a7e44 |
| [neodev.nvim](https://github.com/folke/neodev.nvim.git) | Разработка Lua-конфига | проверить необходимость вне шести рабочих языков | — | 46aa467dca16 |
| [neogit](https://github.com/NeogitOrg/neogit.git) | Git status/commit/ветки/worktree | ядро | diffview.nvim, plenary.nvim, telescope.nvim | d7bb91b42f98 |
| [neotest](https://github.com/nvim-neotest/neotest.git) | Tests и language adapters | ядро; dependency не отдельная фича | FixCursorHold.nvim, neotest-golang, neotest-jest, neotest-python, neotest-rust, nvim-nio, nvim-treesitter, plenary.nvim | 27bf92149804 |
| [neotest-golang](https://github.com/fredrikaverpil/neotest-golang.git) | Tests и language adapters | ядро; dependency не отдельная фича | — | 65b2be63c3de |
| [neotest-jest](https://github.com/nvim-neotest/neotest-jest.git) | Tests и language adapters | ядро; dependency не отдельная фича | — | 0e7979d51301 |
| [neotest-python](https://github.com/nvim-neotest/neotest-python.git) | Tests и language adapters | ядро; dependency не отдельная фича | — | e6df4f1892f6 |
| [neotest-rust](https://github.com/rouge8/neotest-rust.git) | Tests и language adapters | ядро; dependency не отдельная фича | — | 2c9941d4a358 |
| [nui.nvim](https://github.com/MunifTanjim/nui.nvim.git) | Plugin manager / библиотеки | техническая зависимость, не отдельная фича | — | de740991c124 |
| [nvim-autopairs](https://github.com/windwp/nvim-autopairs.git) | Editor helpers | оценить штатные альтернативы без потери ввода | — | 7b9923abad60 |
| [nvim-cmp](https://github.com/hrsh7th/nvim-cmp.git) | Completion и snippets | ядро ввода | LuaSnip, cmp-buffer, cmp-cmdline, cmp-nvim-lsp, cmp-nvim-lsp-signature-help, cmp-path, cmp_luasnip | a1d504892f2b |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap.git) | Debug protocol/UI/adapters | ядро; проверить цену собственного glue | nvim-dap-ui, nvim-dap-virtual-text, telescope-dap.nvim | 45a69eba683a |
| [nvim-dap-go](https://github.com/leoluz/nvim-dap-go.git) | Debug protocol/UI/adapters | ядро; проверить цену собственного glue | nvim-dap | b4421153ead5 |
| [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python.git) | Debug protocol/UI/adapters | ядро; проверить цену собственного glue | nvim-dap | 1808458eba2b |
| [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui.git) | Debug protocol/UI/adapters | ядро; проверить цену собственного glue | nvim-dap, nvim-nio | 1a66cabaa4a4 |
| [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text.git) | Debug protocol/UI/adapters | ядро; проверить цену собственного glue | — | fbdb48c2ed45 |
| [nvim-hlslens](https://github.com/kevinhwang91/nvim-hlslens.git) | Поисковые highlights/заметки | дополнительный UX | — | be2d7b2be018 |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig.git) | LSP и setup | ядро / настройка инструментов | cmp-nvim-lsp, mason.nvim | 451d4ef9abd4 |
| [nvim-navic](https://github.com/SmiteshP/nvim-navic.git) | Breadcrumbs | кандидат для сравнения без этой фичи | — | f5eba192f39b |
| [nvim-nio](https://github.com/nvim-neotest/nvim-nio.git) | Plugin manager / библиотеки | техническая зависимость, не отдельная фича | — | 21f5324bfac1 |
| [nvim-surround](https://github.com/kylechui/nvim-surround.git) | Editor helpers | оценить штатные альтернативы без потери ввода | — | 2e93e154de9f |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter.git) | Парсеры/структура текста | языковое ядро и keyboard navigation | nvim-treesitter-textobjects | 4916d6592ede |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects.git) | Парсеры/структура текста | языковое ядро и keyboard navigation | — | 851e865342e5 |
| [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons.git) | Theme/statusline/icons/indent | UX, не отдельный language backend | — | 2795c26c916b |
| [overseer.nvim](https://github.com/stevearc/overseer.nvim.git) | Tasks/run | ядро; не дублирует структурированные Tests | — | f818eefff81f |
| [persistence.nvim](https://github.com/folke/persistence.nvim.git) | Проекты/root и session restore | сверить реальные сценарии и пересечения | — | b20b2a7887bd |
| [plenary.nvim](https://github.com/nvim-lua/plenary.nvim.git) | Plugin manager / библиотеки | техническая зависимость, не отдельная фича | — | 74b06c6c75e4 |
| [project.nvim](https://github.com/ahmedkhalf/project.nvim.git) | Проекты/root и session restore | сверить реальные сценарии и пересечения | — | 8c6bad7d22ee |
| [satellite.nvim](https://github.com/lewis6991/satellite.nvim.git) | Overview ruler | дополнительный UI, оценить цену | — | 87843c9c8f28 |
| [telescope-dap.nvim](https://github.com/nvim-telescope/telescope-dap.nvim.git) | Debug protocol/UI/adapters | ядро; проверить цену собственного glue | — | 783366bd6c1e |
| [telescope-fzf-native.nvim](https://github.com/nvim-telescope/telescope-fzf-native.nvim.git) | Поиск и pickers | ядро; extensions отдельны от основного plugin | — | b25b749b9db6 |
| [telescope-ui-select.nvim](https://github.com/nvim-telescope/telescope-ui-select.nvim.git) | Поиск и pickers | ядро; extensions отдельны от основного plugin | — | 6e51d7da30bd |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim.git) | Поиск и pickers | ядро; extensions отдельны от основного plugin | nvim-web-devicons, plenary.nvim, telescope-fzf-native.nvim, telescope-ui-select.nvim | f04ab730b8f9 |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim.git) | Поисковые highlights/заметки | дополнительный UX | plenary.nvim | 31e3c38ce9b2 |
| [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim.git) | Терминал | ядро | — | 50ea089fc548 |
| [trouble.nvim](https://github.com/folke/trouble.nvim.git) | Problems/LSP/qf UI | ядро Problems; вторичные views пересмотреть | — | bd67efe408d4 |
| [vim-illuminate](https://github.com/RRethy/vim-illuminate.git) | Подсветка usages | отдельная фича; сохранить guards и E2E | — | 0d1e93684da0 |
| [which-key.nvim](https://github.com/folke/which-key.nvim.git) | Подсказки клавиш | ядро обнаружения команд | — | 3aab2147e748 |
