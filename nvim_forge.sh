#!/usr/bin/env bash
# ============================================================
# Launches Neovim with the nvim_forge config from this repository
# WITHOUT touching the parent shell's environment and WITHOUT
# copying anything into ~/.config/nvim.
#
# Equivalent to nvim_forge.cmd on Windows: scopes XDG_CONFIG_HOME
# + NVIM_APPNAME to this single nvim invocation (via env-prefix +
# `exec`) — parent shell stays untouched.
#
# Каталоги для этой сборки (изолированы через NVIM_APPNAME,
# Neovim сам добавляет суффикс к именам state-каталогов):
#   config : $REPO/nvim_forge/
#   data   : ${XDG_DATA_HOME:-$HOME/.local/share}/nvim_forge/
#   state  : ${XDG_STATE_HOME:-$HOME/.local/state}/nvim_forge/
#   cache  : ${XDG_CACHE_HOME:-$HOME/.cache}/nvim_forge/
#
# Чтобы снести ВСЁ ради этой сборки — удалить три data-каталога
# выше. Папка nvim_forge/ в репо при этом остаётся нетронутой.
#
# ВАЖНО: это локальный запускатор для разработки. Удалённая
# установка через scripts/install-*.sh кладёт конфиг в
# ~/.config/nvim (без суффикса) и работает параллельно.
#
# Использование:
#   ./nvim_forge.sh                  # запуск без аргументов
#   ./nvim_forge.sh path/to/file     # nvim откроет файл
#   ./nvim_forge.sh -- --version     # любые nvim-аргументы дальше
#
# Если получаешь "Permission denied" — дай exec bit один раз:
#   chmod +x nvim_forge.sh
# ============================================================

set -e

# Resolve repo root = directory of this script, c учётом symlink'ов.
SCRIPT="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT" ]; do
    DIR="$(cd -P "$(dirname "$SCRIPT")" && pwd)"
    SCRIPT="$(readlink "$SCRIPT")"
    case "$SCRIPT" in
        /*) ;;
        *) SCRIPT="$DIR/$SCRIPT" ;;
    esac
done
REPO="$(cd -P "$(dirname "$SCRIPT")" && pwd)"

# env-prefix + exec: переменные живут ровно одну nvim-сессию,
# родительский shell их не увидит. NVIM_APPNAME=nvim_forge
# заставляет Neovim искать конфиг в $XDG_CONFIG_HOME/nvim_forge/
# и складывать data/state/cache с тем же суффиксом.
exec env \
    XDG_CONFIG_HOME="$REPO" \
    NVIM_APPNAME=nvim_forge \
    nvim "$@"
