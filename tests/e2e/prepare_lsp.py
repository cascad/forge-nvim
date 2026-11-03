"""Явная подготовка Go LSP/format E2E; запуск теста инструменты не устанавливает."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
TOOLS = {
    'gopls': ('golang.org/x/tools/gopls', 'v0.23.0', 'bin'),
    'gofumpt': ('mvdan.cc/gofumpt', 'v0.9.2', 'format-bin'),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / '.tests/lsp-deps')
    parser.add_argument('--go', help='Явный путь к подготовленному Go 1.26.0')
    args = parser.parse_args()
    output = args.output.resolve()
    if os.name == 'nt' and output.drive.lower() != ROOT.drive.lower():
        parser.error('Windows output/temp/build должны оставаться на диске checkout')
    suffix = '.exe' if os.name == 'nt' else ''
    sdk = Path(os.environ.get('FORGE_E2E_DAP_TOOLS', ROOT / '.tests/dap-tools')) / ('go/bin/go' + suffix)
    go = args.go or (str(sdk) if sdk.is_file() else shutil.which('go'))
    if not go:
        parser.error('Нужен Go 1.26.0; явно выполни prepare_dap.py --download')
    temp = output / 'tmp'
    temp.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, GOTOOLCHAIN='local', GOENV='off', CGO_ENABLED='0',
               GOMAXPROCS='2', GOMEMLIMIT='512MiB', GOTELEMETRY='off',
               GOPATH=str(output / 'gopath'), GOMODCACHE=str(output / 'gopath/pkg/mod'),
               GOCACHE=str(output / 'build-cache'), TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp),
               GOSUMDB='sum.golang.org', GOPROXY='https://proxy.golang.org,direct')
    go_version = subprocess.check_output([go, 'version'], env=env, text=True).strip()
    if not go_version.startswith('go version go1.26.0 '):
        parser.error('Для воспроизводимой подготовки нужен Go 1.26.0: ' + go_version)
    manifest_file = output / 'manifest.json'
    previous = json.loads(manifest_file.read_text(encoding='utf-8')) if manifest_file.exists() else {}
    manifest = {'go_version': go_version, 'tools': {}}
    for name, (module, version, folder) in TOOLS.items():
        target = output / folder / (name + suffix)
        target.parent.mkdir(parents=True, exist_ok=True)
        old = previous.get('tools', {}).get(name, {})
        changed = target.exists() and old.get('sha256') and hashlib.sha256(target.read_bytes()).hexdigest() != old['sha256']
        if not target.exists() or changed:
            if not args.download:
                parser.error(f'{name} отсутствует/изменён; явно выполни prepare_lsp.py --download')
            build_env = dict(env, GOBIN=str(target.parent))
            subprocess.run([go, 'install', '-p', '2', module + '@' + version], env=build_env, check=True)
        metadata = subprocess.check_output([go, 'version', '-m', str(target)], env=env, text=True)
        if not re.search(r'\bmod\s+' + re.escape(module) + r'\s+' + re.escape(version) + r'\s', metadata):
            parser.error(f'Неверная версия {name} в {target}: {metadata}')
        if not re.search(r': go1\.26\.0$', metadata.splitlines()[0]):
            parser.error(f'{name} собран другим Go: {metadata.splitlines()[0]}')
        manifest['tools'][name] = {'module': module, 'version': version,
                                   'path': target.relative_to(output).as_posix(),
                                   'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                                   'build_info': metadata}
        print(f'Prepared {name} {version}: {target}', flush=True)
    manifest_file.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
