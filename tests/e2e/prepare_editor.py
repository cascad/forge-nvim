"""Явная подготовка исходников pinned-плагинов; editor e2e ничего не скачивает."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / 'nvim_forge/lazy-lock.json'


def git(cache, *args):
    return subprocess.run(['git', '-c', 'safe.directory=' + cache.as_posix(), '-C', str(cache), *args],
                          capture_output=True, timeout=60)


def extract(raw, destination):
    destination.mkdir(parents=True, exist_ok=True)
    links = []
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for item in archive.getmembers():
            target = (destination / item.name).resolve()
            if destination.resolve() not in (target, *target.parents):
                raise RuntimeError('Unsafe archive path: ' + item.name)
            if item.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif item.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.extractfile(item).read())
                target.chmod(item.mode)
            elif item.issym() or item.islnk():
                source = (target.parent / item.linkname if item.issym() else destination / item.linkname).resolve()
                if destination.resolve() not in (source, *source.parents):
                    raise RuntimeError('Unsafe archive link: ' + item.name)
                links.append((target, source))
            else:
                raise RuntimeError('Unsupported archive entry: ' + item.name)
    # Материализуем внутренние ссылки одинаково на Windows/POSIX без привилегий.
    while links:
        pending = []
        for target, source in links:
            if source.is_file():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
            elif source.is_dir() and source not in target.parents:
                shutil.copytree(source, target)
            else:
                pending.append((target, source))
        if len(pending) == len(links):
            raise RuntimeError('Unresolved/cyclic archive links: ' + str(pending))
        links = pending


def default_caches():
    if os.name == 'nt':
        base = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData/Local'))
        return [base / (name + '-data/lazy') for name in ('nvim_forge', 'nvim')]
    base = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    return [base / name / 'lazy' for name in ('nvim_forge', 'nvim')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, action='append', default=[])
    parser.add_argument('--download', action='store_true', help='Явно разрешить скачать отсутствующие pinned исходники')
    parser.add_argument('--output', type=Path, default=ROOT / '.tests/editor-deps')
    args = parser.parse_args()
    lock_raw = LOCK.read_bytes()
    lock = json.loads(lock_raw)
    catalog_path = ROOT / 'tests/e2e/plugin-sources.json'
    catalog = json.loads(catalog_path.read_text()) if catalog_path.exists() else {}
    caches = args.cache or default_caches()
    result = {}
    missing = []
    args.output.mkdir(parents=True, exist_ok=True)
    for name, entry in lock.items():
        if Path(name).name != name or name in ('.', '..'):
            raise RuntimeError('Unsafe plugin name: ' + name)
        destination = args.output / 'lazy' / name
        raw = None
        for base in caches:
            source = base / name
            if not (source / '.git').exists():
                continue
            remote = git(source, 'config', '--get', 'remote.origin.url')
            if remote.returncode == 0:
                url = remote.stdout.decode().strip().removesuffix('.git')
                if url.startswith('https://github.com/'):
                    catalog[name] = url.removeprefix('https://github.com/')
            content = git(source, 'archive', '--format=tar', entry['commit'])
            if content.returncode == 0:
                raw = content.stdout
                break
        if raw is None and args.download and name in catalog:
            url = 'https://codeload.github.com/' + catalog[name] + '/tar.gz/' + entry['commit']
            with urllib.request.urlopen(url, timeout=60) as response:
                downloaded = response.read()
            # GitHub tarball имеет общий верхний каталог; преобразуем в плоский tar.
            output = io.BytesIO()
            with tarfile.open(fileobj=io.BytesIO(downloaded), mode='r:gz') as archive, tarfile.open(fileobj=output, mode='w') as flat:
                for item in archive.getmembers():
                    parts = item.name.split('/', 1)
                    if len(parts) == 1 or not parts[1]:
                        continue
                    item.name = parts[1]
                    flat.addfile(item, archive.extractfile(item) if item.isfile() else None)
            raw = output.getvalue()
        if raw is None:
            missing.append(name)
            continue
        if destination.exists():
            # Удаляем только вычисленный leaf подготовленного output, не источник.
            if args.output.resolve() not in destination.resolve().parents:
                raise RuntimeError('Destination escapes output: ' + str(destination))
            shutil.rmtree(destination)
        extract(raw, destination)
        result[name] = entry['commit']
    # Каталог URL — отдельные данные, lock остаётся единственным источником revisions.
    if catalog and not catalog_path.exists():
        catalog_path.write_text(json.dumps(catalog, indent=2, sort_keys=True) + '\n')
    if missing:
        parser.exit(2, 'Нет pinned исходников: ' + ', '.join(missing) + '\nИспользуй --download либо --cache с нужными git-объектами.\n')
    manifest = {'lock_sha256': hashlib.sha256(lock_raw).hexdigest(), 'plugins': result}
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print('Prepared %d pinned plugins: %s' % (len(result), args.output))


if __name__ == '__main__':
    main()
