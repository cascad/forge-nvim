"""spec: IDE-BOOT-30 IDE-BOOT-31. Files/search/Lua LSP/edit/save/restart.

Run only against an explicitly prepared kit and its OWN test profile:
python -B tests/install-core-acceptance.test.py --kit <kit> --profile <owned profile>
The profile must live below .tests (or FORGE_CORE_TEST_ROOT). No preparation
stages are replaced. The missing-plugin control temporarily moves one plugin
inside that owned profile and always restores it.
--editor-deps <prepared editor-deps> --runtime <native parser runtime> checks
the full source config with a native LuaLS from PATH; this mode creates its
own profile and does NOT claim installer/delivery acceptance.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
mode = parser.add_mutually_exclusive_group(required=True)
mode.add_argument('--kit', type=Path)
mode.add_argument('--editor-deps', type=Path, help='Prepared native editor inputs; checks config, NOT installation')
parser.add_argument('--runtime', type=Path, help='Native prepared runtime containing treesitter/ (source mode)')
parser.add_argument('--profile', type=Path, help='Existing owned profile (kit mode)')
parser.add_argument('--case', choices=['all', 'workflow', 'missing', 'library', 'jsonc'], default='all')
args = parser.parse_args()
owned = Path(os.environ.get('FORGE_CORE_TEST_ROOT', str(ROOT / '.tests'))).resolve()
base = owned / 'core-acceptance' / ('consumer-' + str(time.time_ns()))
base.mkdir(parents=True)
kit = args.kit.resolve() if args.kit else None
profile = args.profile.resolve() if args.profile else base / 'profile'
assert profile.is_relative_to(owned) and profile != owned, 'An owned test profile is required'
if kit:
    assert args.profile and kit.is_relative_to(owned), 'A prepared owned kit/profile is required'
    marker = json.loads((kit / '.forge-install.json').read_text(encoding='utf-8'))
    assert marker.get('ready') is True and marker.get('product') == 'forge-nvim' and marker.get('components') == ['core'], marker
project = base / 'project'
project.mkdir()
(project / 'main.lua').write_text('---@type string\nlocal value = 123\nprint(value)\n', encoding='utf-8')
(project / 'notes.txt').write_text('notes\nFRIDE_CORE_NEEDLE\n', encoding='utf-8')
(project / '.luarc.json').write_text('{"workspace":{"checkThirdParty":false}}', encoding='utf-8')
env = os.environ.copy()
for key in ['HOME', 'USERPROFILE', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'TEMP', 'TMP', 'TMPDIR']:
    path = profile / key
    if not kit: path.mkdir(parents=True, exist_ok=True)
    assert path.is_dir(), str(path)
    env[key] = str(path)
env.update(GIT_CONFIG_GLOBAL=str(base / 'gitconfig'), GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0')
env['PSModuleAnalysisCachePath'] = str(base / 'powershell-module-cache.bin')
(base / 'gitconfig').write_text('', encoding='utf-8')
subprocess.run(['git', 'init', '-q', str(project)], env=env, check=True, capture_output=True)
if kit:
    config = kit / 'config/forge'
    launch = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(kit / 'bin/fride.ps1')] if os.name == 'nt' else [str(kit / 'bin/fride')]
else:
    assert args.runtime and (args.runtime / 'treesitter/parser/lua.so').is_file(), 'Prepared native parser runtime required'
    assert not args.profile, 'Source mode creates its own profile'
    deps = args.editor_deps.resolve()
    expected = json.loads((ROOT / 'nvim_forge/lazy-lock.json').read_text(encoding='utf-8'))
    manifest = json.loads((deps / 'manifest.json').read_text(encoding='utf-8'))
    assert manifest['plugins'] == {n: pin['commit'] for n, pin in expected.items()}, 'Prepared plugins differ from source pins'
    data = profile / 'XDG_DATA_HOME' / ('fride-data' if os.name == 'nt' else 'fride')
    shutil.copytree(deps / 'lazy', data / 'lazy')
    config = profile / 'XDG_CONFIG_HOME/fride'
    names = subprocess.check_output(['git', 'ls-files', '-z', '--', 'nvim_forge'], cwd=ROOT).decode().strip('\0').split('\0')
    for name in names:
        source = ROOT / name
        if source.is_file():
            target = config / source.relative_to(ROOT / 'nvim_forge')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    env.update(NVIM_APPNAME='fride', FRIDE_CONFIG=str(config), FRIDE_RUNTIME=str(args.runtime.resolve()))
    nvim = os.environ.get('FORGE_INSTALL_TEST_NVIM', str(ROOT / '.tools/neovim/windows-x64/bin/nvim.exe') if os.name == 'nt' else shutil.which('nvim'))
    assert nvim and Path(nvim).is_file(), 'Prepared native Neovim required'
    launch = [nvim, '--cmd', 'lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)', '-u', str(config / 'init.lua')]
lock = config / 'lazy-lock.json'
lock_before = lock.read_bytes()
plugin = profile / 'XDG_DATA_HOME' / ('fride-data' if os.name == 'nt' else 'fride') / 'lazy/grug-far.nvim'
quarantine = plugin.with_name('grug-far.nvim.core-acceptance')
assert plugin.is_dir() and not quarantine.exists(), str(plugin)
assert plugin.resolve().is_relative_to(profile), 'Plugin path leaves owned profile'
print('evidence:', base, flush=True)
print('mode:', 'installed-kit' if kit else 'prepared-native-config (not installation acceptance)', flush=True)
try:
    rounds = {'all': [1, 2, 3, 4, 5], 'workflow': [1, 2], 'missing': [3], 'library': [4], 'jsonc': [5]}[args.case]
    for round_number in rounds:
        if round_number == 3: plugin.rename(quarantine)
        if round_number == 4: (project / '.luarc.json').unlink()
        if round_number == 5:
            if (project / '.luarc.json').exists(): (project / '.luarc.json').unlink()
            (project / '.luarc.jsonc').write_text('// Explicit project settings\n{"workspace":{"checkThirdParty":false}}', encoding='utf-8')
        settings = project / ('.luarc.jsonc' if round_number == 5 else '.luarc.json')
        settings_before = settings.read_bytes() if settings.exists() else None
        result = subprocess.run(launch + ['--headless', '-i', 'NONE', '-l', str(ROOT / 'tests/diagnostics/install-core-observe.lua'), str(base), str(round_number)],
                                cwd=project, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=110)
        (base / ('process-' + str(round_number) + '.json')).write_text(json.dumps({'code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}, ensure_ascii=False, indent=2), encoding='utf-8')
        assert result.returncode == 0, result.stdout + result.stderr
        assert lock.read_bytes() == lock_before, 'Ordinary launch changed lock'
        assert (settings.read_bytes() if settings.exists() else None) == settings_before, 'IDE changed project settings'
        if round_number == 3:
            assert not plugin.exists(), 'Ordinary launch installed missing plugin'
            quarantine.rename(plugin)
        print('round', round_number, 'PASS', flush=True)
finally:
    if quarantine.exists() and not plugin.exists(): quarantine.rename(plugin)
print('PASS:', args.case, flush=True)
