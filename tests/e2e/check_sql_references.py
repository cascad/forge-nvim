"""Native resolver unit checks against the pinned SQLS parser; no SDK installation."""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deps', type=Path, default=ROOT / '.tests/sql-deps')
    parser.add_argument('--go', default=shutil.which('go'))
    args = parser.parse_args()
    if not args.go:
        parser.error('Нужен явно подготовленный Go; задай --go')
    deps = args.deps.resolve()
    manifest = json.loads((deps / 'manifest.json').read_text(encoding='utf-8'))
    locks = manifest['build_context']['sqls']['go_locks']
    specification = json.loads((ROOT / 'tests/e2e/sql-tools/sources.json').read_text(encoding='utf-8'))['sqls_source']
    archive = deps / 'archives' / specification['archive']
    if sha(archive) != specification['sha256']:
        parser.error('Изменён pinned SQLS source archive')
    evidence = ROOT / '.tests/sql-references-native'
    evidence.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='resolver-', dir=evidence)).resolve()
    shutil.copy2(__file__, work / 'check_sql_references.py')
    env = dict(os.environ, GOTOOLCHAIN='local', GOENV='off', GOWORK='off',
               GOCACHE=str(evidence / 'go-build'), GOMODCACHE=str(deps / 'go-mod'),
               GOPATH=str(work / 'go'), CGO_ENABLED='0', GOMAXPROCS='2', GOPROXY='off')
    (work / 'tmp').mkdir()
    for name in ('TEMP', 'TMP', 'TMPDIR', 'GOTMPDIR'):
        env[name] = str(work / 'tmp')
    if os.name == 'nt' and deps.drive.lower() != ROOT.drive.lower():
        parser.error('Windows caches должны быть на диске checkout')
    sources = {}
    # Читаем upstream AST из проверенного archive, не из изменяемого build scratch.
    with tarfile.open(archive) as package:
        for member in package.getmembers():
            if not member.isfile() or '/' not in member.name:
                continue
            name = member.name.split('/', 1)[1]
            if name not in ('go.mod', 'go.sum') and name.split('/', 1)[0] not in ('ast', 'token', 'parser', 'dialect'):
                continue
            target_file = (work / name).resolve()
            if not target_file.is_relative_to(work):
                raise RuntimeError('Archive path вне private module')
            target_file.parent.mkdir(parents=True, exist_ok=True)
            target_file.write_bytes(package.extractfile(member).read())
            sources[name] = sha(target_file)
    for name, expected in locks.items():
        if sha(work / name) != expected:
            parser.error('Pinned archive не совпал с SDK Go lock: ' + name)
    overlay = ROOT / 'scripts/sdk/sqls-references'
    target = work / 'internal/references'
    target.mkdir(parents=True)
    payload = {}
    for file in sorted(overlay.glob('*.go')):
        shutil.copy2(file, target / file.name)
        payload[file.name] = sha(file)
    command = [str(Path(args.go).resolve()), 'test', '-mod=readonly', '-buildvcs=false',
               '-p=2', './internal/references', '-count=1', '-v']
    result = subprocess.run(command, cwd=work, env=env, encoding='utf-8', capture_output=True, timeout=120)
    (work / 'stdout.txt').write_text(result.stdout, encoding='utf-8')
    (work / 'stderr.txt').write_text(result.stderr, encoding='utf-8')
    unchanged = all(sha(work / name) == expected for name, expected in locks.items())
    (work / 'result.json').write_text(json.dumps({
        'command': command, 'code': result.returncode, 'source_archive': str(archive),
        'source_archive_sha256': sha(archive),
        'runner_sha256': sha(work / 'check_sql_references.py'), 'platform': platform.platform(),
        'sources': sources, 'overlay': payload, 'locks_unchanged': unchanged,
        'scope': 'native resolver unit checks, no LSP/editor/SDK integration',
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(result.stdout, end='')
    print(result.stderr, end='')
    print('artifacts: ' + str(work))
    if not unchanged:
        raise RuntimeError('Изменились Go locks')
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
