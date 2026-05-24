# nvim_astro

Дефолтный и идиоматичный конфиг **AstroNvim v6** в отдельной папке —
для сравнения с основным `forge-nvim`-конфигом и постепенной донастройки.

Профиль ориентирован на разработчика **Rust / Go / Python**: language packs
из `astrocommunity` подключены сразу, всё остальное — ванильный AstroNvim.

## Структура

```
nvim_astro/
├── init.lua                     # bootstrap lazy.nvim
├── lua/
│   ├── lazy_setup.lua           # импорт AstroNvim + community + plugins
│   ├── community.lua            # language packs (rust, go, python, ...)
│   ├── polish.lua               # хук, запускающийся в самом конце
│   └── plugins/
│       ├── astrocore.lua        # vim options, mappings, treesitter, diagnostics
│       ├── astroui.lua          # colorscheme, highlight, icons
│       ├── astrolsp.lua         # LSP defaults, format-on-save, mappings
│       ├── mason.lua            # mason-tool-installer ensure_installed
│       ├── treesitter.lua       # override-слот для парсеров
│       ├── none-ls.lua          # доп. источники форматтеров/линтеров
│       └── user.lua             # пользовательские плагины и override-ы
├── .gitignore
└── README.md
```

Любой `*.lua` в `lua/plugins/` автоматически подхватывается lazy.nvim
через `{ import = "plugins" }` в `lazy_setup.lua`. Чтобы добавить плагин —
создай новый файл, возвращающий `LazySpec`-таблицу.

## Запуск, не трогая основной конфиг

Ничего никуда копировать или симлинкать не нужно. В корне репо лежит
обёртка **`nvim_astro.cmd`**, которая выставляет `XDG_CONFIG_HOME`
прямо на эту папку и поднимает `NVIM_APPNAME=nvim_astro` — только
на свой запуск, не трогая родительскую сессию.

### Windows (cmd / PowerShell / Windows Terminal) — рекомендуемый путь

```powershell
<repo-root>\nvim_astro.cmd
# либо просто из этой папки:
.\nvim_astro.cmd
# с аргументами и файлами:
.\nvim_astro.cmd C:\some\project
```

где `<repo-root>` — куда ты склонировал этот репозиторий.

Что происходит внутри:

- `setlocal` — переменные живут только до выхода из `cmd.exe`-обёртки.
- `XDG_CONFIG_HOME` = корень репо → Neovim ищет конфиг в подпапке `nvim_astro/`.
- `NVIM_APPNAME=nvim_astro` → Neovim добавляет суффикс к именам state-каталогов:

| Каталог | Путь |
| --- | --- |
| config | `<repo-root>\nvim_astro\` |
| data   | `%LOCALAPPDATA%\nvim_astro-data\` |
| state  | `%LOCALAPPDATA%\nvim_astro-data\` |
| cache  | `%TEMP%\nvim_astro\` |

Основной `nvim` (config = `%LOCALAPPDATA%\nvim`, data = `%LOCALAPPDATA%\nvim-data`)
и любая другая сборка через `NVIM_APPNAME` живут **в своих** каталогах
и физически не пересекаются с `nvim_astro`. Удалить всё ради этой
сборки = снести `%LOCALAPPDATA%\nvim_astro-data\` и `%TEMP%\nvim_astro\`.

PowerShell-алиас (необязательно):

```powershell
Set-Alias nva <repo-root>\nvim_astro.cmd
nva
```

### Полностью локальная изоляция (опционально)

Если хочется, чтобы и плагины, и mason, и сессии тоже жили **внутри**
папки `nvim_astro/` (и сборку можно было целиком удалить одним
`Remove-Item -Recurse`), есть вариант с переопределением всех XDG-путей.
Создаёшь рядом скрипт `nvim_astro_local.cmd`:

```bat
@echo off
setlocal
set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"

set "XDG_CONFIG_HOME=%REPO%"
set "XDG_DATA_HOME=%REPO%\nvim_astro\.local\share"
set "XDG_STATE_HOME=%REPO%\nvim_astro\.local\state"
set "XDG_CACHE_HOME=%REPO%\nvim_astro\.local\cache"
set "NVIM_APPNAME=nvim_astro"

nvim %*
endlocal
```

`NVIM_APPNAME` всё равно нужен, чтобы пути не сталкивались с тем, что
Neovim строит для `nvim` по умолчанию.

### Linux / macOS

Аналогичная однострочная обёртка — никакого копирования:

```bash
XDG_CONFIG_HOME="$(pwd)" NVIM_APPNAME=nvim_astro nvim "$@"
```

или скриптом `nvim_astro.sh` рядом с папкой:

```bash
#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
XDG_CONFIG_HOME="$DIR" NVIM_APPNAME=nvim_astro exec nvim "$@"
```

## Первый запуск

1. Запустить `..\nvim_astro.cmd` (см. выше) или эквивалент под Linux/macOS.
2. Lazy.nvim сам склонирует AstroNvim и все плагины, потом откроется
   окно `:Lazy`. Дождаться окончания установки.
3. Выйти и запустить заново.
4. Открыть `:Mason` — `mason-tool-installer` уже скачивает:
   - `lua-language-server`, `stylua`
   - `debugpy`, `tree-sitter-cli`
   - плюс инструменты из подключённых `astrocommunity.pack.*`.
5. Проверить состояние: `:checkhealth astrocore`, `:checkhealth astrolsp`,
   `:checkhealth mason`.

## Что подключено по умолчанию (astrocommunity packs)

В `lua/community.lua`:

- `pack.lua` — для самого конфига
- `pack.rust` — `rust-analyzer`, DAP, treesitter
- `pack.go` — `gopls`, `gofmt`/`goimports`, DAP
- `pack.python-ruff` — `pyright`/`basedpyright` + `ruff`
- `pack.json`, `pack.yaml`, `pack.toml`
- `pack.markdown`, `pack.bash`, `pack.docker`

Альтернативные colorscheme'ы и AI-плагины перечислены там же
закомментированными — можно включать построчно.

## Куда смотреть, что править

| Хочу… | Файл |
| --- | --- |
| Поменять опции vim (numbers, scrolloff, undofile, …) | `lua/plugins/astrocore.lua` → `opts.options.opt` |
| Сменить leader-клавишу | `lua/lazy_setup.lua` → AstroNvim `opts` |
| Добавить keymap | `lua/plugins/astrocore.lua` → `opts.mappings` |
| Сменить тему | `lua/plugins/astroui.lua` → `opts.colorscheme` |
| Включить inlay hints | `lua/plugins/astrolsp.lua` → `features.inlay_hints = true` |
| Выключить format-on-save для языка | `lua/plugins/astrolsp.lua` → `formatting.format_on_save.ignore_filetypes` |
| Подкрутить LSP-сервер (например, rust-analyzer) | `lua/plugins/astrolsp.lua` → `config.rust_analyzer = { settings = { … } }` |
| Поставить ещё инструмент через Mason | `lua/plugins/mason.lua` → `ensure_installed` |
| Добавить плагин | новый файл в `lua/plugins/`, либо запись в `user.lua` |
| Отключить дефолтный плагин AstroNvim | в `user.lua`: `{ "имя/плагин", enabled = false }` |
| Подключить готовый language pack / recipe | `lua/community.lua` |

## Полезные команды AstroNvim

- `:AstroChangelog` — что нового в AstroNvim.
- `:AstroUpdate` — обновить AstroNvim и плагины.
- `:AstroVersion` — версия AstroNvim.
- `:AstroReadme` — открыть README плагина под курсором.

## Источники

- AstroNvim docs: <https://docs.astronvim.com/>
- Template (источник дефолтов): <https://github.com/AstroNvim/template>
- AstroCommunity: <https://github.com/AstroNvim/astrocommunity>
