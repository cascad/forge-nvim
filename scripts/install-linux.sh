#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${FORGE_NVIM_REPO:-https://github.com/cascad/forge-nvim.git}"
BRANCH="${FORGE_NVIM_BRANCH:-main}"
INSTALL_DIR="${FORGE_NVIM_INSTALL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
SKIP_DEPS="${FORGE_NVIM_SKIP_DEPS:-0}"
WITH_LANGUAGES="${FORGE_NVIM_WITH_LANGUAGES:-0}"
USE_LOCAL_SOURCE="${FORGE_NVIM_USE_LOCAL_SOURCE:-0}"
NO_BACKUP="${FORGE_NVIM_NO_BACKUP:-0}"

step() {
  printf '\n==> %s\n' "$1"
}

info() {
  printf '    %s\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_deps() {
  if [ "$SKIP_DEPS" = "1" ]; then
    info "Skipping dependency install"
    return
  fi

  step "Installing base dependencies"
  if have apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y git neovim ripgrep fd-find cmake clang unzip curl build-essential python3 python3-venv python3-pip tree-sitter-cli
    mkdir -p "$HOME/.local/bin"
    if ! have fd && have fdfind; then
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
      export PATH="$HOME/.local/bin:$PATH"
    fi
    if [ "$WITH_LANGUAGES" = "1" ]; then
      run_sudo apt-get install -y golang-go cargo rustc
      info "For Rust stdlib navigation install rustup manually and run: rustup component add rust-src"
    fi
  elif have dnf; then
    run_sudo dnf install -y git neovim ripgrep fd-find cmake clang unzip curl gcc gcc-c++ make python3 python3-pip tree-sitter-cli
    if [ "$WITH_LANGUAGES" = "1" ]; then
      run_sudo dnf install -y golang rust cargo
    fi
  elif have pacman; then
    run_sudo pacman -Sy --needed git neovim ripgrep fd cmake clang unzip curl base-devel python python-pip tree-sitter-cli
    if [ "$WITH_LANGUAGES" = "1" ]; then
      run_sudo pacman -Sy --needed go rustup
    fi
  else
    info "No supported package manager found. Install git, nvim, rg, fd, cmake, clang manually."
  fi
}

backup_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
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
install_config
sync_neovim

printf '\nforge-nvim installed: %s\n' "$INSTALL_DIR"
printf 'Start with: nvim\n'
