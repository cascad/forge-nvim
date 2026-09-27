#!/usr/bin/env bash
# ============================================================
# Установка forge-nvim на macOS. Идемпотентен: повторный запуск
# ничего не переустанавливает, только доставляет недостающее и чинит
# то, что разъехалось. Запускай в любой момент — это и есть «починка».
#
# Запуск из чекаута монорепо — одна команда, флаги не нужны:
#   ./nvim_forge/scripts/install-macos.sh
#   ./nvim_forge.sh
# На чистом маке без чекаута — `curl … | bash`: скрипт сам склонирует
# монорепо в ~/forge-nvim (FORGE_NVIM_SRC) и продолжит оттуда же. Нужен git:
# без Xcode Command Line Tools скрипт остановится и подскажет
# `xcode-select --install`.
#
# Что делает:
#   1. brew в PATH (дописывает `brew shellenv` в профиль логин-шелла —
#      ~/.bash_profile для bash, иначе ${ZDOTDIR:-~}/.zprofile, — если
#      установщик Homebrew этого не сделал), brew-зависимости (git, neovim,
#      ripgrep, fd, cmake, tree-sitter-cli) + Nerd Font — только то, чего нет.
#   2. WezTerm: ставит cask, если терминала нет; симлинкует wezterm.lua
#      из репо в ~/.config/wezterm/wezterm.lua; нейтрализует то, что этот
#      симлинк молча перекрывает (~/.wezterm.lua — в бэкап; переменная
#      WEZTERM_CONFIG_FILE — снимается в launchd, а в профилях шелла в конец
#      дописывается помеченный `unset`, свои строки не трогаются); в конце
#      проверяет, какой конфиг реально загрузит WezTerm из Dock и что он
#      загружается без ошибок. Не так — код возврата 1 с объяснением.
#   3. Только для установки в ~/.config/nvim (FORGE_NVIM_DEPS_ONLY=0):
#      делает путь установки симлинком на <чекаут>/nvim_forge и приводит
#      плагины к lazy-lock.json чекаута (`Lazy! restore`). Чекаут должен
#      оставаться на месте; `git pull` в нём обновляет и конфиг. Из чекаута
#      монорепо без флага этот шаг пропускается сам: nvim запускается через
#      ./nvim_forge.sh, ~/.config/nvim не трогаем.
#
# Флаги (env) — нужны только для нестандартных сценариев. Булев флаг
# включён только значением 1:
#   FORGE_NVIM_SRC=...          куда клонировать монорепо при `curl | bash` и
#                               при запуске файла вне чекаута (деф. ~/forge-nvim)
#   FORGE_NVIM_REPO=...         откуда клонировать
#                               (деф. https://github.com/cascad/forge-nvim.git)
#   FORGE_NVIM_BRANCH=...       ветка клона (деф. main)
#   FORGE_NVIM_DEPS_ONLY=0|1    явно: 0 — ставить в ~/.config/nvim даже из
#                               чекаута, 1 — не трогать ~/.config/nvim
#                               (по умолчанию определяется само)
#   FORGE_NVIM_INSTALL_DIR=...  где создать симлинк на конфиг
#                               (деф. ${XDG_CONFIG_HOME:-~/.config}/nvim; если
#                               XDG_CONFIG_HOME ведёт в чекаут — ~/.config/nvim)
#   FORGE_NVIM_USE_LOCAL_SOURCE=1 источник — только чекаут, из которого запущен
#                               скрипт: без сети; вне чекаута — отказ
#   FORGE_NVIM_SKIP_DEPS=1      не ставить brew-пакеты
#   FORGE_NVIM_SKIP_WEZTERM=1   не трогать WezTerm и его конфиг
#   FORGE_NVIM_WITH_LANGUAGES=1 доставить go/python/rustup
#   FORGE_NVIM_NO_BACKUP=1      падать, если путь занят, вместо бэкапа
# ============================================================
set -euo pipefail

REPO_URL="${FORGE_NVIM_REPO:-https://github.com/cascad/forge-nvim.git}"
BRANCH="${FORGE_NVIM_BRANCH:-main}"
SKIP_DEPS="${FORGE_NVIM_SKIP_DEPS:-0}"
WITH_LANGUAGES="${FORGE_NVIM_WITH_LANGUAGES:-0}"
USE_LOCAL_SOURCE="${FORGE_NVIM_USE_LOCAL_SOURCE:-0}"
NO_BACKUP="${FORGE_NVIM_NO_BACKUP:-0}"
SKIP_WEZTERM="${FORGE_NVIM_SKIP_WEZTERM:-0}"

# Каталог скрипта. Пуст при `curl … | bash`: тогда рядом нет ни чекаута,
# ни wezterm.lua. В этом режиме ${BASH_SOURCE[0]} на верхнем уровне не
# задан (с `set -u` — падение), а внутри функций равен "main" (bash 5) —
# поэтому `:-` и проверка, что это реальный файл.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
fi

# Общие функции подключения (resolve_path, path_within, link_with_backup,
# link_wezterm_config) — nvim_forge/scripts/lib/wezterm-link.sh, одна копия
# на macOS и Linux. Нет файла (скрипт скачан отдельно) — шаг WezTerm
# пропускается, а режим установки всё равно уходит в бутстрап.
WEZTERM_LINK_LIB=0
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/lib/wezterm-link.sh" ]; then
  # shellcheck source=lib/wezterm-link.sh
  . "$SCRIPT_DIR/lib/wezterm-link.sh"
  WEZTERM_LINK_LIB=1
fi

# Чекаут монорепо: скрипт лежит в <root>/nvim_forge/scripts, рядом с <root>
# лежит лаунчер nvim_forge.sh. Тогда режим по умолчанию — локальный
# (DEPS_ONLY): помнить флаг не нужно.
MONOREPO_ROOT=""
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../../nvim_forge.sh" ]; then
  MONOREPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
fi
DEPS_ONLY="${FORGE_NVIM_DEPS_ONLY:-}"
if [ -z "$DEPS_ONLY" ]; then
  if [ -n "$MONOREPO_ROOT" ]; then DEPS_ONLY=1; else DEPS_ONLY=0; fi
fi

# Итог шага WezTerm: ok | broken | skipped. broken → скрипт завершится
# с ненулевым кодом, но только после всех остальных шагов.
WEZTERM_STATUS="skipped"

step() {
  printf '\n==> %s\n' "$1"
}

info() {
  printf '    %s\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

# Путь установки конфига по умолчанию (MAC-INST-13): XDG_CONFIG_HOME шелла,
# кроме случая, когда он ведёт в чекаут (шелл из терминала nvim_forge) —
# тогда ~/.config.
default_install_dir() {
  local xdg="${XDG_CONFIG_HOME:-}"
  if [ -n "$xdg" ] && [ -n "$MONOREPO_ROOT" ] && [ "$WEZTERM_LINK_LIB" = "1" ] &&
     path_within "$(resolve_path "$xdg")" "$MONOREPO_ROOT"; then
    xdg=""
  fi
  printf '%s/nvim\n' "${xdg:-$HOME/.config}"
}
INSTALL_DIR="${FORGE_NVIM_INSTALL_DIR:-$(default_install_dir)}"
INSTALL_DIR="${INSTALL_DIR%/}"

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

# Homebrew на свежем Apple Silicon стоит в /opt/homebrew и в PATH не
# попадает, пока в профиле нет `brew shellenv` — официальный установщик
# только просит это дописать. Дописываем сами (один раз, помеченной
# строкой) и подключаем в текущий прогон.
ensure_brew_on_path() {
  local b profile line
  if have brew; then
    return 0
  fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ ! -x "$b" ]; then
      continue
    fi
    eval "$("$b" shellenv)"
    case "${SHELL:-}" in
      */bash) profile="$HOME/.bash_profile" ;;
      *) profile="${ZDOTDIR:-$HOME}/.zprofile" ;;
    esac
    line="eval \"\$($b shellenv)\""
    if ! grep -qF "$line" "$profile" 2>/dev/null; then
      printf '\n# [forge-nvim] Homebrew on PATH (install-macos.sh)\n%s\n' "$line" >> "$profile"
      info "$profile: добавлен brew shellenv"
    fi
    return 0
  done
  return 1
}

# CaskaydiaCove Nerd Font уже лежит в одном из каталогов шрифтов (MAC-INST-6)?
# Каждый каталог проверяется отдельно: glob без совпадений остаётся шаблоном,
# поэтому [ -e ] на каждом совпадении.
nerd_font_present() {
  local d f
  for d in "$HOME/Library/Fonts" "/Library/Fonts"; do
    for f in "$d"/CaskaydiaCoveNerdFont*; do
      if [ -e "$f" ]; then
        return 0
      fi
    done
  done
  return 1
}

install_deps() {
  if [ "$SKIP_DEPS" = "1" ]; then
    info "Skipping dependency install"
    return
  fi

  if ! ensure_brew_on_path; then
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
  # Основной шрифт из wezterm.lua — CaskaydiaCove Nerd Font. Уже лежит в
  # Library/Fonts (ставили руками) — cask не трогаем: он упал бы на
  # конфликте файлов и оборвал установку. Шрифт косметика, поэтому сбой
  # установки — предупреждение, а не остановка.
  if nerd_font_present; then
    info "CaskaydiaCove Nerd Font: already present in Library/Fonts"
  elif ! ensure_casks font-caskaydia-cove-nerd-font; then
    info "!! Nerd Font не поставился — иконки могут быть пустыми (brew install --cask font-caskaydia-cove-nerd-font)"
  fi

  if [ "$WITH_LANGUAGES" = "1" ]; then
    step "Installing optional language toolchains"
    ensure_formulas go python rustup-init
    # Rust стоит, если cargo в PATH или в ~/.cargo/bin (rustup-init ставим
    # с --no-modify-path, поэтому каталог может быть не в PATH) — MAC-INST-5.
    if have cargo; then
      info "rust: already installed"
    elif [ -x "$HOME/.cargo/bin/cargo" ]; then
      info "rust: already installed (~/.cargo/bin; добавь этот каталог в PATH, если его там нет)"
    else
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

# --- WezTerm -----------------------------------------------------------
# Конфиг терминала — симлинк на wezterm.lua из репо. WezTerm берёт ПЕРВЫЙ
# найденный конфиг (config/src/config.rs, load_with_overrides), и всё, что
# стоит в этом списке выше симлинка, перекрывает его молча:
#   1. переменная WEZTERM_CONFIG_FILE: у WezTerm.app из Dock/Spotlight — из
#      launchd (~/.zshrc он не читает), у запущенного из шелла — из профиля;
#   2. ~/.wezterm.lua;
#   3. $XDG_CONFIG_HOME/wezterm/wezterm.lua, где XDG_CONFIG_HOME — тоже из
#      launchd, по умолчанию ~/.config. Сюда и кладём симлинк.
# Порядок шага: сначала файлы (то, что может отказать при NO_BACKUP), потом
# переменная окружения, в конце — проверка тем же порядком поиска.
# Чужие строки в профилях шелла НЕ правим (переписывание ломает `…; fi`,
# многострочные значения и т.п.) — только дописываем в конец помеченный
# блок unset.

# Переменная окружения GUI-приложений (launchd), а не текущего шелла.
gui_env() {
  launchctl getenv "$1" 2>/dev/null || true
}

wezterm_gui_config_home() {
  local x
  x="$(gui_env XDG_CONFIG_HOME)"
  printf '%s\n' "${x:-$HOME/.config}"
}

# Какой файл загрузит WezTerm, запущенный из Dock/Spotlight. Пустая строка —
# встроенные дефолты. Битый симлинк WezTerm пропускает, как и [ -f ].
wezterm_effective_config() {
  local p
  p="$(gui_env WEZTERM_CONFIG_FILE)"
  if [ -n "$p" ]; then
    printf '%s\n' "$p"
    return 0
  fi
  for p in "$HOME/.wezterm.lua" "$(wezterm_gui_config_home)/wezterm/wezterm.lua"; do
    if [ -f "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  # Явный 0: иначе статус последнего `[ -f ]` (1) под `set -e` уронит
  # вызывающий `x="$(wezterm_effective_config)"`.
  return 0
}

# CLI из бандла предпочтительнее: он передаёт работу wezterm-gui из своего
# же каталога, то есть проверяется ровно та версия, что запускается из Dock.
wezterm_cli() {
  if [ -x "/Applications/WezTerm.app/Contents/MacOS/wezterm" ]; then
    printf '%s\n' "/Applications/WezTerm.app/Contents/MacOS/wezterm"
  elif have wezterm; then
    command -v wezterm
  fi
  return 0
}

# wezterm.lua рядом со скриптом: корень монорепо (nvim_forge/scripts/../..),
# затем корень конфига (remote-раскладка).
wezterm_src() {
  local candidate
  if [ -z "$SCRIPT_DIR" ] || [ "$WEZTERM_LINK_LIB" != "1" ]; then
    return 0
  fi
  for candidate in "$SCRIPT_DIR/../../wezterm.lua" "$SCRIPT_DIR/../wezterm.lua"; do
    if [ -f "$candidate" ]; then
      resolve_path "$candidate"
      return 0
    fi
  done
  return 0
}

# ~/.wezterm.lua главнее ~/.config/wezterm — если он не ведёт в репо,
# убираем в бэкап.
remove_home_wezterm_lua() {
  local src="$1" f="$HOME/.wezterm.lua"
  if { [ -e "$f" ] || [ -L "$f" ]; } && [ "$(resolve_path "$f")" != "$src" ]; then
    info "~/.wezterm.lua перекрывает ~/.config/wezterm/wezterm.lua"
    backup_path "$f"
  fi
  return 0
}

# Строки команды LaunchAgent-plist — ProgramArguments и Program — по одной
# на строку, с раскодированными XML-сущностями. Двоичный plist приводится к
# XML через plutil; без plutil файл читается как есть (WT-LOAD-8).
plist_command_strings() {
  local xml
  if have plutil; then
    xml="$(plutil -convert xml1 -o - "$1" 2>/dev/null)" || xml=""
  else
    xml="$(cat "$1" 2>/dev/null)" || xml=""
  fi
  printf '%s\n' "$xml" | tr '\n' ' ' | awk 'BEGIN { RS = "<" } {
      tag = $0; sub(/>.*/, "", tag)
      text = $0; if (sub(/^[^>]*>/, "", text) == 0) text = ""
      if (tag == "key") { key = text; want = (key == "ProgramArguments" || key == "Program"); next }
      if (tag == "string" && want) {
        gsub(/&lt;/, "<", text); gsub(/&gt;/, ">", text); gsub(/&quot;/, "\"", text)
        gsub(/&apos;/, "\047", text); gsub(/&amp;/, "\\&", text)
        print text
        if (key == "Program") want = 0
        next
      }
      if (tag == "/array") want = 0
    }'
}

# Значения WEZTERM_CONFIG_FILE, которые plist выставляет в launchd при входе:
# `launchctl setenv WEZTERM_CONFIG_FILE <значение>` подряд идущими аргументами
# или внутри строки для шелла (`sh -c "…"`); во втором случае ~ и $HOME
# раскрываются, как их раскрыл бы шелл. По значению на строку.
plist_wezterm_setenv_values() {
  local s prev2="" prev1="" prev0="" v
  while IFS= read -r s; do
    if { [ "$prev2" = "launchctl" ] || [ "${prev2##*/}" = "launchctl" ]; } &&
       [ "$prev1" = "setenv" ] && [ "$prev0" = "WEZTERM_CONFIG_FILE" ]; then
      printf '%s\n' "$s"
    fi
    prev2="$prev1"; prev1="$prev0"; prev0="$s"
    # Строка для шелла: вынуть значение после `launchctl setenv WEZTERM_CONFIG_FILE`.
    printf '%s\n' "$s" | sed -n -E 's/.*launchctl[[:space:]]+setenv[[:space:]]+WEZTERM_CONFIG_FILE[[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:];&|]+).*/\1/p' |
      while IFS= read -r v; do
        v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
        case "$v" in
          "~") v="$HOME" ;;
          "~/"*) v="$HOME/${v#\~/}" ;;
          '$HOME'*) v="$HOME${v#\$HOME}" ;;
          '${HOME}'*) v="$HOME${v#\$\{HOME\}}" ;;
        esac
        printf '%s\n' "$v"
      done
  done <<STRINGS
$(plist_command_strings "$1")
STRINGS
  return 0
}

# WEZTERM_CONFIG_FILE в launchd снимаем, если он ведёт не в репо. Plist
# в LaunchAgents, который выставляет её при каждом входе, сам не трогаем
# (там бывают и другие настройки) — называем, и шаг считается сломанным.
# Нарушители — по одному на строку (в bash 3.2 нет ассоциативных массивов).
WEZTERM_AGENT_OVERRIDES=""
clear_launchd_override() {
  local src="$1" cur agent v bad
  cur="$(gui_env WEZTERM_CONFIG_FILE)"
  if [ -n "$cur" ] && [ "$(resolve_path "$cur")" != "$src" ]; then
    launchctl unsetenv WEZTERM_CONFIG_FILE
    info "launchd: WEZTERM_CONFIG_FILE=$cur снят"
  fi
  for agent in "$HOME"/Library/LaunchAgents/*.plist /Library/LaunchAgents/*.plist; do
    if [ ! -f "$agent" ]; then
      continue
    fi
    bad=0
    while IFS= read -r v; do
      if [ -n "$v" ] && [ "$(resolve_path "$v")" != "$src" ]; then
        bad=1
      fi
    done <<VALUES
$(plist_wezterm_setenv_values "$agent")
VALUES
    if [ "$bad" = "1" ]; then
      WEZTERM_AGENT_OVERRIDES="${WEZTERM_AGENT_OVERRIDES}${agent}
"
    fi
  done
  return 0
}

# Профили шелла. ZDOTDIR обычно задаётся в ~/.zshenv и в bash не
# экспортируется — спрашиваем сам zsh.
shell_profiles() {
  local zd=""
  if [ -x /bin/zsh ]; then
    zd="$(/bin/zsh -c 'printf %s "${ZDOTDIR:-}"' 2>/dev/null || true)"
  fi
  zd="${zd:-${ZDOTDIR:-$HOME}}"
  printf '%s\n' \
    "$HOME/.zshenv" "$zd/.zshenv" "$zd/.zprofile" "$zd/.zshrc" "$zd/.zlogin" \
    "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zlogin" \
    "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile" \
    "$HOME/.config/fish/config.fish"
}

WEZTERM_GUARD_BEGIN='# >>> forge-nvim: WezTerm config is the symlink ~/.config/wezterm/wezterm.lua (install-macos.sh) >>>'
WEZTERM_GUARD_END='# <<< forge-nvim <<<'

# Хвост профиля после последнего блока forge-nvim (весь файл, если блока
# нет). Строка unset самого блока лежит до его конца и в хвост не попадает.
profile_tail() {
  awk -v m="$WEZTERM_GUARD_END" '$0 == m { buf = ""; next } { buf = buf $0 "\n" } END { printf "%s", buf }' "$1"
}

# Профиль, где WEZTERM_CONFIG_FILE задаётся (не в комментарии) после
# последнего блока forge-nvim, получает в конце ещё один блок `unset` —
# переменная живёт до конца профиля и снимается (WT-LOAD-7). Свои строки
# не правим, только дописываем: это не может сломать синтаксис.
guard_profiles_against_wezterm_env() {
  local f r seen="|" cmd
  while IFS= read -r f; do
    if [ ! -f "$f" ]; then
      continue
    fi
    r="$(resolve_path "$f")"
    case "$seen" in *"|$r|"*) continue ;; esac
    seen="$seen$r|"
    if ! profile_tail "$f" | grep -qE '^[^#]*WEZTERM_CONFIG_FILE'; then
      continue
    fi
    case "$f" in
      *.fish) cmd='set -e WEZTERM_CONFIG_FILE' ;;
      *) cmd='unset WEZTERM_CONFIG_FILE' ;;
    esac
    if [ -w "$r" ] &&
       printf '\n%s\n%s\n%s\n' "$WEZTERM_GUARD_BEGIN" "$cmd" "$WEZTERM_GUARD_END" >> "$f"; then
      info "$f задаёт WEZTERM_CONFIG_FILE — в конец дописан '$cmd' (свои строки не тронуты)"
    else
      info "!! $f задаёт WEZTERM_CONFIG_FILE, но недоступен для записи — допиши в конец: $cmd"
    fi
  done <<PROFILES
$(shell_profiles)
PROFILES
  return 0
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

  local src
  src="$(wezterm_src)"
  if [ -z "$src" ]; then
    info "wezterm.lua not found near the config; skipping terminal config link"
    return
  fi

  local before
  before="$(wezterm_effective_config)"
  if [ -n "$before" ]; then
    before="$(resolve_path "$before")"
  fi

  # 1. Файлы. Здесь NO_BACKUP может отказать — до правок окружения.
  remove_home_wezterm_lua "$src"
  link_wezterm_config "$src" "$(wezterm_gui_config_home)/wezterm"
  # 2. Переменная окружения.
  clear_launchd_override "$src"
  guard_profiles_against_wezterm_env
  # 3. Итог.
  verify_wezterm_config "$src" "$before"
}

# Загрузил ли файл репо WezTerm, из панели которого запущен установщик
# (WT-LOAD-12). Авторитетна WEZTERM_CONFIG_FILE панели; если её сняли
# (профиль, WT-LOAD-7) — кандидаты в WEZTERM_CONFIG_DIR и launchd-переменная
# из того же каталога. Нет WEZTERM_CONFIG_DIR — GUI на встроенных дефолтах.
pane_loaded_repo_config() {
  local src="$1" c lp
  if [ -n "${WEZTERM_CONFIG_FILE:-}" ]; then
    [ "$(resolve_path "$WEZTERM_CONFIG_FILE")" = "$src" ]
    return
  fi
  if [ -z "${WEZTERM_CONFIG_DIR:-}" ]; then
    return 1
  fi
  for c in "$WEZTERM_CONFIG_DIR/wezterm.lua" "$WEZTERM_CONFIG_DIR/.wezterm.lua"; do
    if { [ -e "$c" ] || [ -L "$c" ]; } && [ "$(resolve_path "$c")" = "$src" ]; then
      return 0
    fi
  done
  lp="$(gui_env WEZTERM_CONFIG_FILE)"
  if [ -n "$lp" ] && [ "$(dirname -- "$lp")" = "${WEZTERM_CONFIG_DIR%/}" ] &&
     [ "$(resolve_path "$lp")" = "$src" ]; then
    return 0
  fi
  return 1
}

verify_wezterm_config() {
  local src="$1" before="$2" effective agent
  WEZTERM_STATUS="ok"

  effective="$(wezterm_effective_config)"
  if [ -n "$effective" ] && [ "$(resolve_path "$effective")" = "$src" ]; then
    info "WezTerm загрузит: $effective -> $src"
  else
    WEZTERM_STATUS="broken"
    printf '!! WezTerm из Dock загрузит НЕ конфиг из репо: %s\n' "${effective:-встроенные дефолты}" >&2
  fi
  while IFS= read -r agent; do
    if [ -n "$agent" ]; then
      WEZTERM_STATUS="broken"
      printf '!! %s выставляет WEZTERM_CONFIG_FILE при каждом входе в систему — убери из него эту переменную\n' \
        "$agent" >&2
    fi
  done <<AGENTS
$WEZTERM_AGENT_OVERRIDES
AGENTS

  # Загружается ли wezterm.lua. show-keys для этого не годится: на
  # сломанном конфиге он молча печатает дефолты и выходит с 0. ls-fonts
  # честнее: при ошибке пустой stdout и строка ERROR в stderr
  # (проверено на 20240203: синтаксис, runtime error, нет файла).
  local cli out log
  cli="$(wezterm_cli)"
  if [ -n "$cli" ]; then
    log="$(mktemp "${TMPDIR:-/tmp}/forge-wezterm.XXXXXX")"
    out="$("$cli" --config-file "$src" ls-fonts 2>"$log" || true)"
    if [ -n "$out" ] && ! grep -q 'ERROR' "$log"; then
      info "wezterm.lua загружается без ошибок"
    else
      WEZTERM_STATUS="broken"
      printf '!! wezterm.lua не загружается:\n' >&2
      cat "$log" >&2
    fi
    rm -f "$log"
  else
    info "wezterm CLI не найден — не проверяю, что wezterm.lua загружается"
  fi

  # Подсказка про перезапуск: WezTerm уже запущен, а грузил не этот файл —
  # до правок из Dock или в панели, из которой запущен установщик.
  if [ "$WEZTERM_STATUS" = "ok" ] && pgrep -x wezterm-gui >/dev/null 2>&1 &&
     { [ "$before" != "$src" ] ||
       { [ -n "${WEZTERM_PANE:-}" ] && ! pane_loaded_repo_config "$src"; }; }; then
    info "WezTerm запущен со старым конфигом — закрой его (Cmd+Q) и открой заново, один раз"
  fi
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

# --- Режим установки в ~/.config/nvim (MAC-INST-10) ---------------------
# Путь установки — симлинк на <чекаут>/nvim_forge. Все отказы — до первого
# бэкапа: эта предпроверка идёт сразу после шага зависимостей (nvim ставит
# он), до шага WezTerm (он сам бэкапит ~/.wezterm.lua).
preflight_install() {
  local cfg="$MONOREPO_ROOT/nvim_forge" dst
  if [ ! -f "$cfg/init.lua" ]; then
    printf 'No init.lua in %s: this is not a Neovim config.\n' "$cfg" >&2
    exit 1
  fi
  dst="$(resolve_path "$INSTALL_DIR")"
  if [ "$dst" != "$cfg" ] &&
     { path_within "$MONOREPO_ROOT" "$dst" || path_within "$dst" "$MONOREPO_ROOT"; }; then
    printf 'Install path %s overlaps the forge-nvim checkout %s; set FORGE_NVIM_INSTALL_DIR outside it.\n' \
      "$INSTALL_DIR" "$MONOREPO_ROOT" >&2
    exit 1
  fi
  if ! have nvim; then
    printf 'nvim is not available in PATH. Install Neovim or restart the shell.\n' >&2
    exit 1
  fi
}

install_config() {
  step "Installing forge-nvim"
  info "Target: $INSTALL_DIR"
  link_with_backup "$INSTALL_DIR" "$MONOREPO_ROOT/nvim_forge" "forge-nvim config"
}

# Плагины — к lazy-lock.json чекаута (`Lazy! restore`): sync переписал бы
# отслеживаемый lockfile, и `git pull --ff-only` бутстрапа потом падал бы
# на грязном чекауте. nvim читает ровно путь установки: XDG_CONFIG_HOME —
# его родитель, NVIM_APPNAME — его имя, а не то, что шелл унаследовал из
# терминала nvim_forge.
sync_neovim() {
  step "Syncing plugins (Lazy! restore — lazy-lock.json чекаута)"
  (
    cd "$HOME"
    XDG_CONFIG_HOME="$(dirname -- "$INSTALL_DIR")"
    NVIM_APPNAME="$(basename -- "$INSTALL_DIR")"
    export XDG_CONFIG_HOME NVIM_APPNAME
    nvim --headless "+Lazy! restore" "+qa"
    step "Installing Treesitter parsers"
    nvim --headless "+ForgeTreesitterInstall" "+qa" || \
      info "Treesitter parser install returned a non-zero status. Open :checkhealth nvim-treesitter inside nvim for details."
    step "Installing Mason tools"
    nvim --headless "+lua pcall(vim.cmd, 'Lazy load mason-tool-installer.nvim')" "+lua pcall(vim.cmd, 'MasonToolsInstallSync')" "+qa" || \
      info "Mason tool install returned a non-zero status. Open :Mason inside nvim for details."
  )
}

# Сломанный шаг WezTerm не прерывает остальную установку, но делает код
# возврата ненулевым: «поставилось» должно означать «работает».
finish() {
  if [ "$WEZTERM_STATUS" = "broken" ]; then
    printf '\n!! WezTerm: конфиг из репо НЕ будет загружен — см. сообщения выше.\n' >&2
    printf '   Исправь указанное и запусти этот скрипт ещё раз.\n' >&2
    exit 1
  fi
  exit 0
}

# git доступен (MAC-INST-3)? На маке без Xcode CLT /usr/bin/git — заглушка:
# её запуск всплывает системным диалогом. Признак — `xcode-select -p` с
# ошибкой; сам xcode-select ничего не запускает.
git_available() {
  local g
  g="$(command -v git 2>/dev/null)" || return 1
  if [ "$g" = "/usr/bin/git" ] && have xcode-select && ! xcode-select -p >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Чекаута рядом нет (`curl … | bash` или файл вне чекаута в режиме
# установки): делаем его (или обновляем) и перезапускаемся оттуда — дальше
# путь один, из чекаута. Режим установки передаётся явно: без флага
# перезапуск из чекаута выбрал бы локальный режим.
bootstrap_checkout() {
  local dir="${FORGE_NVIM_SRC:-$HOME/forge-nvim}"
  if ! git_available; then
    printf 'git is required: run `xcode-select --install`, then rerun this command.\n' >&2
    exit 1
  fi
  if [ -d "$dir/.git" ]; then
    step "Updating checkout $dir"
    git -C "$dir" pull --ff-only
  else
    step "Cloning $REPO_URL -> $dir"
    git clone --branch "$BRANCH" "$REPO_URL" "$dir"
  fi
  if [ -n "$SCRIPT_DIR" ]; then
    FORGE_NVIM_DEPS_ONLY=0
    export FORGE_NVIM_DEPS_ONLY
  fi
  exec bash "$dir/nvim_forge/scripts/install-macos.sh"
}

# Режим установки из файла вне чекаута: источник — только локальный чекаут
# (FORGE_NVIM_USE_LOCAL_SOURCE=1) — отказ до любых действий, иначе бутстрап.
if [ -z "$SCRIPT_DIR" ]; then
  bootstrap_checkout
elif [ -z "$MONOREPO_ROOT" ] && [ "$DEPS_ONLY" != "1" ]; then
  if [ "$USE_LOCAL_SOURCE" = "1" ]; then
    printf 'FORGE_NVIM_USE_LOCAL_SOURCE=1 requested, but script is not running from a forge-nvim checkout.\n' >&2
    exit 1
  fi
  bootstrap_checkout
fi

install_deps
if [ "$DEPS_ONLY" != "1" ]; then
  preflight_install
fi
setup_wezterm

if [ "$DEPS_ONLY" = "1" ]; then
  printf '\nDependencies and WezTerm are ready; ~/.config/nvim untouched.\n'
  if [ -n "$MONOREPO_ROOT" ]; then
    printf 'Launch: %s/nvim_forge.sh\n' "$MONOREPO_ROOT"
  else
    printf 'Launch from the repo checkout: ./nvim_forge.sh\n'
  fi
  printf '(first start downloads plugins automatically)\n'
  finish
fi

install_config
sync_neovim

printf '\nforge-nvim installed: %s\n' "$INSTALL_DIR"
printf 'Start with: nvim\n'
finish
