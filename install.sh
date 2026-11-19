#!/usr/bin/env bash
# spec: IDE-BOOT-8. Доставка source; установкой пакетов владеет platform script.
set -euo pipefail

ref="${FORGE_NVIM_BRANCH:-main}"
source_root="${XDG_DATA_HOME:-$HOME/.local/share}/forge-nvim/sources"
archive_url=""
install_dir=""
runtime_path=""
runtime_url=""
runtime_sha=""
command_dir=""
ui_path=""
go_toolchain_download=""
tools_versions=""
prepare_languages=0
system_dependencies=""
original_checkout=''
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then original_checkout="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)";fi
skip_dependencies=0
profile=default
components=''
components_explicit=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ref|--archive-url|--source-root|--install-dir|--profile|--components|--runtime-path|--runtime-archive-url|--runtime-sha256|--command-dir|--installer-ui-path|--go-toolchain-download|--tools-versions|--system-deps)
      [ "$#" -ge 2 ] || { printf 'Missing value: %s\n' "$1" >&2; exit 1; }
      case "$1" in
        --ref) ref="$2";;
        --archive-url) archive_url="$2";;
        --source-root) source_root="$2";;
        --install-dir) install_dir="$2";;
        --runtime-path) runtime_path="$2";;
        --runtime-archive-url) runtime_url="$2";;
        --runtime-sha256) runtime_sha="$2";;
        --command-dir) command_dir="$2";;
        --installer-ui-path) ui_path="$2";;
        --go-toolchain-download) go_toolchain_download="$2";;
        --tools-versions) tools_versions="$2";;
        --system-deps) system_dependencies="$2";;
        --profile) profile="$2";;
        --components) components="$2"; components_explicit=1;;
      esac
      shift 2;;
    --skip-dependencies) skip_dependencies=1; shift;;
    --prepare-languages) prepare_languages=1; shift;;
    --help)
      printf '%s\n' 'forge-nvim source bootstrap (development entry)' \
        '--ref REF --archive-url URL --source-root DIR --install-dir DIR --skip-dependencies' \
        '--profile default|custom --components core,go,rust,python,node,bash,sql,terminal'
      printf '%s\n' '--runtime-path DIR (development: prepared native bundle)'
      printf '%s\n' '--command-dir DIR (optional: create fride launcher here; PATH stays unchanged)'
      printf '%s\n' '--installer-ui-path FILE (development: prepared frontend)'
      printf '%s\n' '--go-toolchain-download allow|deny (explicit native Go build policy)'
      printf '%s\n' '--tools-versions preserve|baseline (keep installed tools unless baseline reset is explicit)'
      printf '%s\n' '--prepare-languages (explicit eager SDK/tools setup; default prepares Core)'
      printf '%s\n' '--system-deps ask|install|check (native OS requirements; default ask)'
      exit 0;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1;;
  esac
done
case "$profile" in default|custom) ;; *) printf 'Unknown profile: %s\n' "$profile" >&2; exit 1;; esac
case "$go_toolchain_download" in ''|allow|deny) ;; *) printf 'Go toolchain download: allow or deny\n' >&2;exit 1;; esac
case "$tools_versions" in ''|preserve|baseline) ;; *) printf 'Tool versions: preserve or baseline\n' >&2;exit 1;; esac
case "$system_dependencies" in ''|ask|install|check) ;; *) printf 'System dependencies: ask|install|check\n' >&2;exit 1;; esac
case "$(uname -s)" in
  Linux) platform=linux;;
  Darwin) platform=macos;;
  *) printf 'Use install.ps1 on Windows; unsupported POSIX platform.\n' >&2; exit 1;;
esac
case "$ref" in ''|*[!a-zA-Z0-9._/-]*) printf 'Invalid source ref.\n' >&2; exit 1;; esac
if [ -z "$archive_url" ]; then
  archive_url="https://codeload.github.com/cascad/forge-nvim/tar.gz/$ref"
fi
case "$archive_url" in http://*|https://*) ;; *) printf 'Archive URL must use HTTP(S).\n' >&2; exit 1;; esac
mkdir -p "$source_root"
source_root="$(cd "$source_root" && pwd -P)"
staging="$(mktemp -d "$source_root/.bootstrap.XXXXXX")"
cleanup() {
  case "$staging" in "$source_root"/.bootstrap.*) rm -rf -- "$staging";; esac
}
trap cleanup EXIT
archive="$staging/source.tar.gz"
printf 'Downloading source (%s/%s): %s\n' "$platform" "$(uname -m)" "$archive_url"
if command -v curl >/dev/null 2>&1; then
  curl --fail --location --silent --show-error --output "$archive" "$archive_url"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$archive" "$archive_url"
else
  printf 'A downloader (curl or wget) is required to receive source.\n' >&2; exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  digest="$(sha256sum "$archive" | cut -d ' ' -f 1)"
else
  digest="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
fi
if ! tar -tzf "$archive" > "$staging/members"; then
  printf 'Invalid source archive.\n' >&2; exit 1
fi
# Один относительный top directory; неполный/чужой архив backend не получает.
awk -F/ '
  /^\// {exit 1}
  {if ($1 !~ /^[A-Za-z0-9_.-]+$/ || $1=="." || $1=="..") exit 1
   for(i=1;i<=NF;i++) if($i==".." || $i==".") exit 1
   if(root!="" && root!=$1) exit 1; root=$1; count++}
  END {if(count==0) exit 1}
' "$staging/members" || { printf 'Invalid source archive layout.\n' >&2; exit 1; }
mkdir "$staging/tree"
tar -xzf "$archive" -C "$staging/tree" --strip-components=1
validate_source() {
  [ -f "$1/nvim_forge/init.lua" ] &&
    [ -f "$1/scripts/install-private.sh" ] && [ -f "$1/scripts/install-private.lua" ] &&
    [ -f "$1/nvim_forge.sh" ] && [ -f "$1/wezterm.lua" ]
}
validate_source "$staging/tree" || { printf 'Archive has no complete forge-nvim source.\n' >&2; exit 1; }
source_dir="$source_root/$digest"
if [ -e "$source_dir" ]; then
  validate_source "$source_dir" || { printf 'Cached source is incomplete: %s\n' "$source_dir" >&2; exit 1; }
else
  mv "$staging/tree" "$source_dir"
fi
printf 'Source ready: %s\n' "$source_dir"
install_dir="${install_dir:-${XDG_DATA_HOME:-$HOME/.local/share}/forge-nvim/installation}"
if [ -n "$ui_path" ] || [ -f "$source_dir/installer-ui/Cargo.toml" ]; then
  . "$source_dir/scripts/lib/installer-ui.sh"
  frontend="$(forge_installer_ui "$source_dir" "$source_root" "$original_checkout" "$ui_path")"
  ui_args=(--source "$source_dir" --install-dir "$install_dir" --profile "$profile" --log-dir "$source_root/.ui-logs")
  if [ "$components_explicit" = 1 ]; then ui_args+=("--components=$components");fi
  if [ -n "$go_toolchain_download" ]; then ui_args+=(--go-toolchain-download "$go_toolchain_download");fi
  if [ -n "$tools_versions" ]; then ui_args+=(--tools-versions "$tools_versions");fi
  if [ "$prepare_languages" -eq 1 ]; then ui_args+=(--prepare-languages);fi
  if [ -n "$system_dependencies" ]; then ui_args+=(--system-deps "$system_dependencies");fi
  if [ -n "$command_dir" ]; then ui_args+=(--command-dir "$command_dir");fi
  if [ -n "$runtime_path" ]; then ui_args+=(--runtime-path "$runtime_path");fi
  if [ -n "$runtime_url" ]; then ui_args+=(--runtime-archive-url "$runtime_url" --runtime-sha256 "$runtime_sha");fi
  "$frontend" "${ui_args[@]}"
  exit "$?"
fi
[ -z "$go_toolchain_download" ] || { printf 'Go toolchain choice requires the fride setup frontend.\n' >&2;exit 1; }
[ -z "$tools_versions" ] || { printf 'Tool version choice requires the fride setup frontend.\n' >&2;exit 1; }
[ "$prepare_languages" -eq 0 ] || { printf 'Language preparation requires the fride setup frontend.\n' >&2;exit 1; }
[ -z "$system_dependencies" ] || { printf 'System dependencies choice requires the fride setup frontend.\n' >&2;exit 1; }
. "$source_dir/nvim_forge/scripts/lib/install-profile.sh"
FORGE_NVIM_COMPONENTS="$(forge_select_profile "$profile" "$components" "$components_explicit")"
export FORGE_NVIM_COMPONENTS
printf 'Selected components: %s\nStarting isolated Forge installer (%s).\n' "$FORGE_NVIM_COMPONENTS" "$platform"
FRIDE_SETUP_GO_TOOLCHAIN=local FRIDE_TOOLS_VERSIONS=preserve bash "$source_dir/scripts/install-private.sh" "$source_dir" "$install_dir" "$runtime_path" "$runtime_url" "$runtime_sha" "$command_dir"
