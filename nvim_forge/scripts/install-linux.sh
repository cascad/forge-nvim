#!/usr/bin/env bash
# ============================================================
# Установка forge-nvim на Linux (apt / dnf / pacman). Идемпотентен:
# повторный запуск ничего не переустанавливает, только доставляет
# недостающее (сами пакетные менеджеры пропускают установленное).
#
# Что делает:
#   1. Пакеты-зависимости (git, neovim, ripgrep, fd, cmake, clang,
#      tree-sitter-cli и т.д.) — через нативный пакетный менеджер.
#   2. WezTerm (только в GUI-сессии): ставит терминал, Nerd Font
#      (CaskaydiaCove) и симлинкует wezterm.lua из репо в
#      ~/.config/wezterm/wezterm.lua.
#   3. Клонирует/обновляет конфиг в ~/.config/nvim и синкает плагины
#      (удалённая установка). Для ЛОКАЛЬНОЙ работы из чекаута через
#      ./nvim_forge.sh этот шаг не нужен — запускай с DEPS_ONLY.
#
# Флаги (env):
#   FORGE_NVIM_DEPS_ONLY=1      только зависимости + WezTerm, не трогать
#                               ~/.config/nvim (режим для ./nvim_forge.sh)
#   FORGE_NVIM_SKIP_DEPS=1      не ставить пакеты
#   FORGE_NVIM_SKIP_WEZTERM=1   не трогать WezTerm и его конфиг
#   FORGE_NVIM_FORCE_WEZTERM=1  ставить WezTerm даже без $DISPLAY (headless)
#   FORGE_NVIM_WITH_LANGUAGES=1 доставить go/rust тулчейны
#   FORGE_NVIM_INSTALL_DIR=...  куда ставить конфиг (деф. ~/.config/nvim)
#   FORGE_NVIM_NO_BACKUP=1      падать, если путь занят, вместо бэкапа
#
# Типовой запуск с локальным чекаутом монорепо:
#   FORGE_NVIM_DEPS_ONLY=1 ./nvim_forge/scripts/install-linux.sh
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
FORCE_WEZTERM="${FORGE_NVIM_FORCE_WEZTERM:-0}"

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
  # apt/dnf идемпотентны сами по себе, pacman — через --needed:
  # уже установленные пакеты пропускаются.
  if have apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y git neovim ripgrep fd-find cmake clang unzip curl gnupg build-essential python3 python3-venv python3-pip tree-sitter-cli
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
    run_sudo pacman -Sy --needed --noconfirm git neovim ripgrep fd cmake clang unzip curl base-devel python python-pip tree-sitter-cli
    if [ "$WITH_LANGUAGES" = "1" ]; then
      run_sudo pacman -Sy --needed --noconfirm go rustup
    fi
  else
    info "No supported package manager found. Install git, nvim, rg, fd, cmake, clang manually."
  fi

  if [ "$WITH_LANGUAGES" = "1" ] && have go; then
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

install_nerd_font() {
  # CaskaydiaCove Nerd Font — основной шрифт из wezterm.lua. В дистро-репах
  # его обычно нет, тянем релиз nerd-fonts в ~/.local/share/fonts.
  local font_dir="$HOME/.local/share/fonts/CaskaydiaCoveNerdFont"

  if fc-list 2>/dev/null | grep -qi 'CaskaydiaCove'; then
    info "CaskaydiaCove Nerd Font: already installed"
    return
  fi
  if [ -d "$font_dir" ] && [ -n "$(ls -A "$font_dir" 2>/dev/null)" ]; then
    info "CaskaydiaCove Nerd Font: already installed ($font_dir)"
    return
  fi

  if ! have curl || ! have unzip; then
    info "curl/unzip not available; skipping Nerd Font install"
    return
  fi

  info "Downloading CaskaydiaCove Nerd Font"
  local tmp_zip
  tmp_zip="$(mktemp -t caskaydia-XXXXXX.zip)"
  # Архив называется CascadiaCode, семейство внутри — CaskaydiaCove NF.
  if curl -fsSL -o "$tmp_zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"; then
    mkdir -p "$font_dir"
    unzip -oq "$tmp_zip" '*.ttf' -d "$font_dir"
    rm -f "$tmp_zip"
    if have fc-cache; then
      fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    fi
    info "Installed to $font_dir"
  else
    rm -f "$tmp_zip"
    info "Font download failed; install a Nerd Font manually: https://www.nerdfonts.com"
  fi
}

install_wezterm_pkg() {
  if have wezterm; then
    info "WezTerm: already installed"
    return
  fi

  if have pacman; then
    run_sudo pacman -Sy --needed --noconfirm wezterm
  elif have dnf; then
    # В свежих Fedora wezterm есть в официальных репах.
    run_sudo dnf install -y wezterm || \
      info "wezterm not found in dnf repos; install manually: https://wezterm.org/install/linux.html"
  elif have apt-get; then
    # В Debian/Ubuntu репах wezterm нет — подключаем официальный apt-репо
    # автора (см. https://wezterm.org/install/linux.html), один раз.
    if [ ! -f /etc/apt/sources.list.d/wezterm.list ]; then
      curl -fsSL https://apt.fury.io/wez/gpg.key | \
        run_sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
      echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | \
        run_sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
      run_sudo apt-get update
    fi
    run_sudo apt-get install -y wezterm || \
      info "wezterm install failed; install manually: https://wezterm.org/install/linux.html"
  else
    info "Install WezTerm manually: https://wezterm.org/install/linux.html"
  fi
}

setup_wezterm() {
  if [ "$SKIP_WEZTERM" = "1" ]; then
    info "Skipping WezTerm setup"
    return
  fi

  # На headless-сервере GUI-терминал и шрифты не нужны.
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$FORCE_WEZTERM" != "1" ]; then
    info "No GUI session detected; skipping WezTerm setup (FORGE_NVIM_FORCE_WEZTERM=1 to force)"
    return
  fi

  step "Setting up WezTerm"
  install_wezterm_pkg
  install_nerd_font

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
