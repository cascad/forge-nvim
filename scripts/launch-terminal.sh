#!/usr/bin/env bash
# spec: IDE-BOOT-28. Explicit private WezTerm, never user config/PATH registration.
set -euo pipefail
script="${BASH_SOURCE[0]}"
while [ -L "$script" ]; do
  parent="$(cd -P "$(dirname "$script")" && pwd)";script="$(readlink "$script")"
  case "$script" in /*) ;; *) script="$parent/$script";; esac
done
root="$(cd -P "$(dirname "$script")/.." && pwd)"
case "$(uname -s)" in
  Darwin) binary="$root/runtime/terminal/wezterm/WezTerm.app/Contents/MacOS/wezterm";;
  *) binary="$root/runtime/terminal/wezterm/usr/bin/wezterm";;
esac
if [ ! -x "$binary" ]; then printf 'Terminal component unavailable: %s\n' "$binary" >&2;exit 1;fi
exec "$binary" --config-file "$root/config/fride-wezterm.lua" start --always-new-process --cwd "$PWD" -- "$root/bin/fride" "$@"
