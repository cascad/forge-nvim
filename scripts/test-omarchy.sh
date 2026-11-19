#!/usr/bin/env bash
# Explicit native Omarchy report; never installs packages or starts Docker/WSL.
set -euo pipefail
forge_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
forge_kit= forge_project="$PWD" forge_output= forge_versions=0 forge_quick=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --kit) forge_kit="$2"; shift 2 ;;
    --project) forge_project="$2"; shift 2 ;;
    --output) forge_output="$2"; shift 2 ;;
    --versions) forge_versions=1; shift ;;
    --quick) forge_quick=1; shift ;;
    -h|--help) printf '%s\n' 'Usage: bash scripts/test-omarchy.sh --kit DIR [--project DIR] [--output FILE] [--versions] [--quick]'; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
if [ -z "$forge_kit" ] || [ ! -f "$forge_kit/.forge-install.json" ]; then
  printf '%s\n' 'Provide --kit with an installed fride directory.' >&2; exit 2
fi
forge_kit="$(cd -- "$forge_kit" && pwd -P)"
forge_project="$(cd -- "$forge_project" && pwd -P)"
if [ -z "$forge_output" ]; then forge_output="$forge_root/.tests/omarchy/native-$(date +%Y%m%d-%H%M%S).json"; fi
case "$forge_output" in /*) ;; *) forge_output="$PWD/$forge_output" ;; esac
mkdir -p -- "$(dirname -- "$forge_output")" "$forge_root/.tests/tmp"
export TEMP="$forge_root/.tests/tmp" TMP="$forge_root/.tests/tmp" TMPDIR="$forge_root/.tests/tmp"
export NVIM_LOG_FILE="$forge_root/.tests/tmp/omarchy-report.nvim.log"
"$forge_kit/bin/fride" --headless -u NONE -i NONE -l "$forge_root/tests/diagnostics/omarchy-native-info.lua" \
  "$forge_kit" "$forge_project" "$forge_output" "$forge_versions"
printf 'Report: %s\n' "$forge_output"
if [ "$forge_quick" -eq 1 ]; then
  cd -- "$forge_root"
  "$forge_kit/runtime/bin/nvim" -u NONE -i NONE -l tests/run.lua unit trace
fi
