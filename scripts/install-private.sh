#!/usr/bin/env bash
# spec: IDE-BOOT-11. POSIX bootstrap использует только подготовленный private SDK.
set -euo pipefail
source_dir="$1"; install_dir="$2"; runtime="${3:-}"
url="${4:-}"; expected="${5:-}"
hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d ' ' -f 1
  else shasum -a 256 "$1" | cut -d ' ' -f 1; fi
}
if [ -n "$runtime" ] && [ -n "$url" ]; then printf 'Choose runtime path or URL.\n' >&2; exit 1; fi
if [ -n "$url" ]; then
  case "$url" in http://*|https://*) ;; *) printf 'Runtime URL must use HTTP(S).\n' >&2; exit 1;; esac
  [ "${#expected}" = 64 ] || { printf 'Runtime archive requires SHA256.\n' >&2; exit 1; }
  case "$expected" in *[!a-f0-9]*) printf 'Runtime SHA256 must use lowercase hex.\n' >&2; exit 1;; esac
  cache="$(dirname "$source_dir")/.runtime-cache/$expected"
  if [ ! -d "$cache" ]; then
    mkdir -p "$(dirname "$cache")"
    stage="$(mktemp -d "$cache.stage.XXXXXX")"
    trap 'rm -rf -- "$stage"' EXIT
    if command -v curl >/dev/null 2>&1; then curl --fail --location "$url" -o "$stage/runtime.tar.gz"
    else wget -O "$stage/runtime.tar.gz" "$url"; fi
    [ "$(hash_file "$stage/runtime.tar.gz")" = "$expected" ] || { printf 'Runtime archive SHA256 mismatch.\n' >&2; exit 1; }
    tar -tzf "$stage/runtime.tar.gz" > "$stage/names"
    while IFS= read -r name; do
      case "$name" in /*|..|../*|*/../*|*/..) printf 'Unsafe runtime archive entry.\n' >&2; exit 1;; esac
    done < "$stage/names"
    # Bundle writer materialize links; extraction никогда не создаёт ссылки/devices.
    tar -tvzf "$stage/runtime.tar.gz" > "$stage/types"
    while IFS= read -r entry; do
      case "$entry" in d*|-*) ;; *) printf 'Unsupported runtime archive entry.\n' >&2; exit 1;; esac
    done < "$stage/types"
    mkdir "$stage/unpacked"
    tar -xzf "$stage/runtime.tar.gz" -C "$stage/unpacked"
    mv "$stage/unpacked" "$cache"
    rm -rf -- "$stage"; trap - EXIT
  fi
  runtime="$cache"
fi
if [ -z "$runtime" ]; then
  printf '%s\n' 'Prepared private runtime is unavailable. IDE-138 release bundles are not published yet; development stand: --runtime-path <prepared bundle>. System Neovim and packages were not changed.' >&2
  exit 1
fi
runtime="$(cd "$runtime" && pwd -P)"
# Нормализованный bundle contract: POSIX executable всегда bin/nvim.
[ -f "$runtime/forge-runtime.json" ] && [ -x "$runtime/bin/nvim" ] || { printf 'Incomplete private runtime.\n' >&2; exit 1; }
[ -f "$runtime/nvim.sha256" ] && [ "$(hash_file "$runtime/bin/nvim")" = "$(cat "$runtime/nvim.sha256")" ] || { printf 'Runtime Neovim SHA256 mismatch.\n' >&2; exit 1; }
unset VIM VIMRUNTIME VIMINIT EXINIT LUA_INIT LUA_PATH LUA_CPATH
export FORGE_INSTALL_SOURCE="$source_dir" FORGE_INSTALL_TARGET="$install_dir" FORGE_INSTALL_RUNTIME="$runtime"
work="$(mktemp -d "$(dirname "$source_dir")/.installer.XXXXXX")"
mkdir "$work/tmp"
export XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data"
export XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" NVIM_APPNAME=forge-bootstrap
export NVIM_LOG_FILE="$work/nvim.log" TEMP="$work/tmp" TMP="$work/tmp" TMPDIR="$work/tmp"
exec "$runtime/bin/nvim" --headless -u NONE -i NONE -l "$source_dir/scripts/install-private.lua"
