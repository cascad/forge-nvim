"""Native installed Custom Core: Files/search/Lua LSP/edit/save/restart.

Run only against an explicitly prepared kit and its OWN test profile:
python -B tests/install-core-acceptance.test.py --kit <kit> --profile <owned profile>
The profile must live below .tests (or FORGE_CORE_TEST_ROOT). No preparation
stages are replaced. The missing-plugin control temporarily moves one plugin
inside that owned profile and always restores it.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--kit', type=Path, required=True)
parser.add_argument('--profile', type=Path, required=True)
parser.add_argument('--case', choices=['all', 'workflow', 'missing'], default='all')
args = parser.parse_args()
kit, profile = args.kit.resolve(), args.profile.resolve()
owned = Path(os.environ.get('FORGE_CORE_TEST_ROOT', str(ROOT / '.tests'))).resolve()
assert profile.is_relative_to(owned) and profile != owned, 'An owned test profile is required'
assert kit.is_relative_to(owned) and (kit / '.forge-install.json').is_file(), 'A prepared owned kit is required'
marker = json.loads((kit / '.forge-install.json').read_text(encoding='utf-8'))
assert marker.get('ready') is True and marker.get('product') == 'forge-nvim' and marker.get('components') == ['core'], marker
base = owned / 'core-acceptance' / ('consumer-' + str(time.time_ns()))
base.mkdir(parents=True)
project = base / 'project'
project.mkdir()
(project / 'main.lua').write_text('---@type string\nlocal value = 123\nprint(value)\n', encoding='utf-8')
(project / 'notes.txt').write_text('notes\nFRIDE_CORE_NEEDLE\n', encoding='utf-8')
(project / '.luarc.json').write_text('{"workspace":{"checkThirdParty":false}}', encoding='utf-8')
env = os.environ.copy()
for key in ['HOME', 'USERPROFILE', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'TEMP', 'TMP', 'TMPDIR']:
    path = profile / key
    assert path.is_dir(), str(path)
    env[key] = str(path)
env.update(GIT_CONFIG_GLOBAL=str(base / 'gitconfig'), GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0')
env['PSModuleAnalysisCachePath'] = str(base / 'powershell-module-cache.bin')
(base / 'gitconfig').write_text('', encoding='utf-8')
subprocess.run(['git', 'init', '-q', str(project)], env=env, check=True, capture_output=True)
lock = kit / 'config/forge/lazy-lock.json'
lock_before = lock.read_bytes()
launch = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(kit / 'bin/fride.ps1')] if os.name == 'nt' else [str(kit / 'bin/fride')]
plugin = profile / 'XDG_DATA_HOME' / ('fride-data' if os.name == 'nt' else 'fride') / 'lazy/grug-far.nvim'
quarantine = plugin.with_name('grug-far.nvim.core-acceptance')
assert plugin.is_dir() and not quarantine.exists(), str(plugin)
assert plugin.resolve().is_relative_to(profile), 'Plugin path leaves owned profile'
print('evidence:', base, flush=True)
try:
    for round_number in ([3] if args.case == 'missing' else [1, 2] if args.case == 'workflow' else [1, 2, 3]):
        if round_number == 3: plugin.rename(quarantine)
        result = subprocess.run(launch + ['--headless', '-i', 'NONE', '-l', str(ROOT / 'tests/diagnostics/install-core-observe.lua'), str(base), str(round_number)],
                                cwd=project, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=110)
        (base / ('process-' + str(round_number) + '.json')).write_text(json.dumps({'code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}, ensure_ascii=False, indent=2), encoding='utf-8')
        assert result.returncode == 0, result.stdout + result.stderr
        assert lock.read_bytes() == lock_before, 'Ordinary launch changed lock'
        if round_number == 3: assert not plugin.exists(), 'Ordinary launch installed missing plugin'
        print('round', round_number, 'PASS', flush=True)
finally:
    if quarantine.exists() and not plugin.exists(): quarantine.rename(plugin)
print('PASS:', args.case, flush=True)
