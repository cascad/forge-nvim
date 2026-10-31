"""Явная подготовка частного Go SDK и Delve для DAP E2E; системный PATH не меняет."""
import argparse
import hashlib
import io
import os
from pathlib import Path
import platform
import subprocess
import urllib.request
import zipfile

from prepare_editor import extract

ROOT = Path(__file__).resolve().parents[2]
# Официальные checksums https://go.dev/dl/; версия фиксирована для E2E.
SHA = {
    'windows-amd64': '9bbe0fc64236b2b51f6255c05c4232532b8ecc0e6d2e00950bd3021d8a4d07d4',
    'windows-arm64': '73bdbb9f64aa152758024485c5243a1098182bb741fcc603b6fb664ee5e0fe35',
    'linux-amd64': 'aac1b08a0fb0c4e0a7c1555beb7b59180b05dfc5a3d62e40e9de90cd42f88235',
    'linux-arm64': 'bd03b743eb6eb4193ea3c3fd3956546bf0e3ca5b7076c8226334afe6b75704cd',
    'darwin-amd64': '1ca28b7703cbea05a65b2a1d92d6b308610ef92f8824578a0874f2e60c9d5a22',
    'darwin-arm64': 'b1640525dfe68f066d56f200bef7bf4dce955a1a893bd061de6754c211431023',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    if not args.download:
        parser.error('Для явной сетевой подготовки укажи --download')
    system = platform.system().lower()
    arch = {'x86_64': 'amd64', 'amd64': 'amd64', 'aarch64': 'arm64', 'arm64': 'arm64'}.get(platform.machine().lower())
    key = system + '-' + str(arch)
    if key not in SHA:
        parser.error('Не поддерживается платформа ' + key)
    output = ROOT / '.tests/dap-tools'
    output.mkdir(parents=True, exist_ok=True)
    suffix = '.exe' if system == 'windows' else ''
    go = output / ('go/bin/go' + suffix)
    if not go.exists():
        extension = '.zip' if system == 'windows' else '.tar.gz'
        with urllib.request.urlopen('https://go.dev/dl/go1.26.0.' + key + extension, timeout=60) as response:
            raw = response.read()
        if hashlib.sha256(raw).hexdigest() != SHA[key]:
            raise RuntimeError('Go archive SHA256 mismatch')
        if extension == '.zip':
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                for member in archive.infolist():
                    target = (output / member.filename).resolve()
                    if output.resolve() not in target.parents:
                        raise RuntimeError('Unsafe archive path')
                archive.extractall(output)
        else:
            # Тот же проверяющий пути extractor, что у pinned plugins.
            extract(raw, output)
    env = dict(os.environ, GOTOOLCHAIN='local', GOBIN=str(output / 'bin'),
               GOPATH=str(output / 'gopath'), GOCACHE=str(output / 'build-cache'),
               GOSUMDB='sum.golang.org', GOPROXY='https://proxy.golang.org,direct', GOENV='off')
    go_version = subprocess.check_output([str(go), 'version'], env=env, text=True)
    if not go_version.startswith('go version go1.26.0 '):
        raise RuntimeError('Unexpected SDK in .tests/dap-tools: ' + go_version)
    print(go_version.strip(), flush=True)
    dlv = output / ('bin/dlv' + suffix)
    if not dlv.exists():
        subprocess.run([str(go), 'install', 'github.com/go-delve/delve/cmd/dlv@v1.26.3'], env=env, check=True)
    dlv_version = subprocess.check_output([str(dlv), 'version'], env=env, text=True)
    if 'Version: 1.26.3' not in dlv_version:
        raise RuntimeError('Unexpected Delve in .tests/dap-tools: ' + dlv_version)
    print(dlv_version.strip(), flush=True)
    print('Prepared DAP tools: ' + str(output))


if __name__ == '__main__':
    main()
