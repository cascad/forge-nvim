"""Явная подготовка Rust E2E; host SDK не устанавливается и не обновляется."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import urllib.error
import urllib.request
import zipfile

from prepare_editor import extract

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tests/e2e/rust-tools/sources.json'


def sha(path):
    with Path(path).open('rb') as source:
        digest = hashlib.sha256()
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
        return digest.hexdigest()


def unpack(archive, destination):
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as source:
            for entry in source.infolist():
                target = (destination / entry.filename).resolve()
                if destination.resolve() not in (target, *target.parents):
                    raise RuntimeError('Небезопасный путь архива: ' + entry.filename)
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(entry) as data, target.open('wb') as out:
                        shutil.copyfileobj(data, out)
                    if os.name != 'nt' and entry.external_attr >> 16 & 0o111:
                        target.chmod(0o755)
    else:
        extract(archive.read_bytes(), destination)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download', action='store_true')
    p.add_argument('--output', type=Path, default=ROOT / '.tests/rust-deps')
    p.add_argument('--rustc', help='Настоящий rustc или установленный rustup shim')
    p.add_argument('--nvim', default=os.environ.get('FORGE_TEST_NVIM', 'nvim'))
    p.add_argument('--cc')
    args = p.parse_args()
    out = args.output.resolve()
    if os.name == 'nt' and out.drive.lower() != ROOT.drive.lower():
        p.error('Windows output/temp/build должны оставаться на диске checkout')
    sources = json.loads(SOURCE.read_text(encoding='utf-8'))
    arch = 'arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x64'
    key = ('win32' if os.name == 'nt' else platform.system().lower()) + '-' + arch
    if key not in sources['platforms']:
        p.error('Нет pinned Rust E2E tools для платформы ' + key)
    temp = out / 'tmp'
    if args.download:
        temp.mkdir(parents=True, exist_ok=True)
    elif not temp.is_dir():
        p.error('Нужна явная подготовка --download: отсутствует tmp/manifest')
    env = dict(os.environ, TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp),
               CARGO_HOME=str(out / 'cargo-home'), CARGO_NET_OFFLINE='true',
               CARGO_BUILD_JOBS='2', RUSTUP_AUTO_INSTALL='0')

    def run(command, **kwargs):
        if kwargs.get('text'):
            kwargs.setdefault('encoding', 'utf-8')
        return subprocess.run([str(x) for x in command], env=env, check=True, **kwargs)

    candidate = args.rustc or shutil.which('rustc')
    if not candidate:
        p.error('Нужен установленный host Rust SDK; автоматической установки нет')
    sysroot = Path(run([candidate, '--print', 'sysroot'], capture_output=True, text=True).stdout.strip())
    suffix = '.exe' if os.name == 'nt' else ''
    binaries = {name: sysroot / 'bin' / (name + suffix) for name in
                ['rustc', 'cargo', 'rust-analyzer', 'rustfmt', 'cargo-clippy', 'clippy-driver']}
    for name, path in binaries.items():
        if not path.is_file():
            p.error('В host SDK отсутствует ' + name + '; подготовь компонент явно')
    if not (sysroot / 'lib/rustlib/src/rust/library/std/src/lib.rs').is_file():
        p.error('Нужен установленный rust-src: rustup component add rust-src')
    env['PATH'] = str(sysroot / 'bin') + os.pathsep + env['PATH']
    versions = {name: run([path, '--version'], capture_output=True, text=True).stdout.strip()
                for name, path in binaries.items() if name != 'clippy-driver'}
    host = run([binaries['rustc'], '--version', '--verbose'], capture_output=True, text=True).stdout.strip()
    manifest_path = out / 'manifest.json'
    previous = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.is_file() else {}
    if not args.download and (previous.get('sources_sha256') != sha(SOURCE) or previous.get('rustc_verbose') != host):
        p.error('Нужна явная подготовка --download для этого SDK/lock')

    def fetch(source):
        archive = out / 'archives' / source['archive']
        if not archive.is_file():
            if not args.download:
                p.error('Нужна явная подготовка --download: ' + source['archive'])
            archive.parent.mkdir(parents=True, exist_ok=True)
            print('Download ' + source['archive'], flush=True)
            partial = archive.with_suffix(archive.suffix + '.part')
            for attempt in range(3):
                # Другая cache key официального asset помогает при CDN 5xx;
                # payload всё равно принимается только по закреплённому SHA.
                url = source['url'] + ('?download=' + str(attempt) if attempt else '')
                request = urllib.request.Request(url, headers={'User-Agent': 'forge-nvim-e2e'})
                try:
                    with urllib.request.urlopen(request, timeout=60) as response, partial.open('wb') as output:
                        shutil.copyfileobj(response, output)
                    break
                except urllib.error.HTTPError as error:
                    if error.code < 500 or attempt == 2:
                        raise
                    print('Retry official archive after HTTP ' + str(error.code), flush=True)
            partial.replace(archive)
        if sha(archive) != source['sha256']:
            p.error('SHA256 не совпал: ' + str(archive))
        return archive

    for name in ['nextest', 'codelldb']:
        archive = fetch(sources['platforms'][key][name])
        destination = out / name
        if args.download:
            unpack(archive, destination)
    nextest = out / 'nextest' / ('cargo-nextest' + suffix)
    adapter = out / 'codelldb/extension/adapter' / ('codelldb' + suffix)
    if not nextest.is_file() or not adapter.is_file():
        p.error('Отсутствуют подготовленные nextest/CodeLLDB; нужен --download')
    if os.name != 'nt' and args.download:
        nextest.chmod(0o755)
        adapter.chmod(0o755)
    nextest_version = run([nextest, '--version'], capture_output=True, text=True).stdout.strip()
    if not nextest_version.startswith('cargo-nextest ' + sources['nextest_version']):
        p.error('Неверная версия nextest: ' + nextest_version)
    package = json.loads((out / 'codelldb/extension/package.json').read_text(encoding='utf-8'))
    if package['version'] != sources['codelldb_version']:
        p.error('Неверная версия CodeLLDB')

    grammar = sources['rust_grammar']
    catalog = Path(os.environ.get('FORGE_E2E_DEPS', ROOT / '.tests/editor-deps')) / 'lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua'
    revision = re.search(r"\n  rust = \{\s+install_info = \{\s+revision = '([^']+)'", catalog.read_text(encoding='utf-8'))
    if not revision or revision[1] != grammar['revision']:
        p.error('Rust grammar не соответствует pinned Treesitter')
    archive = fetch(grammar)
    target = out / 'site/parser/rust.so'
    if args.download:
        destination = out / 'src' / grammar['revision']
        unpack(archive, destination)
        src = next(destination.glob('*/src/parser.c')).parent
        cc = args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
        if not cc:
            p.error('Нужен C compiler для pinned Rust parser')
        build = out / 'build/parser'
        build.mkdir(parents=True, exist_ok=True)
        compiled = build / target.name
        run([cc, '-O2', '-shared', *([] if os.name == 'nt' else ['-fPIC']), '-I', src,
             src / 'parser.c', src / 'scanner.c', '-o', compiled])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(compiled, target)
    lua = 'vim.opt.rtp={' + json.dumps((out / 'site').as_posix()) + ",vim.env.VIMRUNTIME};assert(#vim.api.nvim_get_runtime_file('parser/rust.*',true)==1);vim.treesitter.language.add('rust');assert(vim.treesitter.get_string_parser('fn main() {}','rust'):parse()[1]:root():type()=='source_file')"
    run([args.nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '+lua ' + lua, '+qa'])
    probe = out / 'build/probe'
    exe = probe / ('probe' + suffix)
    if args.download:
        probe.mkdir(parents=True, exist_ok=True)
        (probe / 'main.rs').write_text('fn main(){println!("FORGE_RUST_SDK_OK");}\n', encoding='utf-8')
        run([binaries['rustc'], probe / 'main.rs', '-o', exe])
    elif not exe.is_file():
        p.error('Отсутствует SDK compile probe; нужен --download')
    assert run([exe], capture_output=True, text=True).stdout.strip() == 'FORGE_RUST_SDK_OK'
    hashes = {str(f.relative_to(out)): sha(f) for f in [nextest, target, exe, probe / 'main.rs', *sorted((out / 'codelldb/extension').rglob('*'))]
              if f.is_file() and '__pycache__' not in f.parts}
    host_hashes = {str(path): sha(path) for path in binaries.values()}
    if not args.download and (hashes != previous.get('files') or host_hashes != previous.get('host_files')):
        p.error('Подготовленные Rust/host files изменились; повтори явную подготовку')
    manifest = {'platform': key, 'sources_sha256': sha(SOURCE), 'sysroot': str(sysroot),
                'versions': versions, 'rustc_verbose': host, 'host_files': host_hashes,
                'files': hashes, 'nextest_version': nextest_version, 'codelldb_version': package['version']}
    if args.download:
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('Prepared Rust workflow tools: ' + str(out), flush=True)


if __name__ == '__main__':
    main()
