#!/usr/bin/env bash
# Offline derived editor deps; the image and SDKs stay unchanged.
set -euo pipefail
work=$(mktemp -d /tmp/fride-tool-paths.XXXXXX)
export TEMP="$work" TMP="$work" TMPDIR="$work" NVIM_LOG_FILE="$work/nvim.log"
export PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1
cp -a /opt/forge/editor-deps "$work/editor-deps"
nvim -u NONE -i NONE -l nvim_forge/scripts/prepare-plugins.lua --plugin-root "$work/editor-deps/lazy" > "$work/backports.json"
python3 - "$work/editor-deps/manifest.json" "$work/backports.json" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text())
data['backports']=json.loads(pathlib.Path(sys.argv[2]).read_text())
p.write_text(json.dumps(data,indent=2)+'\n')
PY
export FORGE_E2E_DEPS="$work/editor-deps" FORGE_TEST_ID="${FORGE_TEST_ID:-IDE-BOOT-33}"
if [ "${1:-}" = --batch ]; then
  shift
  export FORGE_TEST_TMPDIR="$work" FORGE_INSTALL_STAND_ROOT="$work/install-stands"
  exec bash scripts/test.sh "$@"
fi
exec nvim -l "${1:-tests/e2e/tool-paths.test.lua}"
