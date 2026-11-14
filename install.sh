#!/usr/bin/env bash
# spec: IDE-BOOT-8. Доставка source; установкой пакетов владеет platform script.
set -euo pipefail

ref="${FORGE_NVIM_BRANCH:-main}"
source_root="${XDG_DATA_HOME:-$HOME/.local/share}/forge-nvim/sources"
archive_url=""
install_dir=""
skip_dependencies=0
profile=default
components=''
components_explicit=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ref|--archive-url|--source-root|--install-dir|--profile|--components)
      [ "$#" -ge 2 ] || { printf 'Missing value: %s\n' "$1" >&2; exit 1; }
      case "$1" in
        --ref) ref="$2";;
        --archive-url) archive_url="$2";;
        --source-root) source_root="$2";;
        --install-dir) install_dir="$2";;
        --profile) profile="$2";;
        --components) components="$2"; components_explicit=1;;
      esac
      shift 2;;
    --skip-dependencies) skip_dependencies=1; shift;;
    --help)
      printf '%s\n' 'forge-nvim source bootstrap (development entry)' \
        '--ref REF --archive-url URL --source-root DIR --install-dir DIR --skip-dependencies' \
        '--profile default|custom --components core,go,rust,python,node,bash,sql,terminal'
      exit 0;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1;;
  esac
done
case "$profile" in default|custom) ;; *) printf 'Unknown profile: %s\n' "$profile" >&2; exit 1;; esac
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
    [ -f "$1/nvim_forge/scripts/install-$platform.sh" ] &&
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
. "$source_dir/nvim_forge/scripts/lib/install-profile.sh"
FORGE_NVIM_COMPONENTS="$(forge_select_profile "$profile" "$components" "$components_explicit")"
export FORGE_NVIM_COMPONENTS
printf 'Selected components: %s\nStarting %s installer.\n' "$FORGE_NVIM_COMPONENTS" "$platform"
export FORGE_NVIM_USE_LOCAL_SOURCE=1
export FORGE_NVIM_WITH_LANGUAGES="${FORGE_NVIM_WITH_LANGUAGES:-1}"
if [ -n "$install_dir" ]; then export FORGE_NVIM_INSTALL_DIR="$install_dir"; fi
if [ "$skip_dependencies" = 1 ]; then export FORGE_NVIM_SKIP_DEPS=1; fi
bash "$source_dir/nvim_forge/scripts/install-$platform.sh"
