"""Явный native publisher stand; приёмочный install не запускает эту сборку."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true', help='Явно разрешить upstream archives/crates/grammars')
    parser.add_argument('--work', type=Path, default=ROOT / '.tests/acceptance-installer/publisher')
    parser.add_argument('--output', type=Path)
    for name in ('nvim', 'editor-deps', 'site', 'search', 'terminal', 'frontend'):
        parser.add_argument('--' + name, type=Path, help='Переиспользовать готовый native publisher input')
    args = parser.parse_args()
    packager = module('package-acceptance-installer')
    native = packager.native_platform()
    supported=json.loads((ROOT/'scripts/sdk/terminal.json').read_text(encoding='utf-8'))['wezterm']['platforms']
    if native not in supported:
        parser.error('Full Core+Terminal stand is unavailable for '+native+'; use the separate Core publisher scripts.')
    work = args.work.resolve() / native
    output = (args.output or work / 'installer').resolve()
    if output.exists():
        parser.error('Existing installer preserved. Run its install entrypoint, or choose a new --output for rebuild.')
    if not args.frontend and not shutil.which('rustc'):
        parser.error('Publisher needs an existing Rust SDK to build frontend; user install does not. Or pass --frontend.')
    fzf_ready=False
    if args.editor_deps and (args.editor_deps/'manifest.json').is_file():
        fzf_ready=bool(json.loads((args.editor_deps/'manifest.json').read_text(encoding='utf-8')).get('native',{}).get('fzf'))
    if not fzf_ready and not shutil.which('cmake'):
        parser.error('Publisher needs CMake/C toolchain for native fzf; user install does not. Or pass prepared --editor-deps.')
    if not args.site:
        if not args.download:
            parser.error('Parser compilation requires explicit --download, or pass a prepared --site.')
        if not shutil.which('tree-sitter') or not any(shutil.which(tool) for tool in ('cc', 'clang', 'gcc', 'cl')):
            parser.error('Publisher needs tree-sitter CLI and C compiler; user install does not. Or pass --site.')
    if os.name == 'nt':
        nvim_root = (args.nvim or ROOT / '.tools/neovim/windows-x64').resolve()
        if not (nvim_root / 'forge-sdk.json').is_file():
            parser.error('Prepare the existing private Windows SDK first: scripts/prepare-windows-sdk.ps1 -Download')
    else:
        nvim_root = (args.nvim or work / 'neovim').resolve()
    work.mkdir(parents=True, exist_ok=True)
    temporary = work / 'tmp'
    temporary.mkdir(exist_ok=True)
    env = os.environ.copy()
    env.update(TEMP=str(temporary), TMP=str(temporary), TMPDIR=str(temporary), PYTHONUTF8='1',
               PYTHONDONTWRITEBYTECODE='1', NVIM_LOG_FILE=str(temporary / 'nvim.log'),
               GOMAXPROCS='2', CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2')

    def run(script, *arguments):
        print('Preparing ' + script, flush=True)
        subprocess.run([sys.executable, '-B', str(ROOT / script), *map(str, arguments)], env=env, cwd=ROOT, check=True)

    if os.name != 'nt' and not args.nvim:
        run('scripts/prepare-native-neovim.py', '--output', nvim_root, *(['--download'] if args.download else []))
    nvim = nvim_root / 'bin' / ('nvim.exe' if os.name == 'nt' else 'nvim')
    if not nvim.is_file():
        parser.error('Missing prepared native Neovim: ' + str(nvim))
    frontend = args.frontend
    if not frontend:
        run('scripts/build-installer-ui.py', '--work', work / 'frontend-build', '--output', work / 'frontend',
            *(['--download'] if args.download else []))
        frontend = work / 'frontend' / ('fride-setup.exe' if os.name == 'nt' else 'fride-setup')
    packager.frontend_receipt(frontend)
    editor = (args.editor_deps or work / 'editor-deps').resolve()
    if not args.editor_deps:
        run('tests/e2e/prepare_editor.py', '--output', editor, '--nvim', nvim,
            *(['--download'] if args.download else []))
    prepared=json.loads((editor/'manifest.json').read_text(encoding='utf-8'))
    if not prepared.get('native',{}).get('fzf'):
        run('tests/e2e/prepare_fzf.py','--editor-deps',editor,'--build-root',work/'fzf-build')
    site = (args.site or work / 'site').resolve()
    if not args.site:
        print('Preparing native parser site', flush=True)
        probe_env = env.copy()
        for key in ('HOME', 'USERPROFILE', 'LOCALAPPDATA', 'APPDATA', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            directory = work / 'parser-profile' / key
            directory.mkdir(parents=True, exist_ok=True)
            probe_env[key] = str(directory)
        for key in ('VIM', 'VIMRUNTIME', 'VIMINIT', 'EXINIT', 'LUA_INIT', 'LUA_PATH', 'LUA_CPATH', 'FORGE_NVIM_COMPONENTS', 'FRIDE_RUNTIME'):
            probe_env.pop(key, None)
        subprocess.run([str(nvim), '--headless', '-u', 'NONE', '-i', 'NONE', '-l', str(ROOT / 'scripts/prepare-parser-site.lua'),
                        str(editor / 'lazy/nvim-treesitter'), str(site)], env=probe_env, cwd=ROOT, check=True, timeout=360)
    search = (args.search or work / 'search').resolve()
    terminal = (args.terminal or work / 'terminal').resolve()
    for script, directory in (('prepare-search-runtime', search), ('prepare-terminal-runtime', terminal)):
        preparation = module(script)
        if directory.exists():
            preparation.verify(directory)
        else:
            run('scripts/' + script + '.py', '--output', directory, *(['--download'] if args.download else []))
    assets = work / 'assets'
    assets.mkdir(exist_ok=True)
    core = assets / 'core.zip'
    terminal_archive = assets / 'terminal.zip'
    run('scripts/package-core-runtime.py', '--nvim', nvim_root, '--site', site, '--editor-deps', editor,
        '--search', search, '--output', core)
    run('scripts/prepare-terminal-runtime.py', '--package', terminal, '--output', terminal_archive)
    result = packager.package(core, frontend, output, terminal_archive)
    print(json.dumps(result), flush=True)
    print('Install: ' + str(output / ('install.cmd' if os.name == 'nt' else 'install.sh')), flush=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))
