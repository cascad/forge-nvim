# Локальное явное обновление backports уже подготовленного editor SDK.
# При смене pins/Neovim/tools требуется основной Dockerfile.
ARG BASE_IMAGE=forge-nvim-tests:ubuntu24.04-nvim0.12.2
FROM ${BASE_IMAGE}
USER root
COPY nvim_forge/lazy-lock.json /opt/forge/nvim_forge/lazy-lock.json
COPY nvim_forge/patches/plugins.json /opt/forge/nvim_forge/patches/plugins.json
COPY nvim_forge/lua/ide/backports.lua /opt/forge/nvim_forge/lua/ide/backports.lua
COPY nvim_forge/scripts/prepare-plugins.lua /opt/forge/nvim_forge/scripts/prepare-plugins.lua
RUN python3 - <<'PY'
import hashlib, json, os, pathlib, subprocess
manifest = pathlib.Path('/opt/forge/editor-deps/manifest.json')
data = json.loads(manifest.read_text())
raw = pathlib.Path('/opt/forge/nvim_forge/lazy-lock.json').read_bytes()
lock = json.loads(raw)
assert data['plugins'] == {name: value['commit'] for name, value in lock.items()}, 'Pins changed: build the full image'
assert data['lock_sha256'] == hashlib.sha256(raw).hexdigest(), 'Lock bytes changed: build the full image'
result = subprocess.run(['nvim', '-l', '/opt/forge/nvim_forge/scripts/prepare-plugins.lua',
    '--plugin-root', '/opt/forge/editor-deps/lazy'], capture_output=True, text=True, timeout=30,
    env=dict(os.environ, NVIM_LOG_FILE='/tmp/forge-refresh.log'))
assert result.returncode == 0, result.stdout + result.stderr
data['backports'] = json.loads(result.stdout)
manifest.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
print('Prepared offline backports:', ', '.join(sorted(data['backports'])))
pathlib.Path('/tmp/forge-refresh.log').unlink(missing_ok=True)
PY
USER forge
