"""Явная pinned подготовка Python workflow; runtime E2E работает offline."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import sysconfig
import urllib.request

from prepare_editor import extract

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tests/e2e/python-tools'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def python_in(path):
    return path / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download', action='store_true')
    p.add_argument('--output', type=Path, default=ROOT / '.tests/python-deps')
    p.add_argument('--node-deps', type=Path, default=ROOT / '.tests/node-deps')
    p.add_argument('--nvim', default=os.environ.get('FORGE_TEST_NVIM', 'nvim'))
    p.add_argument('--cc')
    args = p.parse_args()
    if sys.version_info < (3, 10):
        p.error('Нужен host Python >=3.10; SDK устанавливается отдельно владельцем')
    out = args.output.resolve()
    if os.name == 'nt' and out.drive.lower() != ROOT.drive.lower():
        p.error('Windows output/temp/build должны оставаться на диске checkout')
    manifest_path = out / 'manifest.json'
    previous = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    locks = {name: sha(SOURCE / name) for name in ('requirements.lock', 'package-lock.json', 'sources.json')}
    identity = sys.implementation.cache_tag + '-' + sysconfig.get_platform()
    if not args.download and (previous.get('locks') != locks or previous.get('host_identity') != identity):
        p.error('Нужна явная подготовка --download для этого Python/lock')
    temp = out / 'tmp';temp.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp), PYTHONNOUSERSITE='1',
               PYTHONIOENCODING='utf-8',
               PYTHONPYCACHEPREFIX=str(out / 'pycache'),
               PIP_CONFIG_FILE=os.devnull, PIP_CACHE_DIR=str(out / 'pip-cache'), PIP_EXTRA_INDEX_URL='',
               PIP_DISABLE_PIP_VERSION_CHECK='1', npm_config_cache=str(out / 'npm-cache'))
    env.pop('PYTHONHOME', None);env.pop('PYTHONPATH', None)
    env.pop('VIRTUAL_ENV', None);env.pop('CONDA_PREFIX', None)

    def run(command, **kwargs):
        return subprocess.run([str(x) for x in command], env=env, check=True, **kwargs)

    tools_env = out / 'venvs' / identity
    tools_python = python_in(tools_env)
    wheels = out / 'wheels';wheels.mkdir(exist_ok=True)
    node_manifest = json.loads((args.node_deps / 'manifest.json').read_text(encoding='utf-8'))
    node = (args.node_deps / node_manifest['node']).resolve()
    sdk = node.parent if os.name == 'nt' else node.parent.parent
    npm = sdk / ('node_modules/npm/bin/npm-cli.js' if os.name == 'nt' else 'lib/node_modules/npm/bin/npm-cli.js')
    if not node.is_file() or not npm.is_file():
        p.error('Сначала явно подготовь Node SDK: prepare_node.py --download')
    tools = out / 'tools';tools.mkdir(exist_ok=True)
    if args.download:
        if not tools_python.is_file():
            run([sys.executable, '-m', 'venv', tools_env])
        pip = [tools_python, '-m', 'pip']
        run([*pip, 'download', '--index-url', 'https://pypi.org/simple', '--require-hashes',
             '--only-binary=:all:', '--dest', wheels, '-r', SOURCE / 'requirements.lock'])
        run([*pip, 'install', '--no-index', '--find-links', wheels, '--require-hashes',
             '-r', SOURCE / 'requirements.lock'])
        for name in ('package.json', 'package-lock.json'):
            shutil.copyfile(SOURCE / name, tools / name)
        for name in ('user', 'global'):
            config = temp / (name + '.npmrc');config.write_text('', encoding='utf-8')
            env['NPM_CONFIG_' + name.upper() + 'CONFIG'] = str(config)
        run([node, npm, 'ci', '--ignore-scripts', '--no-audit', '--no-fund'], cwd=tools)
    if not tools_python.is_file() or not (tools / 'node_modules/pyright/langserver.index.js').is_file():
        p.error('Подготовленные Python/Pyright tools отсутствуют; нужен --download')

    fixture = ROOT / 'tests/e2e/fixtures/python-language/dependency'
    fixture_sha = hashlib.sha256(b''.join(f.read_bytes() for f in sorted(fixture.rglob('*')) if f.is_file())).hexdigest()
    dependency = out / 'dependency-wheels/forge_fixture_dependency-0.1.0-py3-none-any.whl'
    if args.download:
        build = out / 'build' / ('dependency-' + fixture_sha)
        shutil.copytree(fixture, build, dirs_exist_ok=True)
        dependency.parent.mkdir(exist_ok=True)
        run([tools_python, '-m', 'pip', 'wheel', '--no-index', '--no-deps', '--no-build-isolation',
             '--wheel-dir', dependency.parent, build])
    if not dependency.is_file() or (not args.download and previous.get('dependency_source_sha256') != fixture_sha):
        p.error('Dependency wheel отсутствует/устарела; нужен --download')

    grammar = json.loads((SOURCE / 'sources.json').read_text(encoding='utf-8'))['python_grammar']
    catalog = Path(os.environ.get('FORGE_E2E_DEPS', ROOT / '.tests/editor-deps')) / 'lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua'
    revision = re.search(r"\n  python = \{\s+install_info = \{\s+revision = '([^']+)'", catalog.read_text(encoding='utf-8'))
    if not revision or revision[1] != grammar['revision']:
        p.error('Python grammar lock не соответствует pinned Treesitter')
    archive = out / 'archives' / grammar['archive']
    if not archive.is_file():
        if not args.download:
            p.error('Нет grammar archive; нужен --download')
        archive.parent.mkdir(exist_ok=True)
        with urllib.request.urlopen(grammar['url'], timeout=60) as response:
            archive.write_bytes(response.read())
    if sha(archive) != grammar['sha256']:
        p.error('Python grammar SHA256 не совпал')
    target = out / 'site/parser/python.so'
    if args.download and (not target.exists() or previous.get('grammar_archive_sha256') != grammar['sha256']):
        sources = out / 'src' / grammar['revision'];extract(archive.read_bytes(), sources)
        candidates = list(sources.glob('*/src/parser.c'));assert len(candidates) == 1
        src = candidates[0].parent
        build = out / 'build/parser';build.mkdir(parents=True, exist_ok=True)
        cc = args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
        if not cc:
            p.error('Нужен C compiler для pinned Python parser')
        compiled = build / target.name
        run([cc, '-O2', '-shared', *([] if os.name == 'nt' else ['-fPIC']), '-I', src,
             src / 'parser.c', src / 'scanner.c', '-o', compiled])
        target.parent.mkdir(parents=True, exist_ok=True);shutil.copyfile(compiled, target)
    lua = "vim.opt.rtp={" + json.dumps((out / 'site').as_posix()) + ",vim.env.VIMRUNTIME}; assert(#vim.api.nvim_get_runtime_file('parser/python.*',true)==1);vim.treesitter.language.add('python');assert(vim.treesitter.get_string_parser('answer=42','python'):parse()[1]:root():type()=='module')"
    run([args.nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '+lua ' + lua, '+qa'])
    metadata = run([tools_python, '-c', "import importlib.metadata,json,sys; print(json.dumps({'python':sys.version,'packages':{n:importlib.metadata.version(n) for n in ['pytest','debugpy','ruff','setuptools','wheel']}}))"],
                   capture_output=True, text=True)
    versions = json.loads(metadata.stdout)
    for name, expected in {'pytest':'9.2.0','debugpy':'1.8.22','ruff':'0.17.3','setuptools':'80.9.0','wheel':'0.45.1'}.items():
        if versions['packages'][name] != expected:
            p.error('Неверная версия ' + name)
    pyright = json.loads((tools / 'node_modules/pyright/package.json').read_text(encoding='utf-8'))
    if pyright['version'] != '1.1.414':
        p.error('Неверная версия Pyright')
    hashes = {str(f.relative_to(out)): sha(f) for f in [*wheels.glob('*.whl'), dependency, target, tools_python,
              tools / 'node_modules/pyright/langserver.index.js']}
    if not args.download and hashes != previous.get('files'):
        p.error('Подготовленные файлы изменились; повтори явную подготовку')
    manifest = {'host_identity':identity, 'host_python':sys.executable, 'python_version':sys.version,
                'tools_python':str(tools_python.relative_to(out)), 'locks':locks, 'files':hashes,
                'dependency_source_sha256':fixture_sha, 'grammar_archive_sha256':grammar['sha256'],
                'packages':versions['packages'], 'pyright_version':pyright['version'],
                'node':str(node), 'node_sha256':sha(node)}
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('Prepared Python workflow tools: ' + str(out), flush=True)


if __name__ == '__main__':
    main()
