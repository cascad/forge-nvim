# forge-nvim repo

## Рабочий план мини-IDE

Основная сборка — **nvim_forge**. Текущие этапы, приоритеты и критерии
готовности: [docs/IDE_ROADMAP.md](docs/IDE_ROADMAP.md).
Новые проблемы добавляем в [PROBLEMS.md](PROBLEMS.md), порядок работы — в план.
Первый этап: [диагностика задержек zsh/Go на Mac](docs/MACOS_STARTUP_DIAGNOSTICS.md).
Активные среды — Windows/macOS/Ubuntu; Mint пока отложен: [границы модулей](docs/PORTABLE_ARCHITECTURE.md).
[E2E и команды прогонов внутри VM](tests/e2e/README.md).
[Команды агента и формат получаемых результатов](docs/AGENT_COMMANDS.md).
[Клавиши рабочих панелей Space w](nvim_forge/QUICKSTART.md#общий-маршрут-рабочих-панелей--space-w).
[Фактическая матрица языков и следующие шаги](docs/LANGUAGE_MATRIX.md).
[Bash: язык, запуск файла и Tests](docs/BASH_WORKFLOW.md).
[SQL: язык, подключения, запросы и Results](docs/SQL_WORKFLOW.md).
[SQLLogicTest: запуск SQL-тестов в Tests](docs/SQL_TESTS.md).
[Единая история работ, причин и решений](docs/HISTORY.md), включая материалы
из прежнего `F:/claude_code/vim`; новые исправления — в `nvim_forge/FIXLOG.md`.

Multi-config monorepo for Neovim setups. Each subfolder is a complete
Neovim config; each `*.cmd` at the repo root is a launcher that runs
Neovim against that config **without touching** your system
`%LOCALAPPDATA%\nvim\` install.

## Configs

| Folder        | Launchers (Win / Unix)                | Purpose                                                |
|---------------|---------------------------------------|--------------------------------------------------------|
| `nvim_forge/` | `nvim_forge.cmd` / `nvim_forge.sh`    | Main IDE config (Rust / Go / Python / JS / Bash / SQL). Bespoke, panel-driven. |
| `nvim_astro/` | `nvim_astro.cmd`                      | AstroNvim v6 + astrocommunity baseline for comparison. |
| `nvim-ide/`   | `nvim-ide.cmd`                        | `ldelossa/nvim-ide`-based testbed. Used to prototype panel UX. |

## How the launchers work

Each `*.cmd` / `*.sh` does the same thing in a single scoped env:

1. Set `XDG_CONFIG_HOME` to the repo root.
2. Set `NVIM_APPNAME` to the folder name (e.g. `nvim_forge`).
3. Run Neovim with the supplied arguments. `nvim_forge.cmd` uses the
   prepared Windows SDK; POSIX launchers and other configs use `nvim` in PATH.

Для `nvim_forge` на Windows один раз явно подготовить временный SDK:

```powershell
powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download
.\nvim_forge.cmd
```

На builder нужны Git, CMake/Ninja и MSVC C++ Build Tools. Source/build/temp
остаются на диске checkout; runtime — `.tools/neovim/windows-x64`.
Launcher/test entrypoint проверяют manifest и SHA256, ничего не собирают
при старте. Системный `nvim` не заменяется. Причина, A/B и команды:
[tests/diagnostics/README.md](tests/diagnostics/README.md).

Neovim then reads `<repo>/<NVIM_APPNAME>/init.lua` and keeps data,
state and cache in:

| OS       | data / state / cache                                                            |
|----------|---------------------------------------------------------------------------------|
| Windows  | `%LOCALAPPDATA%\<NVIM_APPNAME>-data\`, `%TEMP%\<NVIM_APPNAME>\`                  |
| Linux    | `~/.local/share/<NVIM_APPNAME>/`, `~/.local/state/<NVIM_APPNAME>/`, `~/.cache/<NVIM_APPNAME>/` |
| macOS    | same as Linux (XDG paths)                                                        |

So the configs are fully isolated from each other and from the
"real" install at `~/.config/nvim` (or `%LOCALAPPDATA%\nvim\`) — on
macOS that install is a symlink to this checkout's `nvim_forge/`, so its
plugin data (`~/.local/share/nvim`) is still separate.

To nuke a single config's data, delete its `*-data\` folder
(Windows) or `~/.local/share/<NVIM_APPNAME>/` etc. (Unix). The source
folder in the repo stays intact.

## Repo layout

```
forge-nvim/
├── nvim_forge/         # main config (was the repo root before refactor)
│   ├── init.lua
│   ├── lua/
│   ├── lazy-lock.json
│   ├── scripts/        # install scripts (remote install)
│   ├── PANELS.md
│   ├── QUICKSTART.md
│   └── README.md
├── nvim_astro/         # AstroNvim v6 baseline
├── nvim-ide/           # ldelossa/nvim-ide based testbed (was: nvim2/)
├── docs/               # cross-config docs and plans
├── nvim_forge.cmd      # launcher (Windows)
├── nvim_forge.sh       # launcher (macOS / Linux)
├── nvim_astro.cmd      # launcher (Windows)
├── nvim-ide.cmd        # launcher (Windows, was: nvim2.cmd)
├── wezterm.lua         # terminal + multiplexer config, shared Win/macOS
├── .gitignore          # shared
└── .gitattributes      # shared
```

## Daily entry points

| Goal                 | Windows              | macOS / Linux          | Docs |
|----------------------|----------------------|------------------------|------|
| Main IDE             | `nvim_forge.cmd`     | `./nvim_forge.sh`      | `nvim_forge/QUICKSTART.md`, `nvim_forge/PANELS.md` |
| AstroNvim baseline   | `nvim_astro.cmd`     | (one-liner below)      | `nvim_astro/README.md` |
| `ldelossa/nvim-ide`  | `nvim-ide.cmd`       | (one-liner below)      | `nvim-ide/README.md` |
| Terminal + panes     | `wezterm.lua`        | `wezterm.lua`          | `docs/WEZTERM.md` |

macOS — один скрипт из чекаута, без флагов. Он ставит зависимости, шрифт,
WezTerm и его конфиг (и проверяет, что WezTerm его реально подхватит).
Повторный запуск безопасен и заодно чинит то, что разъехалось:

```bash
./nvim_forge/scripts/install-macos.sh
./nvim_forge.sh                 # запуск без аргументов
./nvim_forge.sh path/to/file    # с файлом
```

Linux: `chmod +x nvim_forge.sh` (если exec-бит потерялся), дальше так же
`./nvim_forge.sh`.

`nvim_forge.sh` использует `exec env XDG_CONFIG_HOME=$REPO
NVIM_APPNAME=nvim_forge nvim "$@"` — переменные живут только пока
работает nvim, родительский shell их не получает.

Эквивалентный one-liner для случаев, когда нет sh-launcher'а
(`nvim_astro`, `nvim-ide`):

```bash
XDG_CONFIG_HOME="$PWD" NVIM_APPNAME=nvim_astro nvim
XDG_CONFIG_HOME="$PWD" NVIM_APPNAME=nvim-ide   nvim
```

## Notes

- `lazy-lock.json` inside each config is committed to pin plugin versions.
- Mason data, sessions, swap files, undo and logs are git-ignored
  (see `.gitignore`).
- `.gitattributes` пинит line endings: `.sh` — LF, `.ps1` / `.cmd` — CRLF
  (если когда-нибудь захочется добавить `.cmd` в `text eol`, сейчас они
  под `* text=auto`). Это значит `nvim_forge.sh` корректно отрабатывает
  на macOS/Linux даже если был добавлен с Windows-машины.
