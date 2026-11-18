# spec: IDE-BOOT-13. Bash3.2, готовый frontend без jq/Python/Rust.
forge_ui_hash() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d ' ' -f 1
  else shasum -a 256 "$1" | cut -d ' ' -f 1; fi
}
forge_installer_ui() {
  local source_dir="$1" cache_root="$2" checkout="$3" explicit="$4" platform arch ready binary expected='' url='' id link
  if [ -n "$explicit" ]; then
    [ -f "$explicit" ] && [ -x "$explicit" ] || { printf 'Installer UI not executable: %s\n' "$explicit" >&2; return 1; }
    printf '%s\n' "$explicit"; return
  fi
  case "$(uname -s)" in Linux) platform=linux;; Darwin) platform=macos;; *) printf 'Unsupported installer UI platform.\n' >&2; return 1;; esac
  case "$(uname -m)" in x86_64) arch=x64;; arm64|aarch64) arch=arm64;; *) printf 'Unsupported installer UI architecture.\n' >&2; return 1;; esac
  platform="$platform-$arch"
  if [ -f "$source_dir/installer-ui/artifacts.tsv" ]; then
    while IFS=$'\t' read -r id link expected; do
      expected="${expected%$'\r'}"
      case "$id" in ''|'#'*) continue;; esac
      if [ "$id" = "$platform" ]; then url="$link";break;fi
    done < "$source_dir/installer-ui/artifacts.tsv"
  fi
  [ -n "$url" ] || { printf 'Installer UI artifact for %s is not published. Developer preview: build with scripts/build-installer-ui.py and pass --installer-ui-path explicitly; install never runs Cargo.\n' "$platform" >&2;return 1; }
  case "$url" in https://*|http://*) ;; *) printf 'Installer UI URL must use HTTP(S).\n' >&2;return 1;; esac
  [ "${#expected}" = 64 ] || { printf 'Installer UI requires SHA256.\n' >&2;return 1; }
  case "$expected" in *[!a-f0-9]*) printf 'Installer UI requires SHA256.\n' >&2;return 1;; esac
  if [ -n "$checkout" ]; then
    ready="$checkout/.tools/installer-ui/$platform";binary="$ready/fride-setup"
    if [ -f "$binary" ] && [ -x "$binary" ] && [ "$(forge_ui_hash "$binary")" = "$expected" ]; then
      printf '%s\n' "$binary";return
    fi
  fi
  local cache="$cache_root/.ui-cache" current="$cache_root/.ui-cache" pending
  while [ -n "$current" ] && [ "$current" != / ]; do
    [ ! -L "$current" ] || { printf 'Linked UI cache: %s\n' "$current" >&2;return 1; };current="$(dirname "$current")"
  done
  mkdir -p "$cache";binary="$cache/$expected"
  [ ! -L "$binary" ] || { printf 'Linked installer UI cache file.\n' >&2;return 1; }
  if [ -f "$binary" ] && [ "$(forge_ui_hash "$binary")" = "$expected" ]; then printf '%s\n' "$binary";return;fi
  pending="$(mktemp "$cache/.download.XXXXXX")"
  if command -v curl >/dev/null 2>&1; then curl --fail --location --silent --show-error "$url" -o "$pending" || { rm -f "$pending";return 1; }
  else wget -q -O "$pending" "$url" || { rm -f "$pending";return 1; };fi
  [ "$(forge_ui_hash "$pending")" = "$expected" ] || { rm -f "$pending";printf 'Installer UI SHA256 mismatch.\n' >&2;return 1; }
  chmod +x "$pending";mv -f "$pending" "$binary";printf '%s\n' "$binary"
}
