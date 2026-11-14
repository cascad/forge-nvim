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
forge_state_path=''
while IFS=$'\t' read -r kind key relative; do
  relative="${relative%$'\r'}"
  case "$kind" in ''|'#'*) continue;; esac
  case "$kind" in
    dir|file) export "$key=$root/$relative";;
    clear) unset "$key";;
    bin) case "$key" in all|posix) forge_state_path="${forge_state_path:+$forge_state_path:}$root/$relative";; esac;;
    *) printf 'Invalid SDK environment policy kind.\n' >&2;exit 1;;
  esac
done < "$root/bin/sdk-environment.tsv"
# Файл создаётся installer из проверенных относительных bin directories; без eval.
forge_path=''
while IFS= read -r dir; do
  forge_path="${forge_path:+$forge_path:}$root/runtime/$dir"
done < "$root/bin/runtime-paths.txt"
PATH="$forge_path${forge_state_path:+:$forge_state_path}:$PATH"
export PATH
exec "$root/runtime/bin/nvim" "$@"
