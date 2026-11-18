#!/usr/bin/env bash
# Единая точка входа внутри macOS/Linux VM; зависимости готовятся отдельно.
set -euo pipefail
FORGE_TEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$FORGE_TEST_ROOT"
if ! command -v nvim >/dev/null 2>&1; then
  printf 'Neovim is required. Prepare this VM before running tests.\n' >&2
  exit 2
fi
forge_mode="${1:-full}"
if [ "$#" -gt 0 ]; then shift; fi
if [ "$#" -gt 0 ] || [ "$forge_mode" = regression ]; then
  exec python3 -B scripts/test-batch.py --nvim "$(command -v nvim)" --mode "$forge_mode" "$@"
fi
case "$forge_mode" in
  quick) set -- unit ;;
  e2e)   set -- e2e ;;
  full)  set -- unit e2e wezterm install trace ;;
  *) printf 'Usage: bash scripts/test.sh [quick|e2e|full|regression] [--file PATH ...] [--plan]\n' >&2; exit 2 ;;
esac
exec nvim -l tests/run.lua "$@"
