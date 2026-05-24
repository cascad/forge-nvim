# forge-nvim

Portable Neovim IDE config for Rust, Go and Python.

This is one of several configs living in this repository. See the root
`README.md` for the full layout and how the launchers isolate state.

## Run locally (no install)

Из корня репозитория:

**Windows**

```cmd
nvim_forge.cmd
```

**macOS / Linux**

```bash
chmod +x nvim_forge.sh       # один раз после клонирования
./nvim_forge.sh
./nvim_forge.sh path/to/file # с файлом
```

Обе обёртки делают одно и то же: ставят `NVIM_APPNAME=nvim_forge` и
`XDG_CONFIG_HOME` на корень репо, после чего `exec nvim`. Переменные
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
installed by Mason on first sync.

### Quick Install

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/cascad/forge-nvim/main/nvim_forge/scripts/install-windows.ps1 | iex
```

Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cascad/forge-nvim/main/nvim_forge/scripts/install-linux.sh | bash
```

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/cascad/forge-nvim/main/nvim_forge/scripts/install-macos.sh | bash
```

The scripts install base dependencies, back up an existing Neovim
config, clone this repo, copy `nvim_forge/` into the Neovim config
directory, run `Lazy! sync`, and then try to install Mason tools.

> NOTE: the install scripts still assume a flat repo layout where
> `init.lua` sits at the repo root. After the move into `nvim_forge/`
> they need a small update before remote installation works again.
> Local development via `nvim_forge.cmd` is unaffected.

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

## Notes

- Existing config is moved to `nvim.backup-YYYYMMDD-HHMMSS` by default.
- `lazy-lock.json` must be committed; it pins plugin versions.
- Do not commit `nvim-data`, Mason packages, sessions, swap files or local project `launch.json`.
- `launch.json.example` is committed as a template for project debug configs.

## Docs

- `QUICKSTART.md` - daily shortcuts.
- `PANELS.md` - panels, layouts, debug/test/search modes.
- `../docs/PANELS_PLAN.md` - upcoming mini-framework for panels (in repo root `docs/`).
