"""Явная pinned подготовка Node/JS tools; editor и runtime E2E ничего не устанавливают."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

from prepare_editor import extract

ROOT = Path(__file__).resolve().parents[2]
VERSION = '24.11.0'
ARCHIVES = {
    'win-x64': ('zip', '1054540bce22b54ec7e50ebc078ec5d090700a77657607a58f6a64df21f49fdd'),
    'win-arm64': ('zip', '12d3b1aa9696b7411e115a4fa2aef57f95560b5ee16bb62cd69843e535ec72be'),
    'linux-x64': ('tar.gz', 'b3c071cdf47aab867c3b2aa287257df12ec5d7c962bf922b32fd33226c4295fd'),
    'linux-arm64': ('tar.gz', '4786d00c4d259d3ff0b2328307f764ef3ced65f2d6e9502d433e68d66238509d'),
    'darwin-x64': ('tar.gz', '3884671e87f46f773832d98a0a6cabcc5ec4f637084f0f3515b69e66ea27f2f1'),
    'darwin-arm64': ('tar.gz', '0be2ab2816a4fa02d1acff014a434f29f56d8d956f5af6a98b70ced6c5f4d201'),
}
DEBUG_VERSION = '1.105.0'
DEBUG_SHA = '5c3ccc47ee77d82ba796787de452e670478d331719d9332abd49bbde8e5d479c'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download', action='store_true')
    p.add_argument('--output', type=Path, default=ROOT / '.tests/node-deps')
    p.add_argument('--nvim', default=os.environ.get('FORGE_TEST_NVIM', 'nvim'))
    p.add_argument('--cc')
    args = p.parse_args()
    out = args.output.resolve()
    if os.name == 'nt' and out.drive.lower() != ROOT.drive.lower():
        p.error('Windows temp/build/output должны оставаться на диске checkout')
    arch = 'arm64' if platform.machine().lower() in ('aarch64', 'arm64') else 'x64'
    system = 'win' if os.name == 'nt' else platform.system().lower()
    key = system + '-' + arch
    if key not in ARCHIVES:
        p.error('Неподдержанная тестовая платформа: ' + key)
    temp = out / 'tmp';temp.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp),
               npm_config_cache=str(out / 'npm-cache'), npm_config_audit='false',
               npm_config_fund='false', npm_config_update_notifier='false')
    user_config = temp / 'user.npmrc';user_config.write_text('', encoding='utf-8')
    global_config = temp / 'global.npmrc';global_config.write_text('', encoding='utf-8')
    env.update(NPM_CONFIG_USERCONFIG=str(user_config), NPM_CONFIG_GLOBALCONFIG=str(global_config))

    def fetch(url, filename, expected=None):
        target = out / 'archives' / filename
        if not target.exists():
            if not args.download:
                p.error('Нужна явная подготовка --download: ' + filename)
            target.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(url, timeout=60) as response:
                raw = response.read()
            if expected and hashlib.sha256(raw).hexdigest() != expected:
                p.error('SHA256 не совпал: ' + filename)
            target.write_bytes(raw)
        if expected and sha(target) != expected:
            p.error('SHA256 кэша не совпал: ' + filename)
        return target

    extension, sdk_sha = ARCHIVES[key]
    folder = f'node-v{VERSION}-{key}'
    name = folder + '.' + extension
    archive = fetch(f'https://nodejs.org/dist/v{VERSION}/{name}', name, sdk_sha)
    sdk = out / 'sdk' / folder
    node = sdk / ('node.exe' if os.name == 'nt' else 'bin/node')
    npm = sdk / ('node_modules/npm/bin/npm-cli.js' if os.name == 'nt' else 'lib/node_modules/npm/bin/npm-cli.js')
    if not node.exists():
        if extension == 'zip':
            with zipfile.ZipFile(archive) as source:
                for info in source.infolist():
                    target = (out / 'sdk' / info.filename).resolve()
                    if (out / 'sdk').resolve() not in (target, *target.parents):
                        p.error('Небезопасный путь SDK archive')
                source.extractall(out / 'sdk')
        else:
            # npm/npx используют относительные symlinks; POSIX сохраняет их.
            with tarfile.open(archive) as source:
                source.extractall(out / 'sdk', filter='data')
    env['PATH'] = str(node.parent) + os.pathsep + env.get('PATH', '')
    version = subprocess.check_output([str(node), '--version'], env=env, text=True).strip()
    if version != 'v' + VERSION:
        p.error('Неверный Node SDK: ' + version)
    source = ROOT / 'tests/e2e/node-tools'
    tools = out / 'tools';tools.mkdir(exist_ok=True)
    for file in ('package.json', 'package-lock.json'):
        if not (source / file).is_file():
            p.error('Нет committed tools lock: ' + file)
        shutil.copyfile(source / file, tools / file)
    lock_sha = sha(source / 'package-lock.json')
    previous = json.loads((out / 'manifest.json').read_text(encoding='utf-8')) if (out / 'manifest.json').exists() else {}
    if not (tools / 'node_modules/jest/package.json').exists() or previous.get('tools_lock_sha256') != lock_sha:
        if not args.download:
            p.error('Нужна явная подготовка npm tools --download')
        subprocess.run([str(node), str(npm), 'ci', '--ignore-scripts', '--no-audit', '--no-fund'],
                       cwd=tools, env=env, check=True)
    package = json.loads((source / 'package.json').read_text(encoding='utf-8'))
    for dependency, expected in package['dependencies'].items():
        actual = json.loads((tools / 'node_modules' / dependency / 'package.json').read_text(encoding='utf-8'))['version']
        if actual != expected:
            p.error(f'Неверная версия {dependency}: {actual}')
    debug = fetch(f'https://github.com/microsoft/vscode-js-debug/releases/download/v{DEBUG_VERSION}/js-debug-dap-v{DEBUG_VERSION}.tar.gz',
                  f'js-debug-dap-v{DEBUG_VERSION}.tar.gz', DEBUG_SHA)
    server = out / 'debug/js-debug/src/dapDebugServer.js'
    if not server.exists():
        extract(debug.read_bytes(), out / 'debug')
    deps = Path(os.environ.get('FORGE_E2E_DEPS', ROOT / '.tests/editor-deps'))
    catalog = deps / 'lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua'
    match = re.search(r'\n  javascript = \{\s+install_info = \{\s+revision = \'([0-9a-f]+)\'', catalog.read_text(encoding='utf-8'))
    if not match:
        p.error('Нет pinned JavaScript grammar; сначала prepare_editor.py')
    revision = match[1]
    grammar = fetch('https://codeload.github.com/tree-sitter/tree-sitter-javascript/tar.gz/' + revision, 'javascript-' + revision + '.tar.gz')
    sources = out / 'src' / revision
    if not sources.exists():
        extract(grammar.read_bytes(), sources)
    src = sources / ('tree-sitter-javascript-' + revision) / 'src'
    target = out / 'site/parser/javascript.so';target.parent.mkdir(parents=True, exist_ok=True)
    # Neovim ищет parser/<language>.*; linker .exp/.lib в этом каталоге
    # могут оказаться первым совпадением вместо загружаемой библиотеки.
    build = out / 'build/javascript';build.mkdir(parents=True, exist_ok=True)
    for extension in ('exp', 'lib'):
        leftover = target.with_suffix('.' + extension)
        if leftover.exists():
            shutil.move(str(leftover), str(build / leftover.name))
    cc = args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
    if not cc:
        p.error('Нужен C compiler для pinned JS parser')
    if not target.exists() or previous.get('javascript_revision') != revision:
        flags = ['-O2', '-shared'] + ([] if os.name == 'nt' else ['-fPIC'])
        compiled = build / target.name
        subprocess.run([cc, *flags, '-I', str(src), str(src / 'parser.c'), str(src / 'scanner.c'), '-o', str(compiled)], env=env, check=True)
        shutil.copyfile(compiled, target)
    lua = "vim.opt.rtp={" + json.dumps((out / 'site').as_posix()) + ",vim.env.VIMRUNTIME}; assert(#vim.api.nvim_get_runtime_file('parser/javascript.*',true)==1); vim.treesitter.language.add('javascript'); assert(vim.treesitter.get_string_parser('const answer=42','javascript'):parse()[1]:root():type()=='program')"
    subprocess.run([args.nvim, '--headless', '-u', 'NONE', '-i', 'NONE', '+lua ' + lua, '+qa'], env=env, check=True)
    manifest = {'node_version': version, 'node': node.relative_to(out).as_posix(), 'node_sha256': sha(node),
                'sdk_archive_sha256': sdk_sha, 'tools_lock_sha256': lock_sha, 'packages': package['dependencies'],
                'js_debug_version': DEBUG_VERSION, 'js_debug_archive_sha256': DEBUG_SHA,
                'js_debug_server_sha256': sha(server), 'javascript_revision': revision, 'parser_sha256': sha(target)}
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('Prepared Node/JS tools: ' + str(out), flush=True)


if __name__ == '__main__':
    main()
