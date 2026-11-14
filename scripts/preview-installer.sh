#!/usr/bin/env bash
# Безопасный preview того же native frontend. Backend не запускается.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
. "$root/scripts/lib/installer-ui.sh"
binary="$(forge_installer_ui "$root" "$root/.tests/installer-ui/cache" "$root" '')"
exec "$binary" --preview --source "$root" "$@"
