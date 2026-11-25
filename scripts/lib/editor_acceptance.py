"""Prepare and check the dependencies of the editor acceptance suite."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
SUFFIX = '.exe' if os.name == 'nt' else ''

# Also the order of preparation. The language tools consume the pinned parser
# catalog and Python/Bash preparation consumes the prepared Node SDK.
DEPENDENCIES = (
    ('editor', 'FORGE_E2E_DEPS', ('manifest.json',)),
    ('dap', 'FORGE_E2E_DAP_TOOLS', ()),
    ('tests', 'FORGE_E2E_TEST_DEPS', ('manifest.json', 'site/parser/go.so', 'bin/gotestsum' + SUFFIX)),
    ('lsp', 'FORGE_E2E_LSP_DEPS', ('manifest.json', 'bin/gopls' + SUFFIX, 'format-bin/gofumpt' + SUFFIX)),
    ('node', 'FORGE_E2E_NODE_DEPS', ('manifest.json', 'site/parser/javascript.so')),
    ('python', 'FORGE_E2E_PYTHON_DEPS', ('manifest.json', 'site/parser/python.so')),
    ('rust', 'FORGE_E2E_RUST_DEPS', ('manifest.json', 'site/parser/rust.so')),
    ('bash', 'FORGE_E2E_BASH_DEPS', ('manifest.json', 'site/parser/bash.so')),
    ('sql', 'FORGE_E2E_SQL_DEPS', ('manifest.json', 'site/parser/sql.so', 'bin/sqruff' + SUFFIX)),
    ('bash_dap', 'FORGE_E2E_BASH_DAP_DEPS', ('manifest.json', 'extension/out/bashDebug.js')),
)


def directory(name, variable, env):
    default = {'dap': 'dap-tools', 'tests': 'test-deps'}.get(name, name.replace('_', '-') + '-deps')
    return Path(env.get(variable) or ROOT / '.tests' / default)


def host_inputs(env, prepare):
    missing = [f'{name} is required in PATH' for name in ('git', 'rg')
               if not shutil.which(name, path=env['PATH'])]
    if sys.platform == 'darwin':
        debug_bash = env.get('FORGE_BASH_DEBUG_BASH') or next(
            (path for path in ('/opt/homebrew/bin/bash', '/usr/local/bin/bash') if os.access(path, os.X_OK)), None)
        bash = shutil.which(debug_bash or env.get('FORGE_BASH_EXECUTABLE') or 'bash', path=env['PATH'])
        result = None
        if bash:
            try:
                result = subprocess.run([bash, '--noprofile', '--norc', '-c', '(( BASH_VERSINFO[0] >= 4 ))'],
                                        env=dict(env, BASH_ENV='', ENV=''), capture_output=True, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        if not result or result.returncode:
            missing.append('Bash 4+ is required for Bash debug on macOS. Install it or set FORGE_BASH_DEBUG_BASH.')
    if prepare:
        if not hasattr(tarfile, 'data_filter'):
            missing.append('Use Python 3.12+ or an updated Python with tarfile.data_filter.')
        if not any(shutil.which(name, path=env['PATH']) for name in (env.get('CC') or 'cc', 'clang', 'gcc')):
            missing.append('A C compiler is required to prepare test parsers. On macOS, install Xcode Command Line Tools.')
        if not env.get('FORGE_E2E_RUST_DEPS') and not shutil.which('rustc', path=env['PATH']):
            missing.append('A host Rust SDK is required. Put rustc in PATH and prepare rust-analyzer, rustfmt, clippy and rust-src.')
    return missing


def prepared_inputs(env, nvim):
    missing = []
    for name, variable, files in DEPENDENCIES:
        base = directory(name, variable, env)
        absent = [file for file in files if not (base / file).is_file()]
        if absent:
            missing.append(f'{base}: missing {", ".join(absent)} ({variable})')
        if name == 'dap':
            path = env['PATH']
            if (base / 'go/bin').is_dir():
                path = os.pathsep.join((str(base / 'go/bin'), str(base / 'bin'), path))
            missing.extend(f'{tool} is required in {base} or PATH' for tool in ('go', 'dlv')
                           if not shutil.which(tool, path=path))
        if name == 'editor' and not absent:
            try:
                manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
                lock = json.loads((ROOT / 'nvim_forge/lazy-lock.json').read_text(encoding='utf-8'))
                pins = {plugin: spec['commit'] for plugin, spec in lock.items()}
                if manifest.get('plugins') != pins:
                    missing.append(f'{base}: prepared plugins do not match lazy-lock.json')
                    continue
                checked = subprocess.run(
                    [nvim, '-u', 'NONE', '-i', 'NONE', '-l', 'nvim_forge/scripts/prepare-plugins.lua',
                     '--plugin-root', str(base / 'lazy'), '--check'],
                    cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8', timeout=30,
                )
                if checked.returncode or json.loads(checked.stdout) != manifest.get('backports'):
                    missing.append(f'{base}: prepared plugin backports do not match. {checked.stderr.strip()}'.rstrip())
            except (ValueError, AttributeError, OSError, subprocess.TimeoutExpired) as error:
                missing.append(f'{base}: cannot check prepared plugins ({error})')
    return missing


def preparation_commands(env):
    node = directory('node', 'FORGE_E2E_NODE_DEPS', env)
    commands = []
    for name, variable, _ in DEPENDENCIES:
        if env.get(variable):
            continue  # Prepared directories supplied by the caller are read-only inputs.
        command = [sys.executable, '-B', f'tests/e2e/prepare_{name}.py', '--download']
        if name in ('python', 'bash'):
            command.extend(('--node-deps', str(node)))
        if name == 'bash' and env.get('FORGE_BASH_EXECUTABLE'):
            command.extend(('--bash', env['FORGE_BASH_EXECUTABLE']))
        commands.append(command)
    return commands
