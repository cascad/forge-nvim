#!/usr/bin/env bash
# ============================================================
# Установка forge-nvim на macOS. Идемпотентен: повторный запуск
# ничего не переустанавливает, только доставляет недостающее.
#
# Что делает:
#   1. brew-зависимости (git, neovim, ripgrep, fd, cmake,
#      tree-sitter-cli) + Nerd Font для иконок — только то, чего нет.
#   2. WezTerm: ставит cask, если терминала нет, и симлинкует
#      wezterm.lua из репо в ~/.config/wezterm/wezterm.lua.
#   3. Клонирует/обновляет конфиг в ~/.config/nvim и синкает плагины
#      (удалённая установка). Для ЛОКАЛЬНОЙ работы из чекаута через
#      ./nvim_forge.sh этот шаг не нужен — запускай с DEPS_ONLY.
#
# Флаги (env):
#   FORGE_NVIM_DEPS_ONLY=1      только зависимости + WezTerm, не трогать
#                               ~/.config/nvim (режим для ./nvim_forge.sh)
#   FORGE_NVIM_SKIP_DEPS=1      не ставить brew-пакеты
#   FORGE_NVIM_SKIP_WEZTERM=1   не трогать WezTerm и его конфиг
#   FORGE_NVIM_WITH_LANGUAGES=1 доставить go/python/rustup
#   FORGE_NVIM_INSTALL_DIR=...  куда ставить конфиг (деф. ~/.config/nvim)
#   FORGE_NVIM_NO_BACKUP=1      падать, если путь занят, вместо бэкапа
#
# Типовой запуск на маке с локальным чекаутом монорепо:
#   FORGE_NVIM_DEPS_ONLY=1 ./nvim_forge/scripts/install-macos.sh
#   ./nvim_forge.sh
# ============================================================
set -euo pipefail

REPO_URL="${FORGE_NVIM_REPO:-https://github.com/cascad/forge-nvim.git}"
BRANCH="${FORGE_NVIM_BRANCH:-main}"
INSTALL_DIR="${FORGE_NVIM_INSTALL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
SKIP_DEPS="${FORGE_NVIM_SKIP_DEPS:-0}"
WITH_LANGUAGES="${FORGE_NVIM_WITH_LANGUAGES:-0}"
USE_LOCAL_SOURCE="${FORGE_NVIM_USE_LOCAL_SOURCE:-0}"
NO_BACKUP="${FORGE_NVIM_NO_BACKUP:-0}"
DEPS_ONLY="${FORGE_NVIM_DEPS_ONLY:-0}"
SKIP_WEZTERM="${FORGE_NVIM_SKIP_WEZTERM:-0}"

step() {
  printf '\n==> %s\n' "$1"
}

info() {
  printf '    %s\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

formula_installed() {
  [ -n "$(brew list --formula --versions "$1" 2>/dev/null)" ]
}

cask_installed() {
  [ -n "$(brew list --cask --versions "$1" 2>/dev/null)" ]
}

# Ставит только отсутствующие формулы, уже установленные — пропускает.
ensure_formulas() {
  local missing=()
  local f
  for f in "$@"; do
    if formula_installed "$f"; then
      info "$f: already installed"
    else
      missing+=("$f")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    brew install "${missing[@]}"
  fi
}

ensure_casks() {
  local c
  for c in "$@"; do
    if cask_installed "$c"; then
      info "$c: already installed"
    else
      brew install --cask "$c"
    fi
  done
}

install_deps() {
  if [ "$SKIP_DEPS" = "1" ]; then
    info "Skipping dependency install"
    return
  fi

  if ! have brew; then
    printf 'Homebrew is required for automatic dependency install: https://brew.sh\n' >&2
    printf 'Install brew or rerun with FORGE_NVIM_SKIP_DEPS=1 after installing dependencies manually.\n' >&2
    exit 1
  fi

  step "Installing base dependencies"
  # tree-sitter-cli: в свежем Homebrew CLI отделён от библиотеки
  # tree-sitter (библиотека приедет сама как зависимость neovim).
  # llvm не ставим: для сборки treesitter-парсеров достаточно Apple clang
  # из Xcode CLT, без которого Homebrew и так не работает.
  ensure_formulas git neovim ripgrep fd cmake tree-sitter-cli

  step "Installing Nerd Font (иконки в nvim/wezterm)"
  # Основной шрифт из wezterm.lua — CaskaydiaCove Nerd Font.
  ensure_casks font-caskaydia-cove-nerd-font

  if [ "$WITH_LANGUAGES" = "1" ]; then
    step "Installing optional language toolchains"
    ensure_formulas go python rustup-init
    if ! have cargo; then
      rustup-init -y --no-modify-path
    fi
    # gopls — конвенция конфига: из Go-тулчейна (go install), НЕ через Mason
    # (см. nvim_forge/lua/plugins/lsp.lua и forge/health.lua).
    local gobin
    gobin="$(go env GOPATH)/bin"
    if have gopls || [ -x "$gobin/gopls" ]; then
      info "gopls: already installed"
    else
      go install golang.org/x/tools/gopls@latest
      info "gopls -> $gobin (добавь этот каталог в PATH, если его там нет)"
    fi
  fi
}

setup_wezterm() {
  if [ "$SKIP_WEZTERM" = "1" ]; then
    info "Skipping WezTerm setup"
    return
  fi

  step "Setting up WezTerm"

  if have wezterm || [ -d "/Applications/WezTerm.app" ]; then
    info "WezTerm: already installed"
  elif have brew; then
    ensure_casks wezterm
  else
    info "brew not found; install WezTerm manually: https://wezterm.org"
  fi

  # Ищем wezterm.lua относительно скрипта: сначала корень монорепо
  # (nvim_forge/scripts/../..), затем корень конфига (remote-раскладка).
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  local src=""
  local candidate
  for candidate in "$script_dir/../../wezterm.lua" "$script_dir/../wezterm.lua"; do
    if [ -f "$candidate" ]; then
      src="$(cd -P -- "$(dirname -- "$candidate")" && pwd)/wezterm.lua"
      break
    fi
  done

  if [ -z "$src" ]; then
    info "wezterm.lua not found near the config; skipping terminal config link"
    return
  fi

  local dst_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm"
  local dst="$dst_dir/wezterm.lua"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    info "WezTerm config already linked: $dst"
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup_path "$dst"
  fi

  mkdir -p "$dst_dir"
  ln -s "$src" "$dst"
  info "Linked $dst -> $src"
}

backup_path() {
  local path="$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return
  fi

  if [ "$NO_BACKUP" = "1" ]; then
    printf 'Install path already exists: %s\n' "$path" >&2
    printf 'Remove it manually or run without FORGE_NVIM_NO_BACKUP=1.\n' >&2
    exit 1
  fi

  local backup="${path}.backup-$(date +%Y%m%d-%H%M%S)"
  step "Backing up existing config"
  info "$path -> $backup"
  mv "$path" "$backup"
}

copy_local_repo() {
  local source="$1"
  local destination="$2"

  step "Copying local checkout"
  mkdir -p "$destination"
  (
    cd "$source"
    tar --exclude='./.git' --exclude='./nvim.log' -cf - .
  ) | (
    cd "$destination"
    tar -xf -
  )
}

install_config() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  local local_repo_root
  local_repo_root="$(cd "$script_dir/.." && pwd -P)"
  local running_from_repo=0
  if [ -f "$local_repo_root/init.lua" ] && [ -d "$local_repo_root/lua" ]; then
    running_from_repo=1
  fi

  step "Installing forge-nvim"
  info "Target: $INSTALL_DIR"

  if [ -d "$INSTALL_DIR/.git" ]; then
    local remote
    remote="$(git -C "$INSTALL_DIR" config --get remote.origin.url 2>/dev/null || true)"
    if [ "$remote" = "$REPO_URL" ] || printf '%s' "$remote" | grep -q 'forge-nvim'; then
      step "Updating existing checkout"
      git -C "$INSTALL_DIR" fetch origin "$BRANCH"
      git -C "$INSTALL_DIR" checkout "$BRANCH"
      git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH"
      return
    fi
  fi

  if [ "$running_from_repo" = "1" ] && [ -e "$INSTALL_DIR" ] && [ "$(cd "$local_repo_root" && pwd -P)" = "$(cd "$INSTALL_DIR" && pwd -P)" ]; then
    info "Already running from the target config directory"
    return
  fi

  backup_path "$INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [ "$USE_LOCAL_SOURCE" = "1" ]; then
    if [ "$running_from_repo" != "1" ]; then
      printf 'FORGE_NVIM_USE_LOCAL_SOURCE=1 requested, but script is not running from a forge-nvim checkout.\n' >&2
      exit 1
    fi
    copy_local_repo "$local_repo_root" "$INSTALL_DIR"
    return
  fi

  if have git; then
    step "Cloning $REPO_URL"
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
  elif [ "$running_from_repo" = "1" ]; then
    copy_local_repo "$local_repo_root" "$INSTALL_DIR"
  else
    printf 'git is required to clone %s\n' "$REPO_URL" >&2
    exit 1
  fi
}

sync_neovim() {
  if ! have nvim; then
    printf 'nvim is not available in PATH. Install Neovim or restart the shell.\n' >&2
    exit 1
  fi

  step "Syncing plugins"
  (
    cd "$INSTALL_DIR"
    nvim --headless "+Lazy! sync" "+qa"
    step "Installing Treesitter parsers"
    nvim --headless "+ForgeTreesitterInstall" "+qa" || \
      info "Treesitter parser install returned a non-zero status. Open :checkhealth nvim-treesitter inside nvim for details."
    step "Installing Mason tools"
    nvim --headless "+lua pcall(vim.cmd, 'Lazy load mason-tool-installer.nvim')" "+lua pcall(vim.cmd, 'MasonToolsInstallSync')" "+qa" || \
      info "Mason tool install returned a non-zero status. Open :Mason inside nvim for details."
  )
}

install_deps
setup_wezterm

if [ "$DEPS_ONLY" = "1" ]; then
  printf '\nDependencies and WezTerm are ready; ~/.config/nvim untouched.\n'
  printf 'Launch from the repo checkout: ./nvim_forge.sh\n'
  printf '(first start downloads plugins automatically)\n'
  exit 0
fi

install_config
sync_neovim

printf '\nforge-nvim installed: %s\n' "$INSTALL_DIR"
printf 'Start with: nvim\n'
