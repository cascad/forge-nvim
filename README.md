# forge-nvim repo

Multi-config monorepo for Neovim setups. Each subfolder is a complete
Neovim config; each `*.cmd` at the repo root is a launcher that runs
Neovim against that config **without touching** your system
`%LOCALAPPDATA%\nvim\` install.

## Configs

| Folder        | Launchers (Win / Unix)                | Purpose                                                |
|---------------|---------------------------------------|--------------------------------------------------------|
| `nvim_forge/` | `nvim_forge.cmd` / `nvim_forge.sh`    | Main IDE config (Rust / Go / Python). Bespoke, panel-driven. |
| `nvim_astro/` | `nvim_astro.cmd`                      | AstroNvim v6 + astrocommunity baseline for comparison. |
| `nvim-ide/`   | `nvim-ide.cmd`                        | `ldelossa/nvim-ide`-based testbed. Used to prototype panel UX. |

## How the launchers work

Each `*.cmd` / `*.sh` does the same thing in a single scoped env:

1. Set `XDG_CONFIG_HOME` to the repo root.
2. Set `NVIM_APPNAME` to the folder name (e.g. `nvim_forge`).
3. Run `nvim` with the supplied arguments.

Neovim then reads `<repo>/<NVIM_APPNAME>/init.lua` and keeps data,
state and cache in:

| OS       | data / state / cache                                                            |
|----------|---------------------------------------------------------------------------------|
| Windows  | `%LOCALAPPDATA%\<NVIM_APPNAME>-data\`, `%TEMP%\<NVIM_APPNAME>\`                  |
| Linux    | `~/.local/share/<NVIM_APPNAME>/`, `~/.local/state/<NVIM_APPNAME>/`, `~/.cache/<NVIM_APPNAME>/` |
| macOS    | same as Linux (XDG paths)                                                        |

So the configs are fully isolated from each other and from the
"real" install at `~/.config/nvim` (or `%LOCALAPPDATA%\nvim\`).

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
├── .gitignore          # shared
└── .gitattributes      # shared
```

## Daily entry points

| Goal                 | Windows              | macOS / Linux          | Docs |
|----------------------|----------------------|------------------------|------|
| Main IDE             | `nvim_forge.cmd`     | `./nvim_forge.sh`      | `nvim_forge/QUICKSTART.md`, `nvim_forge/PANELS.md` |
| AstroNvim baseline   | `nvim_astro.cmd`     | (one-liner below)      | `nvim_astro/README.md` |
| `ldelossa/nvim-ide`  | `nvim-ide.cmd`       | (one-liner below)      | `nvim-ide/README.md` |

On first use on macOS/Linux:

```bash
chmod +x nvim_forge.sh
./nvim_forge.sh                 # запуск без аргументов
./nvim_forge.sh path/to/file    # с файлом
```

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
