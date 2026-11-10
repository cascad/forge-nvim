"""Явная сборка upstream fzf-native поверх подготовленного pinned editor SDK."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor-deps', type=Path, default=ROOT / '.tests/editor-deps')
    parser.add_argument('--build-root', type=Path, default=ROOT / '.tests/tmp')
    args = parser.parse_args()
    cmake = shutil.which('cmake')
    if not cmake:
        parser.error('Для явной сборки нужны CMake и C toolchain; обычному редактору они не нужны.')
    deps = args.editor_deps.resolve()
    manifest_path = deps / 'manifest.json'
    manifest = json.loads(manifest_path.read_bytes())
    lock = json.loads((ROOT / 'nvim_forge/lazy-lock.json').read_bytes())
    if manifest['plugins'] != {name: value['commit'] for name, value in lock.items()}:
        parser.error('Сначала подготовь editor SDK по текущему lazy-lock.json.')
    plugin = deps / 'lazy/telescope-fzf-native.nvim'
    inputs = ['CMakeLists.txt', 'src/fzf.c', 'src/fzf.h']
    sources = {name: hashlib.sha256((plugin / name).read_bytes()).hexdigest() for name in inputs}
    build_root = args.build_root.resolve()
    build_root.mkdir(parents=True, exist_ok=True)
    library = 'libfzf.dll' if os.name == 'nt' else 'libfzf.so'
    with tempfile.TemporaryDirectory(prefix='forge-fzf-', dir=build_root) as tmp:
        build = Path(tmp).resolve()
        assert build.is_relative_to(build_root), 'Build escaped intended temp root'
        scratch = build / 'tmp'
        scratch.mkdir()
        env = dict(os.environ, TEMP=str(scratch), TMP=str(scratch), TMPDIR=str(scratch))
        commands = [[cmake, '-S', str(plugin), '-B', str(build), '-DCMAKE_BUILD_TYPE=Release'],
                    [cmake, '--build', str(build), '--config', 'Release', '--parallel', '2'],
                    [cmake, '--install', str(build), '--config', 'Release']]
        for command in commands:
            subprocess.run(command, check=True, env=env, timeout=120)
        output = plugin / 'build' / library
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(build / library, output)
        for name, digest in sources.items():
            assert hashlib.sha256((plugin / name).read_bytes()).hexdigest() == digest
        prepared = {'commit': lock['telescope-fzf-native.nvim']['commit'],
                    'library': output.relative_to(deps).as_posix(),
                    'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                    'sources': sources, 'system': platform.system(), 'machine': platform.machine()}
    manifest.setdefault('native', {})['fzf'] = prepared
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print('Prepared native fzf:', output, prepared['sha256'])


if __name__ == '__main__':
    main()
