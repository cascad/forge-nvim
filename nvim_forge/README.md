# forge-nvim

Portable Neovim IDE config for Rust, Go and Python.

IDE-138: [состав Default/Custom и прогресс установки одной командой](../docs/INSTALLATION_PLAN.md).
Root install.ps1/install.sh поддерживают Default/Custom с клавиатуры, но пока
остаются development entry; полный автоматический
setup на чистой системе ещё не завершён. Существующие способы запуска ниже.
Root entry ставит независимый комплект с командой forge и отдельными данными;
он не запускает global package managers и не заменяет существующий nvim.
Старые direct platform installers ниже — legacy system API, не новый safe entry.

Debug Output: `Space w c` / `Space D c` возвращают последний канал с историей;
`Space m d` открывает Debug View. F5 использует канал конфигурации, повторное
открытие PTY сохраняет буфер. Подробности — [QUICKSTART](QUICKSTART.md).
`Space du` скрывает/возвращает всю группу Debug, включая PTY; normal `q`
скрывает текущий компонент. Оба действия сохраняют сессию и полученный вывод.
Скрытый Debug остаётся скрытым до ручного открытия или нового breakpoint;
новая настоящая остановка возвращает панели с актуальными Locals и тем же PTY.

This is one of several configs living in this repository. See the root
`README.md` for the full layout and how the launchers isolate state.

Общее управление панелями: `Space w t/r/f/b` — Tests / Test Output / Search /
Tasks, `Space w h/j/k/l` — фокус, `Space w 0` — код. В панели normal `q` —
скрыть, `?` — помощь, `Esc` — вернуть zoom/фокус в код; `Space w z` — zoom.
Полная [шпаргалка](QUICKSTART.md#общий-маршрут-рабочих-панелей--space-w) и
[справочник клавиш](KEYBINDINGS.md#5-windows--focus).

## Run locally (no install)

Из корня репозитория:

**Windows**

```powershell
powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download
.\nvim_forge.cmd
```

Явная подготовка требует Git, CMake/Ninja и MSVC C++ Build Tools. Временный
Windows SDK исправляет native ConPTY crash IDE-027; хранится в
`.tools/neovim/windows-x64`. Launcher проверяет source/patch/binary hash,
при missing/stale SDK показывает команду подготовки. На старте SDK не
скачивается/собирается. Системный `nvim` не меняется; прямой `nvim` по-прежнему
запускает системную программу. Подробности: `tests/diagnostics/README.md`.

После обновления checkout подготовь **все** объявленные plugin backports,
а не выборочный список. Если версия установленного плагина отличается от
lazy-lock.json, сначала выполни в Forge `:Lazy restore`, дождись завершения
и закрой редактор. Затем из корня репозитория:

```powershell
.\nvim_forge.cmd -l .\nvim_forge\scripts\prepare-plugins.lua
.\nvim_forge.cmd -l .\nvim_forge\scripts\prepare-plugins.lua --check
```

Обе команды используют тот же Windows SDK/NVIM_APPNAME и установленный Lazy
профиль, что обычный launcher. Первая явно применяет все декларации, вторая
только проверяет. Сейчас это6 plugins/16 файлов; список берётся из metadata.
После подготовки запусти Forge заново в каталоге проекта. Неизвестные ревизии
и пользовательские изменения applier сохраняет и отклоняет.
На Linux/macOS те же команды: `./nvim_forge.sh -l
nvim_forge/scripts/prepare-plugins.lua` и повтор с `--check` (в одной строке).

**macOS** — один скрипт ставит всё (зависимости, шрифт, WezTerm и его
конфиг) и проверяет результат; повторный запуск безопасен и чинит то, что
разъехалось:

```bash
./nvim_forge/scripts/install-macos.sh
./nvim_forge.sh
./nvim_forge.sh path/to/file # с файлом
```

**Linux**

```bash
chmod +x nvim_forge.sh       # если exec-бит потерялся
./nvim_forge.sh
```

WezTerm на Linux подключается симлинком — из корня репо:

```bash
mkdir -p ~/.config/wezterm && ln -sf "$PWD/wezterm.lua" ~/.config/wezterm/wezterm.lua
```

или `FORGE_NVIM_DEPS_ONLY=1 ./nvim_forge/scripts/install-linux.sh` (в
GUI-сессии): путь, уже ведущий в репо, он не трогает и внутри чекаута ничего
не создаёт. `~/.wezterm.lua` и переменная `WEZTERM_CONFIG_FILE` на Linux
перекрывают симлинк молча — установщик их не трогает, убери руками.

Обе обёртки делают одно и то же: ставят `NVIM_APPNAME=nvim_forge` и
`XDG_CONFIG_HOME` на корень репо, после чего запускают Neovim: проверенный
локальный SDK Windows либо официальный `nvim` из PATH на POSIX. Переменные
живут только до выхода из nvim, родительский shell их не видит.
Каталоги:

| OS       | data / state / cache                                                                          |
|----------|-----------------------------------------------------------------------------------------------|
| Windows  | `%LOCALAPPDATA%\nvim_forge-data\`, `%TEMP%\nvim_forge\`                                       |
| Linux    | `~/.local/share/nvim_forge/`, `~/.local/state/nvim_forge/`, `~/.cache/nvim_forge/`            |
| macOS    | то же что Linux (XDG paths)                                                                   |

Это означает, что плагины, Mason, сессии и undo живут отдельно от
твоего «настоящего» Neovim install'а (`%LOCALAPPDATA%\nvim\` /
`~/.config/nvim/`) и не конфликтуют с ним.

## Install as the system Neovim config

For day-to-day use you can install this config as the default Neovim
config (Windows: `%LOCALAPPDATA%\nvim`, Linux/macOS:
`${XDG_CONFIG_HOME:-$HOME/.config}/nvim`). Plugin versions are pinned
in `lazy-lock.json`. Language servers, formatters and DAP tools are
installed by the explicit setup step or Mason commands below.

Обычный запуск подготовленной сборки не устанавливает инструменты и
Treesitter-парсеры. Для подготовки после установки/обновления:

```vim
:MasonToolsInstall
:ForgeTreesitterInstall
```

Для setup-скрипта доступна синхронная `:MasonToolsInstallSync`. Обновление
инструментов — отдельная команда `:MasonToolsUpdate`. После установки LSP
перезапусти редактор: доступные серверы включаются из PATH/Mason bin.
`gopls` ставится из активного Go-тулчейна (`go install golang.org/x/tools/gopls@latest`),
а не Mason. Первичная загрузка самих плагинов lazy.nvim остаётся частью
bootstrap; политика выше относится к инструментам и парсерам.

### Quick Install

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/cascad/forge-nvim/main/nvim_forge/scripts/install-windows.ps1 | iex
```

Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cascad/forge-nvim/main/nvim_forge/scripts/install-linux.sh | bash
```

macOS (на чистом маке: склонирует монорепо в `~/forge-nvim` и продолжит
оттуда, как `./nvim_forge/scripts/install-macos.sh`). Нужен git: без Xcode
Command Line Tools скрипт остановится и подскажет `xcode-select --install`
(системный диалог установки сам не всплывёт):

```bash
curl -fsSL https://raw.githubusercontent.com/cascad/forge-nvim/main/nvim_forge/scripts/install-macos.sh | bash
```

macOS: without flags the script sets up dependencies and WezTerm and leaves
`~/.config/nvim` alone (run `./nvim_forge.sh`). With `FORGE_NVIM_DEPS_ONLY=0`
the Neovim config path becomes a **symlink** to `nvim_forge/` of the checkout
(the local one or the clone in `FORGE_NVIM_SRC`): keep the checkout in place —
`git pull` there updates the installed config too. An existing config is moved
to a backup once; a rerun just reports `forge-nvim config already linked`.
Plugins are brought to the checkout's `lazy-lock.json` (`Lazy! restore`), so
the checkout stays clean, then Mason tools are installed.

Linux and Windows scripts install base dependencies, back up an existing
Neovim config, clone this repo, copy `nvim_forge/` into the Neovim config
directory, run `Lazy! sync`, and then try to install Mason tools.

> NOTE: the Linux/Windows install scripts, in the `~/.config/nvim` mode, still
> assume a flat repo layout where `init.lua` sits at the repo root. After the
> move into `nvim_forge/` they need a small update before remote installation
> works again. The macOS script links `nvim_forge/` instead (see above). Local
> development via `nvim_forge.sh` / `nvim_forge.cmd` is unaffected.

For Neovim 0.12+, `nvim-treesitter` uses its `main` branch and
requires `tree-sitter-cli`. The install scripts include it in the base
dependencies.

### Manual Install

Windows:

```powershell
git clone https://github.com/cascad/forge-nvim.git $env:TEMP\forge-nvim-src
Copy-Item -Recurse $env:TEMP\forge-nvim-src\nvim_forge\* $env:LOCALAPPDATA\nvim\
```

Linux/macOS:

```bash
git clone https://github.com/cascad/forge-nvim.git /tmp/forge-nvim-src
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
cp -r /tmp/forge-nvim-src/nvim_forge/. "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/"
```

### Script Options

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 `
  -RepoUrl https://github.com/cascad/forge-nvim.git `
  -Branch main `
  -InstallPath $env:LOCALAPPDATA\nvim
```

Useful switches:

- `-SkipDependencies` - do not install packages through `winget`.
- `-WithLanguages` - also install Rust, Go and Python toolchains.
- `-UseLocalSource` - copy the current checkout instead of cloning from GitHub.
- `-NoBackup` - fail if the target config directory already exists.

Linux/macOS use environment variables:

```bash
FORGE_NVIM_BRANCH=main \
FORGE_NVIM_WITH_LANGUAGES=1 \
FORGE_NVIM_INSTALL_DIR="$HOME/.config/nvim" \
bash scripts/install-linux.sh
```

Useful variables:

- `FORGE_NVIM_REPO`
- `FORGE_NVIM_BRANCH`
- `FORGE_NVIM_INSTALL_DIR`
- `FORGE_NVIM_SKIP_DEPS=1`
- `FORGE_NVIM_WITH_LANGUAGES=1`
- `FORGE_NVIM_USE_LOCAL_SOURCE=1`
- `FORGE_NVIM_NO_BACKUP=1`
- `FORGE_NVIM_DEPS_ONLY=0|1` (Linux and macOS): `1` — dependencies and WezTerm
  only, `~/.config/nvim` untouched. Linux default `0`, no detection; macOS
  default detected — `1` when run from the monorepo checkout
- `FORGE_NVIM_SKIP_WEZTERM=1` (Linux and macOS) — leave WezTerm and its config alone
- Linux only: `FORGE_NVIM_FORCE_WEZTERM=1` — set up WezTerm even without a GUI
  session (`DISPLAY` / `WAYLAND_DISPLAY`)
- macOS only: `FORGE_NVIM_SRC` (checkout location for `curl | bash` and for a
  script file run outside a checkout, default `~/forge-nvim`)
- macOS: `FORGE_NVIM_USE_LOCAL_SOURCE=1` means "no network: the only source is
  the checkout the script runs from" — outside a checkout the script refuses
  before doing anything; from a checkout it changes nothing. The install path
  is a symlink either way, nothing is copied.

## Notes

- Existing config is moved to `nvim.backup-YYYYMMDD-HHMMSS` by default.
- `lazy-lock.json` must be committed; it pins plugin versions.
- Do not commit `nvim-data`, Mason packages, sessions, swap files or local project `launch.json`.
- `launch.json.example` is committed as a template for project debug configs.

## Docs

- `QUICKSTART.md` - daily shortcuts.
- `PANELS.md` - panels, layouts, debug/test/search modes.
- `../docs/PANELS_PLAN.md` - upcoming mini-framework for panels (in repo root `docs/`).
