"""spec: IDE-BOOT-54. Local native installer from prepared archives/current frontend."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def native_platform():
    system = {'Windows': 'windows', 'Darwin': 'macos', 'Linux': 'linux'}[platform.system()]
    arch = {'amd64': 'x64', 'x86_64': 'x64', 'arm64': 'arm64', 'aarch64': 'arm64'}.get(platform.machine().lower())
    if not arch or (system == 'windows' and arch != 'x64'):
        raise ValueError('Unsupported native installer platform')
    return system + '-' + arch


def relative(name):
    if not name or name.startswith('/') or any(c in name for c in '\\:\r\n\t') or any(p in ('', '.', '..') for p in name.split('/')):
        raise ValueError('Invalid installer member: ' + name)
    return name


def unpack(path, output, component):
    """The runtime packager materializes links; every archive file must be declared."""
    path, output = Path(path), Path(output)
    output.mkdir()
    names, keys = set(), set()
    def write(name, stream, mode):
        name = relative(name)
        key = name.lower() if os.name == 'nt' else name
        if key in keys:
            raise ValueError('Duplicate installer archive member: ' + name)
        names.add(name)
        keys.add(key)
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('wb') as destination:
            shutil.copyfileobj(stream, destination)
        target.chmod(mode & 0o777 or 0o644)
    if path.suffix == '.zip':
        with zipfile.ZipFile(path) as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                mode = entry.external_attr >> 16
                if mode & 0o170000 not in (0, 0o100000):
                    raise ValueError('Unsupported installer archive member')
                with archive.open(entry) as stream:
                    write(entry.filename, stream, mode)
    else:
        with tarfile.open(path, 'r:gz') as archive:
            for entry in archive.getmembers():
                name = entry.name.removeprefix('./')
                if entry.isdir():
                    continue
                if not entry.isfile():
                    raise ValueError('Unsupported installer archive member')
                with archive.extractfile(entry) as stream:
                    write(name, stream, entry.mode)
    manifest_name = 'forge-runtime.json' if component == 'core' else 'forge-component.json'
    manifest = json.loads((output / manifest_name).read_text(encoding='utf-8'))
    if manifest.get('schema') != 1 or manifest.get('platform') != native_platform() or manifest.get('components') != [component]:
        raise ValueError('Installer input platform/components mismatch')
    if component != 'core' and (manifest.get('kind') != 'component' or 'nvim' in manifest or 'windows_sdk' in manifest):
        raise ValueError('Invalid optional component manifest')
    files = manifest.get('files', {})
    if not files or set(files) | {manifest_name} != names:
        raise ValueError('Incomplete or unexpected archive files')
    for name, sha in files.items():
        if digest(output / relative(name)) != sha:
            raise ValueError('Installer input SHA256 mismatch: ' + name)
    return manifest


def frontend_receipt(binary):
    binary = Path(binary).resolve()
    receipt = json.loads(binary.with_name('manifest.json').read_text(encoding='utf-8'))
    if receipt.get('schema') != 1 or receipt.get('platform') != native_platform() or receipt.get('binary') != binary.name or receipt.get('sha256') != digest(binary):
        raise ValueError('Native frontend receipt mismatch')
    sources = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
               for p in (ROOT / 'installer-ui').rglob('*') if p.is_file() and 'target' not in p.relative_to(ROOT / 'installer-ui').parts}
    if receipt.get('sources') != sources:
        raise ValueError('Stale frontend; run scripts/build-installer-ui.py with a separate --output')
    return receipt


def copy_source(destination):
    names = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-z'], timeout=30).decode('utf-8').split('\0')
    selected = [name for name in names if name.startswith(('nvim_forge/', 'scripts/')) or name == 'wezterm.lua']
    for name in selected:
        relative(name)
        path = ROOT / name
        if not path.is_file() or path.is_symlink():
            raise ValueError('Missing/linked tracked source: ' + name)
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    for name in ('nvim_forge/init.lua', 'nvim_forge/scripts/components.tsv', 'scripts/install-private.lua', 'scripts/install-private.sh', 'scripts/install-private.ps1', 'wezterm.lua'):
        if not (destination / name).is_file():
            raise ValueError('Incomplete installer source: ' + name)
    return selected


def package(core, frontend, output, terminal=None):
    core, frontend, output = [Path(p).resolve() for p in (core, frontend, output)]
    if output.exists():
        raise ValueError('Existing output preserved; choose a new installer directory')
    for path in (core, frontend, Path(terminal).resolve() if terminal else core):
        if path == output or output in path.parents:
            raise ValueError('Installer output overlaps inputs')
    receipt = frontend_receipt(frontend)
    native = native_platform()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.acceptance-', dir=output.parent) as temporary:
        temporary = Path(temporary).resolve()
        assert temporary.parent == output.parent
        stage = temporary / 'installer'
        payload = stage / 'payload'
        payload.mkdir(parents=True)
        runtime = payload / 'runtime'
        manifest = unpack(core, runtime, 'core')
        expected_nvim = 'bin/nvim.exe' if os.name == 'nt' else 'bin/nvim'
        if manifest.get('nvim') != expected_nvim or expected_nvim not in manifest['files']:
            raise ValueError('Core lacks native Neovim')
        if terminal:
            part_root = temporary / 'terminal'
            part = unpack(terminal, part_root, 'terminal')
            occupied = {p.lower() if os.name == 'nt' else p for p in [*manifest['files'], 'forge-runtime.json', 'forge-component.json']}
            for name in part['files']:
                key = name.lower() if os.name == 'nt' else name
                if key in occupied or any(key.startswith(old + '/') or old.startswith(key + '/') for old in occupied):
                    raise ValueError('Runtime component conflict: ' + name)
                occupied.add(key)
                target = runtime / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(part_root / name, target)
            manifest['files'].update(part['files'])
            manifest['components'].append('terminal')
            manifest['paths'].extend(part.get('paths', []))
            manifest['probes'].extend(part.get('probes', []))
            (runtime / 'forge-runtime.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        selected = copy_source(payload / 'source')
        binary = payload / 'frontend' / frontend.name
        binary.parent.mkdir()
        shutil.copy2(frontend, binary)
        binary.chmod(0o755)
        for name in ('install.ps1', 'install.cmd') if os.name == 'nt' else ('install.sh',):
            shutil.copy2(ROOT / 'scripts/acceptance' / name, stage / name)
            (stage / name).chmod(0o755)
        (stage / 'platform.txt').write_text(native + '\n', encoding='ascii')
        source_commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
        modified=set(subprocess.check_output(['git','-C',str(ROOT),'diff','--name-only','HEAD'],text=True).splitlines())
        metadata = dict(schema=1, platform=native, source_commit=source_commit, components=manifest['components'],
                        source_worktree_dirty=bool(modified.intersection(selected)),
                        core_sha256=digest(core), frontend_sha256=receipt['sha256'], source_files=selected)
        if terminal:
            metadata['terminal_sha256'] = digest(terminal)
        (stage / 'build.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
        hashes = {p.relative_to(stage).as_posix(): digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}
        (stage / 'payload.sha256').write_text(''.join(sha + '  ' + name + '\n' for name, sha in hashes.items()), encoding='utf-8')
        stage.rename(output)
    return dict(output=str(output), platform=native, components=manifest['components'], files=len(hashes), source_commit=source_commit)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core', type=Path, required=True)
    parser.add_argument('--frontend', type=Path, required=True)
    parser.add_argument('--terminal', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(package(args.core, args.frontend, args.output, args.terminal)))
    except (ValueError, OSError, subprocess.SubprocessError, zipfile.BadZipFile, tarfile.TarError) as error:
        parser.exit(1, str(error) + '\n')
