#!/usr/bin/env bash
# spec: IDE-BOOT-11. env живёт только в дочернем процессе.
set -euo pipefail
script="${BASH_SOURCE[0]}"
while [ -L "$script" ]; do
  parent="$(cd -P "$(dirname "$script")" && pwd)"
  script="$(readlink "$script")"
  case "$script" in /*) ;; *) script="$parent/$script";; esac
done
root="$(cd -P "$(dirname "$script")/.." && pwd)"
unset VIM VIMRUNTIME VIMINIT EXINIT LUA_INIT LUA_PATH LUA_CPATH FORGE_NVIM_COMPONENTS FORGE_SDK_PATHS
export NVIM_APPNAME=fride FRIDE_CONFIG="$root/config/forge" FRIDE_RUNTIME="$root/runtime"
export NVIM_LOG_FILE="$root/log/nvim.log" TMPDIR="$root/tmp" TEMP="$root/tmp" TMP="$root/tmp"
# Файл создаётся installer из проверенных относительных bin directories; без eval.
forge_path=''
while IFS= read -r dir; do
  forge_path="${forge_path:+$forge_path:}$root/runtime/$dir"
done < "$root/bin/runtime-paths.txt"
PATH="$forge_path:$PATH"
if [ -f "$root/bin/sdk-paths.txt" ]; then
  while IFS= read -r dir; do
    dir="${dir%$'\r'}"
    if [ -n "$dir" ]; then PATH="$PATH:$dir";fi
  done < "$root/bin/sdk-paths.txt"
fi
export PATH
exec "$root/runtime/bin/nvim" --cmd 'lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)' -u "$FRIDE_CONFIG/init.lua" "$@"
