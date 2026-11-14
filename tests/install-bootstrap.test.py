"""IDE-BOOT-8: настоящий HTTP/download/archive/shell; fixture backend, не native IDE install."""
from contextlib import contextmanager
import gzip
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import tarfile
import threading
import time
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / '.tests/install-bootstrap' / (str(time.time_ns()) + ' ü space')
BASE.mkdir(parents=True)
WINDOWS = os.name == 'nt'
SYSTEM = platform.system()
SHELL = (shutil.which('powershell.exe') or shutil.which('pwsh')) if WINDOWS else shutil.which('bash')
assert SHELL, 'Native PowerShell/Bash is required'

PS_BACKEND = r'''param([string]$Source,[string]$InstallPath,[string]$RuntimePath,[string]$RuntimeArchiveUrl,[string]$RuntimeSHA256)
[IO.Directory]::CreateDirectory($InstallPath) | Out-Null
[IO.File]::WriteAllText((Join-Path $InstallPath 'installed-marker.txt'), 'fixture backend')
[IO.File]::WriteAllLines($env:BOOTSTRAP_FIXTURE_REPORT, @(
  "source=$Source", "target=$InstallPath", "runtime=$RuntimePath", "components=$env:FORGE_NVIM_COMPONENTS"
), (New-Object Text.UTF8Encoding($false)))
if ($env:BOOTSTRAP_FIXTURE_EXIT) { exit ([int]$env:BOOTSTRAP_FIXTURE_EXIT) }
'''
SH_BACKEND = r'''#!/usr/bin/env bash
set -eu
source_dir="$1"; target="$2"; runtime="${3:-}"
mkdir -p "$target"
printf '%s\n' 'fixture backend' > "$target/installed-marker.txt"
printf 'source=%s\ntarget=%s\nruntime=%s\n' "$source_dir" "$target" "$runtime" > "$BOOTSTRAP_FIXTURE_REPORT"
printf 'components=%s\n' "${FORGE_NVIM_COMPONENTS:-}" >> "$BOOTSTRAP_FIXTURE_REPORT"
exit "${BOOTSTRAP_FIXTURE_EXIT:-0}"
'''


def archive(kind, complete=True):
    files = {'nvim_forge/init.lua': b'-- private transport fixture\n',
             'nvim_forge.sh': b'#!/bin/sh\n', 'wezterm.lua': b'-- fixture\n'}
    if complete:
        for name in ['components.tsv','lib/install-profile.ps1','lib/install-profile.sh']:
            files['nvim_forge/scripts/'+name]=(ROOT/'nvim_forge/scripts'/name).read_bytes()
        files.update({'scripts/install-private.ps1': PS_BACKEND.encode(),
                      'scripts/install-private.sh': SH_BACKEND.encode(),
                      'scripts/install-private.lua': b'-- dispatch fixture\n'})
    output = io.BytesIO()
    if kind == 'zip':
        with zipfile.ZipFile(output, 'w') as stream:
            for name, data in sorted(files.items()):
                stream.writestr(zipfile.ZipInfo('forge-fixture/' + name), data)
    else:
        with gzip.GzipFile(fileobj=output, mode='wb', mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as stream:
                for name, data in sorted(files.items()):
                    item = tarfile.TarInfo('forge-fixture/' + name)
                    item.size = len(data); item.mode = 0o644
                    stream.addfile(item, io.BytesIO(data))
    return output.getvalue()


@contextmanager
def serve():
    extension = 'zip' if WINDOWS else 'tar.gz'
    routes = {'/entry': (ROOT / ('install.ps1' if WINDOWS else 'install.sh')).read_bytes(),
              '/source': archive('zip' if WINDOWS else 'tar'),
              '/incomplete': archive('zip' if WINDOWS else 'tar', False), '/broken': b'not an archive'}
    requests = []
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.path)
            if self.path not in routes:
                self.send_error(404); return
            data = routes[self.path]
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8' if self.path == '/entry' else 'application/octet-stream')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers(); self.wfile.write(data)
        def log_message(self, *_): pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
    try:
        yield 'http://127.0.0.1:' + str(server.server_port), routes, requests
    finally:
        server.shutdown(); server.server_close(); thread.join()


class Bootstrap(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = serve(); cls.url, cls.routes, cls.requests = cls.server.__enter__()
    @classmethod
    def tearDownClass(cls): cls.server.__exit__(None, None, None)

    def run_entry(self, name, route='/source', failure=False, options=None, ui_action=None):
        private = BASE / name
        private.mkdir(exist_ok=True)
        source = private / 'sources'; target = private / 'config ü'; report = private / 'backend.txt'
        env = os.environ.copy()
        env.update(BOOTSTRAP_FIXTURE_REPORT=str(report), BOOTSTRAP_FIXTURE_EXIT='7' if failure else '0')
        # Не наследовать пользовательские advanced skip/language флаги.
        for key in ['FORGE_NVIM_WITH_LANGUAGES', 'FORGE_NVIM_SKIP_DEPS', 'FORGE_NVIM_USE_LOCAL_SOURCE']:
            env.pop(key, None)
        if WINDOWS:
            def quote(value): return "'" + str(value).replace("'", "''") + "'"
            command = '& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing -Uri ' + quote(self.url + '/entry') + ').Content))'
            for key, value in [('ArchiveUrl', self.url + route), ('SourceRoot', source), ('InstallPath', target)]:
                command += ' -' + key + ' ' + quote(value)
            command += ' -SkipDependencies'
            args = [SHELL, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command]
        else:
            command = 'bash -c "$(curl --fail --silent --show-error ' + shlex.quote(self.url + '/entry') + ')" --'
            for key, value in [('archive-url', self.url + route), ('source-root', source), ('install-dir', target)]:
                command += ' --' + key + ' ' + shlex.quote(str(value))
            command += ' --skip-dependencies'
            args = [SHELL, '-c', command]
        for key,value in (options or {}).items():
            if WINDOWS:command += ' -'+key+' '+quote(value)
            else:command += ' --'+key+' '+shlex.quote(value)
        args[-1]=command
        if ui_action:
            nvim=str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if WINDOWS else shutil.which('nvim')
            env.update(FORGE_INSTALL_UI_COMMAND=json.dumps(args),FORGE_INSTALL_UI_ACTION=ui_action,FORGE_INSTALL_UI_REPORT=str(private/'ui.json'))
            args=[nvim,'-u','NONE','-i','NONE','-l',str(ROOT/'tests/diagnostics/install-profile-ui.lua')]
        result = subprocess.run(args, env=env, text=True, encoding='utf-8', errors='replace', capture_output=True, timeout=60,stdin=subprocess.DEVNULL)
        count = len(list(private.glob('run-*.json')))
        (private / f'run-{count}.json').write_text(json.dumps({'argv': args, 'exit': result.returncode,
            'stdout': result.stdout, 'stderr': result.stderr}, ensure_ascii=False, indent=2), encoding='utf-8')
        self.assertFalse(list(source.glob('.bootstrap*')), 'Incomplete staging left behind')
        return result, source, target, report

    def test_01_remote_entry_and_repeat(self):
        first, source, target, report = self.run_entry('repeat')
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        received = dict(line.split('=', 1) for line in report.read_text(encoding='utf-8-sig').splitlines())
        expected = source / hashlib.sha256(self.routes['/source']).hexdigest()
        self.assertEqual(Path(received['source']), expected)
        self.assertEqual(received['runtime'], '')
        self.assertEqual(Path(received['target']), target)
        self.assertEqual((target / 'installed-marker.txt').read_text().splitlines(), ['fixture backend'])
        sentinel = expected / 'keep-repeat.txt'; sentinel.write_text('existing source')
        second, _, _, _ = self.run_entry('repeat')
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(sentinel.read_text(), 'existing source')
        self.assertEqual([p.name for p in source.iterdir()], [expected.name])

    def test_02_download_failure(self):
        result, source, target, report = self.run_entry('http-failure', '/missing')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('404', result.stdout + result.stderr)
        self.assertFalse(report.exists()); self.assertFalse(target.exists())
        self.assertEqual(list(source.iterdir()), [])

    def test_03_incomplete_source(self):
        result, source, target, report = self.run_entry('incomplete', '/incomplete')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no complete forge-nvim source', (result.stdout + result.stderr).lower())
        self.assertFalse(report.exists()); self.assertFalse(target.exists())
        self.assertEqual(list(source.iterdir()), [])

    def test_04_broken_archive(self):
        result, source, target, report = self.run_entry('broken', '/broken')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('invalid source archive', (result.stdout + result.stderr).lower())
        self.assertFalse(report.exists()); self.assertFalse(target.exists())
        self.assertEqual(list(source.iterdir()), [])

    def test_05_backend_failure(self):
        result, source, _, report = self.run_entry('backend-failure', failure=True)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertTrue(report.exists()); self.assertEqual(len(list(source.iterdir())), 1)

    def test_06_reject_incomplete_cache(self):
        private = BASE / 'bad-cache'
        source = private / 'sources' / hashlib.sha256(self.routes['/source']).hexdigest()
        source.mkdir(parents=True)
        result, _, target, report = self.run_entry('bad-cache')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cached source is incomplete', (result.stdout + result.stderr).lower())
        self.assertFalse(report.exists()); self.assertFalse(target.exists())


if __name__ == '__main__':
    print('artifacts: ' + str(BASE), flush=True)
    print('transport E2E: ' + SYSTEM + '; shell=' + SHELL + '; package backend=fixture', flush=True)
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(Bootstrap)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    (BASE / 'summary.json').write_text(json.dumps({'platform': SYSTEM, 'shell': SHELL,
        'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'requests': Bootstrap.requests, 'entry_sha256': hashlib.sha256((ROOT / ('install.ps1' if WINDOWS else 'install.sh')).read_bytes()).hexdigest(),
        'test_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}, indent=2), encoding='utf-8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
