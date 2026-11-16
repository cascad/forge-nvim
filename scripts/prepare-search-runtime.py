"""IDE-BOOT-26: publisher preparation of pinned ripgrep, not a host installer."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def native_platform():
    system = {'Windows': 'windows', 'Linux': 'linux', 'Darwin': 'macos'}[platform.system()]
    arch = {'amd64': 'x64', 'x86_64': 'x64', 'arm64': 'arm64', 'aarch64': 'arm64'}.get(platform.machine().lower())
    if not arch:
        raise ValueError('Unsupported native architecture')
    return system + '-' + arch


def source(native):
    policy = json.loads((ROOT / 'scripts/sdk/ripgrep.json').read_text(encoding='utf-8'))
    asset = policy['platforms'][native]
    stem = 'ripgrep-' + policy['version'] + '-' + asset['target']
    name = stem + ('.zip' if native.startswith('windows-') else '.tar.gz')
    return policy, {'archive': name, 'url': 'https://github.com/BurntSushi/ripgrep/releases/download/' + policy['version'] + '/' + name,
                    'sha256': asset['sha256'], 'prefix': stem + '/'}


def payload(raw, native):
    policy, spec = source(native)
    if hashlib.sha256(raw).hexdigest() != spec['sha256']:
        raise ValueError('Ripgrep archive SHA mismatch')
    binary = 'rg.exe' if native.startswith('windows-') else 'rg'
    files = {'bin/' + binary: binary, **{'licenses/' + name: name for name in ('COPYING', 'LICENSE-MIT', 'UNLICENSE')}}
    result = {}
    if native.startswith('windows-'):
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            for name, member in files.items():
                result[name] = archive.read(spec['prefix'] + member)
    else:
        with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
            for name, member in files.items():
                entry = archive.getmember(spec['prefix'] + member)
                if not entry.isfile():
                    raise ValueError('Ripgrep asset member is not a file: ' + member)
                result[name] = archive.extractfile(entry).read()
    return result


def version(binary, expected):
    result = subprocess.run([str(binary), '--version'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=5)
    line = (result.stdout + result.stderr).splitlines()[0] if result.stdout or result.stderr else ''
    if result.returncode or line.split()[:2] != ['ripgrep', expected]:
        raise ValueError('Unexpected native ripgrep version: ' + line)
    return line


def verify(directory, native=None):
    directory = Path(directory).resolve()
    native = native or native_platform()
    policy, spec = source(native)
    meta = json.loads((directory / 'prepared.json').read_text(encoding='utf-8'))
    if meta.get('schema') != 1 or meta.get('platform') != native or meta.get('version') != policy['version'] or meta.get('source') != spec:
        raise ValueError('Ripgrep native manifest/policy mismatch')
    if json.loads((directory / 'search/prepared.json').read_text(encoding='utf-8')) != meta:
        raise ValueError('Ripgrep delivered metadata mismatch')
    files = payload((directory / 'sources' / spec['archive']).read_bytes(), native)
    expected = {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
    if meta.get('files') != expected:
        raise ValueError('Ripgrep manifest differs from official payload')
    for name, sha in expected.items():
        path = directory / 'search' / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != sha:
            raise ValueError('Ripgrep payload SHA mismatch: ' + name)
    binary = directory / 'search/bin' / ('rg.exe' if native.startswith('windows-') else 'rg')
    if not os.access(binary, os.X_OK):
        raise ValueError('Ripgrep binary is not executable')
    version(binary, policy['version'])
    return meta


def prepare(output, archive=None, download=False):
    output = Path(output).resolve()
    native = native_platform()
    policy, spec = source(native)
    if archive:
        raw = Path(archive).read_bytes()
    elif download:
        with urllib.request.urlopen(spec['url'], timeout=60) as response:
            raw = response.read()
    else:
        raise ValueError('Provide an archive or explicitly allow --download')
    files = payload(raw, native)
    if output.exists():
        return verify(output, native)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.search-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'prepared'
        for name, data in files.items():
            path = stage / 'search' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if name.startswith('bin/'):
                path.chmod(0o755)
        source_dir = stage / 'sources'
        source_dir.mkdir()
        (source_dir / spec['archive']).write_bytes(raw)
        binary = stage / 'search/bin' / ('rg.exe' if native.startswith('windows-') else 'rg')
        actual = version(binary, policy['version'])
        meta = {'schema': 1, 'platform': native, 'version': policy['version'], 'native_version': actual,
                'license': policy['license'], 'source': spec,
                'files': {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
        (stage / 'prepared.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
        (stage / 'search/prepared.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
        stage.rename(output)
    return meta


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    print(json.dumps(prepare(args.output, args.archive, args.download), indent=2))
