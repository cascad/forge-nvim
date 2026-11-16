"""IDE-BOOT-25: full native editor on a long Unicode path, no SDK installation.

Uses existing prepared editor-deps and the existing native editor harness.
"""
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
system = {'Windows': 'windows', 'Linux': 'linux', 'Darwin': 'macos'}[platform.system()]
run = ROOT / '.tests/lua-cache' / (system + '-' + str(time.time_ns()))
run.mkdir(parents=True)
nvim = os.environ.get('FORGE_INSTALL_TEST_NVIM', str(ROOT / '.tools/neovim/windows-x64/bin/nvim.exe') if os.name == 'nt' else shutil.which('nvim'))
assert nvim and Path(nvim).is_file(), 'Prepared native Neovim required'
env = os.environ.copy()
base = Path(env.get('FORGE_LUA_CACHE_TMP', str(ROOT / '.tests/tmp' if os.name == 'nt' else '/tmp'))) / 'fride проект с пробелами для проверки загрузки'
base.mkdir(parents=True, exist_ok=True)
env.update(FORGE_TEST_TMPDIR=str(base), FORGE_LUA_CACHE_REPORT=str(run / 'report.json'),
           NVIM_LOG_FILE=str(run / 'driver.log'), PYTHONUTF8='1', PYTHONDONTWRITEBYTECODE='1')
result = subprocess.run([nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '-l', str(ROOT / 'tests/diagnostics/lua-cache-e2e.lua')],
                        cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=100)
(run / 'process.json').write_text(json.dumps({'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}, ensure_ascii=False, indent=2), encoding='utf-8')
print('evidence:', run, flush=True)
print(result.stdout + result.stderr, flush=True)
if (run / 'report.json').exists():
    print((run / 'report.json').read_text(encoding='utf-8'), flush=True)
raise SystemExit(result.returncode)
