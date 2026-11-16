"""IDE-BOOT-24: package native Neovim + prepared parser site; never build SDKs.

The supplied editor-deps must have been prepared with prepare_editor.py at the
current lazy-lock. Existing package-runtime owns the archive/manifest format.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def package(nvim_root, site, editor_deps, output):
    nvim_root, site, editor_deps, output = [Path(p).resolve() for p in (nvim_root, site, editor_deps, output)]
    for source in (nvim_root, site, editor_deps):
        if source == output or source in output.parents:
            raise ValueError('Output must be outside publisher inputs')
    system = {'Windows': 'windows', 'Linux': 'linux', 'Darwin': 'macos'}[platform.system()]
    arch = 'arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x64'
    if system == 'windows' and arch != 'x64':
        raise ValueError('Windows ARM64 Neovim is not verified')
    exe = nvim_root / 'bin' / ('nvim.exe' if system == 'windows' else 'nvim')
    version = subprocess.run([str(exe), '--version'], capture_output=True, text=True, timeout=10, check=True).stdout.splitlines()[0]
    if version != 'NVIM v0.12.2':
        raise ValueError('Unsupported native Neovim: ' + version)
    lock = json.loads((ROOT / 'nvim_forge/lazy-lock.json').read_text(encoding='utf-8'))
    prepared = json.loads((editor_deps / 'manifest.json').read_text(encoding='utf-8'))
    revision = lock['nvim-treesitter']['commit']
    if prepared.get('plugins', {}).get('nvim-treesitter') != revision:
        raise ValueError('Prepared Treesitter does not match lazy-lock')
    sdk = None
    if system == 'windows':
        sdk = json.loads((nvim_root / 'forge-sdk.json').read_text(encoding='utf-8-sig'))
        policy = json.loads((ROOT / 'scripts/sdk/windows.json').read_text())
        if not sdk.get('Ready') or sdk.get('BinarySHA256', '').lower() != digest(exe) or any(sdk.get(k) != v for k, v in policy.items() if k != 'Version'):
            raise ValueError('Windows Neovim SDK receipt/policy mismatch')
    spec = importlib.util.spec_from_file_location('core_runtime_packager', ROOT / 'scripts/package-runtime.py')
    packager = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packager)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.core-runtime-', dir=output.parent) as directory:
        temp = Path(directory)
        # Native probes get a clean, temporary Neovim profile; source sites stay read-only.
        env = os.environ.copy()
        env.update(NVIM_APPNAME='fride', HOME=str(temp / 'home'), USERPROFILE=str(temp / 'home'),
                   LOCALAPPDATA=str(temp / 'local'), NVIM_LOG_FILE=str(temp / 'nvim.log'),
                   XDG_CONFIG_HOME=str(temp / 'config'), XDG_DATA_HOME=str(temp / 'data'),
                   XDG_STATE_HOME=str(temp / 'state'), XDG_CACHE_HOME=str(temp / 'cache'))
        (temp / 'home').mkdir()
        for key in ('VIM', 'VIMRUNTIME', 'VIMINIT', 'EXINIT', 'LUA_INIT', 'LUA_PATH', 'LUA_CPATH', 'FRIDE_RUNTIME', 'FORGE_NVIM_COMPONENTS'):
            env.pop(key, None)
        plugin = editor_deps / 'lazy/nvim-treesitter'
        metadata = temp / 'parsers.json'
        result = subprocess.run([str(exe), '--headless', '-u', 'NONE', '-i', 'NONE', '-l',
                                 str(ROOT / 'scripts/inspect-parser-site.lua'), str(ROOT / 'nvim_forge'),
                                 str(plugin), str(site), str(metadata)], env=env, capture_output=True,
                                text=True, encoding='utf-8', errors='replace', timeout=30)
        if result.returncode:
            raise ValueError('Parser inventory failed: ' + result.stdout + result.stderr)
        inventory = json.loads(metadata.read_text(encoding='utf-8'))
        stage = temp / 'runtime'
        shutil.copytree(nvim_root, stage)
        owned = stage / 'treesitter'
        (owned / 'parser').mkdir(parents=True)
        (owned / 'parser-info').mkdir()
        for name, source in inventory['grammars'].items():
            shutil.copy2(site / 'parser' / (name + '.so'), owned / 'parser' / (name + '.so'))
            (owned / 'parser-info' / (name + '.revision')).write_text(source['revision'] + '\n', encoding='ascii')
        for name, source in inventory['queries'].items():
            shutil.copytree(source, owned / 'queries' / name)
        inventory['queries'] = sorted(inventory['queries'])
        inventory.update(schema=1, platform=system + '-' + arch, treesitter_revision=revision,
                         treesitter_parsers_sha256=digest(plugin / 'lua/nvim-treesitter/parsers.lua'))
        inventory['files'] = {p.relative_to(owned).as_posix(): digest(p) for p in sorted(owned.rglob('*')) if p.is_file()}
        (owned / 'prepared.json').write_text(json.dumps(inventory, indent=2) + '\n', encoding='utf-8')
        env['FRIDE_RUNTIME'] = str(stage)
        probe = temp / 'check.lua'
        probe.write_text("package.path=vim.env.FORGE_CORE_CONFIG..'/lua/?.lua;'..package.path\n"
                         "vim.opt.rtp:prepend(vim.env.FRIDE_RUNTIME..'/treesitter')\n"
                         "require('forge.parser_runtime').check(require('forge.tool_catalog').parsers())\n", encoding='utf-8')
        env['FORGE_CORE_CONFIG'] = str(ROOT / 'nvim_forge')
        result = subprocess.run([str(exe), '--headless', '-u', 'NONE', '-i', 'NONE', '-l', str(probe)],
                                env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
        if result.returncode:
            raise ValueError('Native parser probe failed: ' + result.stdout + result.stderr)
        recipe = {'schema': 1, 'platform': system + '-' + arch, 'nvim': 'bin/' + exe.name,
                  'components': ['core'], 'paths': ['bin'], 'probes': [['bin/' + exe.name, '--version']]}
        if sdk:
            recipe['windows_sdk'] = sdk
        recipe_file = temp / 'recipe.json'
        recipe_file.write_text(json.dumps(recipe), encoding='utf-8')
        return packager.package(stage, recipe_file, output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nvim', required=True, type=Path)
    parser.add_argument('--site', required=True, type=Path)
    parser.add_argument('--editor-deps', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(package(args.nvim, args.site, args.editor_deps, args.output), indent=2))
