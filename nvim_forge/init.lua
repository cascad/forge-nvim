-- Neovim entrypoint.
-- Put this repository at the Neovim config path:
--   Windows: %LOCALAPPDATA%\nvim
--   macOS/Linux: ${XDG_CONFIG_HOME:-$HOME/.config}/nvim
-- Further modules live in lua/config and lua/plugins.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Отключаем встроенные провайдеры, которые на Windows только тормозят
-- стартап и кричат в :checkhealth, если не установлены ruby/perl/python.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
-- Python provider тоже выключаем: debugpy ставится Mason'ом в свой
-- собственный venv (см. plugins\dap.lua → debugpy_python), внешний
-- pynvim ему не нужен. Provider нужен только legacy-плагинам на
-- VimScript+Python — таких у нас нет.
vim.g.loaded_python3_provider = 0

require("config.ru_keys").setup()
require("config.options")
require("config.keymaps")
require("config.lazy")

-- IDE-фреймворк: регистрирует компоненты (explorer/outline/dap/...) и
-- layout-пресеты, экспонирует API через require("ide"). См.
-- docs/PANELS_PLAN.md и lua/ide/init.lua.
--
-- Setup делается ПОСЛЕ lazy, потому что компоненты дёргают плагины
-- по требованию (через safe_require) — плагины должны быть в rtp.
-- Сам setup лёгкий: ничего не открывает, только регистрирует specs.
require("ide").setup()

-- Страж панелей: не даёт обычным файлам открываться в нижней/боковых
-- edgy-панелях (они строго для tool-окон) и лечит уже сохранённые
-- сломанные сессии, где файл «прилип» к панели. См. forge/panel_guard.lua.
require("forge.panel_guard").setup()
