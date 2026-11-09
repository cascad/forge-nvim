"""Явная сборка native SQLLogicTest/SQLite SDK; готовый runtime не требует Rust."""
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
SOURCE = ROOT / 'scripts/sdk/sql-test'
SOURCES = ['Cargo.toml', 'Cargo.lock', 'src/main.rs']


def sha(path, canonical=False):
    data = Path(path).read_bytes()
    if canonical:
        data = data.replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download', action='store_true', help='Разрешить Cargo download и locked build')
    p.add_argument('--output', type=Path, default=ROOT / '.tests/sql-test-deps')
    p.add_argument('--rustc', help='Предоставленный установленный Rust SDK; не устанавливается')
    p.add_argument('--cc', help='Предоставленный C compiler для bundled SQLite')
    args = p.parse_args()
    out = args.output.resolve()
    if os.name == 'nt' and out.drive.lower() != ROOT.drive.lower():
        p.error('Windows SDK/cache/target должны оставаться на диске checkout')
    suffix = '.exe' if os.name == 'nt' else ''
    binary = out / 'bin' / ('forge-sqltest' + suffix)
    manifest_path = out / 'manifest.json'
    source_hashes = {name: sha(SOURCE / name, canonical=True) for name in SOURCES}
    arch = 'arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x64'
    host_platform = ('win32' if os.name == 'nt' else platform.system().lower()) + '-' + arch
    temp_base = ROOT / '.tests/tmp' if os.name == 'nt' else Path(tempfile.gettempdir())
    temp_base.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix=f'forge-sql-test-sdk-{os.getpid()}-', dir=temp_base) as profile:
        profile = Path(profile)
        env = dict(os.environ, TEMP=str(profile), TMP=str(profile), TMPDIR=str(profile),
                   RUSTUP_AUTO_INSTALL='0', CARGO_BUILD_JOBS='2', CARGO_INCREMENTAL='0')

        def run(command, **kwargs):
            return subprocess.run([str(x) for x in command], env=env, check=True,
                                  encoding='utf-8', **kwargs)

        build_context = None
        if args.download:
            candidate = args.rustc or shutil.which('rustc')
            if not candidate:
                p.error('Нужен предоставленный Rust SDK; задай --rustc. Автоустановки нет.')
            # Resolve rustup before replacing HOME; then use actual toolchain
            # binaries so Cargo cannot install a toolchain in the private profile.
            sysroot = Path(run([candidate, '--print', 'sysroot'], capture_output=True).stdout.strip())
            rustc, cargo = [sysroot / 'bin' / (name + suffix) for name in ('rustc', 'cargo')]
            if not rustc.is_file() or not cargo.is_file():
                p.error('В предоставленном SDK нужны native rustc и cargo')
            build_context = {'sysroot': str(sysroot),
                             'rustc': run([rustc, '--version', '--verbose'], capture_output=True).stdout.strip(),
                             'cargo': run([cargo, '--version'], capture_output=True).stdout.strip()}
            env.update(RUSTC=str(rustc), PATH=str(sysroot / 'bin') + os.pathsep + env['PATH'],
                       CARGO_HOME=str(out / 'cargo-home'), CARGO_TARGET_DIR=str(out / 'target'))
            if args.cc:
                env['CC'] = args.cc
                build_context['cc'] = args.cc

        for key, child in [('HOME', 'home'), ('USERPROFILE', 'home'), ('APPDATA', 'roaming'),
                           ('LOCALAPPDATA', 'local'), ('XDG_CACHE_HOME', 'cache'),
                           ('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data')]:
            value = profile / child
            value.mkdir(exist_ok=True)
            env[key] = str(value)

        if args.download:
            out.mkdir(parents=True, exist_ok=True)
            run([cargo, 'build', '--locked', '--release', '--jobs', '2',
                 '--manifest-path', SOURCE / 'Cargo.toml'])
            if {name: sha(SOURCE / name, canonical=True) for name in SOURCES} != source_hashes:
                p.error('Source/lock изменился при --locked build')
            binary.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(out / 'target/release' / binary.name, binary)
            manifest = {'platform': host_platform, 'sources': source_hashes,
                        'files': {binary.relative_to(out).as_posix(): sha(binary)},
                        'build_context': build_context}
        else:
            if not manifest_path.is_file():
                p.error('Сначала явно prepare_sql_test.py --download с предоставленным Rust/CC')
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            if manifest.get('sources') != source_hashes or manifest.get('platform') != host_platform:
                p.error('Source/lock/platform отличаются; нужна явная подготовка --download')
            if not binary.is_file():
                p.error('Отсутствует native runner; сначала явно prepare_sql_test.py --download')
            if manifest.get('files') != {binary.relative_to(out).as_posix(): sha(binary)}:
                p.error('Hash native SQL test runner не совпал с manifest')

        version = run([binary, '--version'], capture_output=True).stdout.strip()
        if not version.startswith('forge-sqltest 0.1.0 (sqllogictest 0.29.1; SQLite '):
            p.error('Неверная версия native runner: ' + version)
        script, report = profile / 'readiness ü.slt', profile / 'report.json'
        script.write_text('query I\nSELECT 40 + 2;\n----\n42\n\n', encoding='utf-8')
        run([binary, '--report', report, '--', script], capture_output=True)
        result = json.loads(report.read_text(encoding='utf-8'))
        if result.get('protocol') != 1 or result.get('status') != 'passed' or result.get('checks') != 1:
            p.error('Native SQLite readiness не выполнил реальный assertion')
        if args.download:
            manifest['version'] = version
            manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        elif manifest.get('version') != version:
            p.error('Version отличается от manifest')
    print(('Prepared ' if args.download else 'Ready ') + str(out))


if __name__ == '__main__':
    main()
