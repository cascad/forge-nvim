#!/usr/bin/env bash
# Единая точка входа внутри macOS/Linux VM; зависимости готовятся отдельно.
set -euo pipefail
FORGE_TEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$FORGE_TEST_ROOT"
if ! command -v nvim >/dev/null 2>&1; then
  printf 'Neovim is required. Prepare this VM before running tests.\n' >&2
  exit 2
fi
case "${1:-full}" in
  quick) set -- unit ;;
  e2e)   set -- e2e ;;
  full)  set -- unit e2e wezterm install trace ;;
  *) printf 'Usage: bash scripts/test.sh [quick|e2e|full]\n' >&2; exit 2 ;;
esac
exec nvim -l tests/run.lua "$@"
