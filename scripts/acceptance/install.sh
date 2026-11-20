#!/usr/bin/env bash
# spec: IDE-BOOT-54. Local payload; the native frontend owns installation.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
case "$(uname -s)" in Darwin) native=macos;; Linux) native=linux;; *) printf 'Use install.cmd on Windows.\n' >&2;exit 1;; esac
case "$(uname -m)" in arm64|aarch64) native="$native-arm64";; x86_64) native="$native-x64";; *) printf 'Unsupported architecture.\n' >&2;exit 1;; esac
[ "$(cat "$root/platform.txt")" = "$native" ] || { printf 'Installer belongs to another native platform.\n' >&2;exit 1; }
for argument in "$@"; do
  case "$argument" in --source|--source=*|--runtime-*|--powershell|--powershell=*) printf 'Source and runtime are provided by this installer.\n' >&2;exit 1;; esac
done
[ -z "$(find "$root/payload" -type l -print)" ] || { printf 'Linked installer payload.\n' >&2;exit 1; }
expected="$(grep -c '  payload/' "$root/payload.sha256")"
actual="$(find "$root/payload" -type f | wc -l | tr -d ' ')"
[ "$expected" = "$actual" ] || { printf 'Incomplete or unexpected installer payload.\n' >&2;exit 1; }
verify() {
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$root" && sha256sum -c payload.sha256 >/dev/null)
  else
    (cd "$root" && shasum -a 256 -c payload.sha256 >/dev/null)
  fi
}
verify || { printf 'Installer SHA256 mismatch.\n' >&2;exit 1; }
exec "$root/payload/frontend/fride-setup" --source "$root/payload/source" \
  --runtime-path "$root/payload/runtime" --log-dir "$root/logs" "$@"
