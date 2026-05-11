# forge-nvim

Portable Neovim IDE config for Rust, Go and Python.

The repository is meant to be installed directly as the Neovim config directory:

- Windows: `%LOCALAPPDATA%\nvim`
- macOS/Linux: `${XDG_CONFIG_HOME:-$HOME/.config}/nvim`

Plugin versions are pinned in `lazy-lock.json`. Language servers, formatters and DAP tools are installed by Mason on first sync.

## Quick Install

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/cascad/forge-nvim/main/scripts/install-windows.ps1 | iex
```

Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cascad/forge-nvim/main/scripts/install-linux.sh | bash
```

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/cascad/forge-nvim/main/scripts/install-macos.sh | bash
```

The scripts install base dependencies, back up an existing Neovim config, clone this repo into the Neovim config directory, run `Lazy! sync`, and then try to install Mason tools.

For Neovim 0.12+, `nvim-treesitter` uses its `main` branch and requires `tree-sitter-cli`. The install scripts include it in the base dependencies.

## Manual Install

Windows:

```powershell
git clone https://github.com/cascad/forge-nvim.git $env:LOCALAPPDATA\nvim
powershell -ExecutionPolicy Bypass -File $env:LOCALAPPDATA\nvim\scripts\install-windows.ps1
```

Linux/macOS:

```bash
git clone https://github.com/cascad/forge-nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
bash "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/scripts/install-linux.sh"
```

On macOS use `install-macos.sh` instead of `install-linux.sh`.

## Script Options

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
