"""IDE-BOOT-26: official native rg -> Core/HTTP/install/launcher -> real Telescope.

Other plugin/Mason provisioning is controlled; this is not full Default acceptance.
"""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


parsers = load('search_parser_delivery', ROOT / 'tests/install-parser-runtime.test.py')
stand = parsers.stand
search = load('search_preparation', ROOT / 'scripts/prepare-search-runtime.py')
TOOLS = Path(os.environ.get('FORGE_SEARCH_RUNTIME', str(ROOT / '.tests/search-runtime' / stand.PLATFORM)))


class Search(parsers.Parsers):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        parsers.publisher.package(stand.SDK, parsers.SITE, parsers.DEPS, cls.core, TOOLS)
        cls.good = cls.core.read_bytes()
        cls.routes['/parser-core'] = cls.good
        cls.catalog()

    def prepared(self, name):
        base, env, target = super().prepared(name)
        shadow = base / 'user-tools'
        shadow.mkdir()
        (shadow / ('rg.exe' if stand.WINDOWS else 'rg')).write_bytes(b'user-owned old rg')
        self.addCleanup(lambda: self.assertEqual((shadow / ('rg.exe' if stand.WINDOWS else 'rg')).read_bytes(), b'user-owned old rg'))
        env['PATH'] = str(shadow) + os.pathsep + env['PATH']
        return base, env, target

    def test_search_01_installed_telescope_without_system_rg(self):
        base, env, target = self.prepared('search-native')
        self.assert_ok(self.install_core(base, env, target))
        project = base / 'project'
        (project / 'каталог с пробелами').mkdir(parents=True)
        (project / '.git').mkdir()
        (project / '.gitignore').write_text('ignored\n')
        (project / 'каталог с пробелами/найти файл.txt').write_text('first line\nFRIDE_SEARCH_NEEDLE\n', encoding='utf-8')
        (project / 'ignored').mkdir()
        (project / 'ignored/найти ignored.txt').write_text('FRIDE_SEARCH_NEEDLE\n', encoding='utf-8')
        launcher = [stand.SHELL, '-NoProfile', '-File', str(target / 'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL, str(target / 'bin/fride')]
        self.assert_ok(self.run_process(launcher + ['--headless', '-i', 'NONE', '-l', str(ROOT / 'tests/diagnostics/install-search-observe.lua'), str(base)], env, base, 'search-observe'))
        report = json.loads((base / 'search.json').read_text(encoding='utf-8'))
        self.assertTrue(Path(report['rg']).is_relative_to(target / 'runtime/search/bin'))
        self.assertEqual(report['grep']['opened']['line'], 2)
        for name in ('COPYING', 'LICENSE-MIT', 'UNLICENSE'):
            self.assertEqual((target / 'runtime/search/licenses' / name).read_bytes(), (TOOLS / 'search/licenses' / name).read_bytes())

    def test_search_02_provenance_and_native_version(self):
        base, env, target = self.prepared('search-provenance')
        copy = base / 'tools'
        shutil.copytree(TOOLS, copy)
        binary = copy / 'search/bin' / ('rg.exe' if stand.WINDOWS else 'rg')
        original = binary.read_bytes()
        binary.write_bytes(b'broken binary')
        with self.assertRaisesRegex(ValueError, 'payload SHA mismatch'):
            parsers.publisher.package(stand.SDK, parsers.SITE, parsers.DEPS, base / 'bad.zip', copy)
        binary.write_bytes(original)
        license = copy / 'search/licenses/LICENSE-MIT'
        license.write_bytes(b'wrong license')
        with self.assertRaisesRegex(ValueError, 'payload SHA mismatch'):
            search.verify(copy)
        with self.assertRaisesRegex(ValueError, 'Unexpected native ripgrep version'):
            search.version(stand.NVIM, '15.2.0')
        bad_archive = base / 'corrupt.zip'
        bad_archive.write_bytes(b'corrupt source')
        with self.assertRaisesRegex(ValueError, 'archive SHA mismatch'):
            search.prepare(base / 'bad-source', bad_archive)
        self.assertFalse((base / 'bad.zip').exists())
        self.assertFalse(target.exists())

    def test_search_03_probe_failure_keeps_previous(self):
        base, env, target = self.prepared('search-probe')
        self.assert_ok(self.install_core(base, env, target))
        marker = (target / '.forge-install.json').read_bytes()
        binary = target / 'runtime/search/bin' / ('rg.exe' if stand.WINDOWS else 'rg')
        sha = hashlib.sha256(binary.read_bytes()).hexdigest()
        self.routes['/parser-core'] = self.changed_core('search/bin/' + binary.name, b'invalid native binary')
        self.catalog()
        result = self.install_core(base, env, target)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / '.forge-install.json').read_bytes(), marker)
        self.assertEqual(hashlib.sha256(binary.read_bytes()).hexdigest(), sha)


if __name__ == '__main__':
    print('work:', stand.BASE, flush=True)
    names = sys.argv[1:] or [n for n in Search.__dict__ if n.startswith('test_search_')]
    result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Search(n) for n in names))
    (stand.BASE / 'search-summary.json').write_text(json.dumps({'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors), 'platform': stand.PLATFORM}, indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
