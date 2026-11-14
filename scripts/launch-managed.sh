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
unset VIM VIMRUNTIME VIMINIT EXINIT LUA_INIT LUA_PATH LUA_CPATH FORGE_NVIM_COMPONENTS
export XDG_CONFIG_HOME="$root/config" XDG_DATA_HOME="$root/data"
export XDG_STATE_HOME="$root/state" XDG_CACHE_HOME="$root/cache" NVIM_APPNAME=forge
export NVIM_LOG_FILE="$root/log/nvim.log" TMPDIR="$root/tmp" TEMP="$root/tmp" TMP="$root/tmp"
export GOPATH="$root/sdk-state/go" GOCACHE="$root/cache/go-build"
export npm_config_cache="$root/cache/npm" PIP_CACHE_DIR="$root/cache/pip"
# Файл создаётся installer из проверенных относительных bin directories; без eval.
forge_path=''
while IFS= read -r dir; do
  forge_path="${forge_path:+$forge_path:}$root/runtime/$dir"
done < "$root/bin/runtime-paths.txt"
PATH="$forge_path:$PATH"
export PATH
exec "$root/runtime/bin/nvim" "$@"
