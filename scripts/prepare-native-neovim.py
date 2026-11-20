"""spec: IDE-BOOT-55. Явная publisher-подготовка official POSIX Neovim, не host install."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
RECEIPT = 'fride-neovim.json'


def native_platform():
    system = {'Linux': 'linux', 'Darwin': 'macos'}.get(platform.system())
    arch = {'x86_64': 'x64', 'amd64': 'x64', 'arm64': 'arm64', 'aarch64': 'arm64'}.get(platform.machine().lower())
    if not system or not arch:
        raise ValueError('POSIX publisher requires native Linux/macOS; Windows uses prepare-windows-sdk.ps1')
    return system + '-' + arch


def source(native):
    policy = json.loads((ROOT / 'scripts/sdk/posix-neovim.json').read_text(encoding='utf-8'))
    asset = policy['platforms'][native]
    return dict(version=policy['version'], url=policy['release'] + asset['archive'], **asset)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def files(root):
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('Linked prepared Neovim file: ' + str(path))
        if path.is_file() and path != root / RECEIPT:
            result[path.relative_to(root).as_posix()] = digest(path)
    return result


def version(root):
    env = os.environ.copy()
    for key in ('VIM', 'VIMRUNTIME', 'VIMINIT', 'EXINIT', 'LUA_INIT', 'LUA_PATH', 'LUA_CPATH'):
        env.pop(key, None)
    result = subprocess.run([str(root / 'bin/nvim'), '--version'], env=env, capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=10, check=True)
    line = result.stdout.splitlines()[0]
    if line != 'NVIM v' + source(native_platform())['version']:
        raise ValueError('Unexpected native Neovim version: ' + line)
    return line


def extract(raw, output, prefix):
    """Pinned upstream tar; materialize only internal links, preserve executable modes."""
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
        links = []
        for item in archive.getmembers():
            parts = PurePosixPath(item.name).parts
            if not parts or parts[0] != prefix or any(p in ('.', '..') for p in parts) or item.name.startswith('/'):
                raise ValueError('Unexpected Neovim archive layout: ' + item.name)
            target = output.joinpath(*parts[1:])
            if not target.resolve().is_relative_to(output.resolve()):
                raise ValueError('Neovim archive path escapes output')
            if item.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif item.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(item) as stream, target.open('wb') as destination:
                    shutil.copyfileobj(stream, destination)
                target.chmod(item.mode & 0o777)
            elif item.issym() or item.islnk():
                link = (target.parent / item.linkname if item.issym() else output.parent / item.linkname).resolve()
                if not link.is_relative_to(output.resolve()):
                    raise ValueError('External Neovim archive link')
                links.append((target, link))
            else:
                raise ValueError('Unsupported Neovim archive member')
        while links:
            pending = []
            for target, link in links:
                if link.is_file():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(link, target)
                else:
                    pending.append((target, link))
            if len(pending) == len(links):
                raise ValueError('Unresolved Neovim archive links')
            links = pending


def verify(output):
    output = Path(output).resolve()
    metadata = json.loads((output / RECEIPT).read_text(encoding='utf-8'))
    native = native_platform()
    if metadata.get('schema') != 1 or metadata.get('platform') != native or metadata.get('source') != source(native):
        raise ValueError('Prepared Neovim platform/source mismatch')
    if not metadata.get('files') or metadata['files'] != files(output):
        raise ValueError('Prepared Neovim payload mismatch')
    version(output)
    return metadata


def prepare(output, archive=None, download=False):
    native = native_platform()
    output = Path(output).resolve()
    spec = source(native)
    if output.exists():
        return verify(output)
    if archive:
        raw = Path(archive).read_bytes()
    elif download:
        with urllib.request.urlopen(spec['url'], timeout=60) as response:
            raw = response.read()
    else:
        raise ValueError('Provide --archive or explicitly allow --download')
    if hashlib.sha256(raw).hexdigest() != spec['sha256']:
        raise ValueError('Official Neovim archive SHA256 mismatch')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.neovim-', dir=output.parent) as temporary:
        temporary = Path(temporary).resolve()
        assert temporary.parent == output.parent
        stage = temporary / 'payload'
        stage.mkdir()
        extract(raw, stage, spec['archive'].removesuffix('.tar.gz'))
        actual = version(stage)
        metadata = dict(schema=1, platform=native, source=spec, native_version=actual, files=files(stage))
        (stage / RECEIPT).write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
        stage.rename(output)
    return metadata


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    try:
        result = prepare(args.output, args.archive, args.download)
        print(json.dumps(dict(platform=result['platform'], version=result['native_version'], output=str(args.output))))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, str(error) + '\n')
