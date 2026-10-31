"""Явная подготовка pinned Go parser и gotestsum для test-runner E2E."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request

from prepare_editor import extract

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / '.tests/test-deps')
    parser.add_argument('--cc', help='Путь к C compiler (clang/gcc)')
    args = parser.parse_args()
    deps = Path(os.environ.get('FORGE_E2E_DEPS', ROOT / '.tests/editor-deps'))
    catalog = deps / 'lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua'
    if not catalog.exists():
        parser.error('Сначала выполни prepare_editor.py --download')
    match = re.search(r'\n  go = \{\s+install_info = \{\s+revision = \'([0-9a-f]+)\'', catalog.read_text(encoding='utf-8'))
    if not match:
        parser.error('Не найдена pinned Go parser revision')
    revision = match.group(1)
    source_dir = args.output / 'src' / revision
    if not source_dir.exists():
        if not args.download:
            parser.error('Нет исходников Go parser; укажи --download для явной подготовки')
        with urllib.request.urlopen('https://codeload.github.com/tree-sitter/tree-sitter-go/tar.gz/' + revision, timeout=60) as response:
            extract(response.read(), source_dir)
    source = source_dir / ('tree-sitter-go-' + revision) / 'src'
    compiler = args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
    if not compiler:
        parser.error('Нужен C compiler в PATH/CC или --cc <path>')
    target = args.output / 'site/parser/go.so'
    target.parent.mkdir(parents=True, exist_ok=True)
    build = source_dir / 'build/go.so'
    build.parent.mkdir(parents=True, exist_ok=True)
    flags = ['-O2', '-shared'] + ([] if os.name == 'nt' else ['-fPIC'])
    subprocess.run([compiler, *flags, '-I', str(source), str(source / 'parser.c'), '-o', str(build)], check=True)
    shutil.copyfile(build, target)
    nvim = shutil.which('nvim')
    if not nvim:
        parser.error('Нужен nvim для проверки parser ABI')
    lua_path = json.dumps(target.resolve().as_posix())
    code = "vim.treesitter.language.add('go',{path=" + lua_path + "}); assert(vim.treesitter.get_string_parser('package main','go'):parse()[1]:root():type()=='source_file')"
    subprocess.run([nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '+lua ' + code, '+qa'], check=True)
    suffix = '.exe' if os.name == 'nt' else ''
    sdk = Path(os.environ.get('FORGE_E2E_DAP_TOOLS', ROOT / '.tests/dap-tools')) / ('go/bin/go' + suffix)
    go = str(sdk) if sdk.exists() else shutil.which('go')
    if not go:
        parser.error('Нужен Go: сначала выполни prepare_dap.py --download')
    gotestsum = args.output / ('bin/gotestsum' + suffix)
    env = dict(os.environ, GOTOOLCHAIN='local', GOENV='off',
               GOBIN=str((args.output / 'bin').resolve()),
               GOPATH=str((args.output / 'gopath').resolve()),
               GOCACHE=str((args.output / 'build-cache').resolve()),
               GOSUMDB='sum.golang.org', GOPROXY='https://proxy.golang.org,direct')
    if not gotestsum.exists():
        if not args.download:
            parser.error('Нет gotestsum; укажи --download для явной подготовки')
        subprocess.run([go, 'install', 'gotest.tools/gotestsum@v1.13.0'], env=env, check=True)
    version = subprocess.check_output([go, 'version', '-m', str(gotestsum)], env=env, text=True)
    if not re.search(r'mod\s+gotest.tools/gotestsum\s+v1\.13\.0\s', version):
        raise RuntimeError('Unexpected gotestsum version: ' + version)
    lock = json.loads((ROOT / 'nvim_forge/lazy-lock.json').read_text(encoding='utf-8'))
    manifest = {'go_revision': revision, 'treesitter_commit': lock['nvim-treesitter']['commit'],
                'gotestsum_version': 'v1.13.0'}
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('Prepared Go parser ' + revision + ': ' + str(target))
    print('Prepared gotestsum v1.13.0: ' + str(gotestsum))


if __name__ == '__main__':
    main()
