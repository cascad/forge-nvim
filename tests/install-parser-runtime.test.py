"""IDE-BOOT-24: native Core parser publisher -> HTTP/UI/install/real launcher.

Other Core plugin/Mason stages are controlled; not full Default acceptance.
Supply a prepared site with FORGE_PARSER_SITE. No SDK installation/downloads.
"""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ui = load('parser_ui', ROOT / 'tests/install-ui.test.py')
stand = ui.stand
publisher = load('core_publisher', ROOT / 'scripts/package-core-runtime.py')
SITE = Path(os.environ.get('FORGE_PARSER_SITE', str(ROOT / '.tests/parser-runtime' / stand.PLATFORM / 'site')))
DEPS = Path(os.environ.get('FORGE_E2E_DEPS', str(ROOT / '.tests/editor-deps')))


class Parsers(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        config = cls.source / 'nvim_forge'
        shutil.copytree(ROOT / 'nvim_forge/lua', config / 'lua')
        shutil.copyfile(ROOT / 'nvim_forge/scripts/setup-stage.lua', config / 'scripts/setup-stage.lua')
        (config / 'init.lua').write_text("dofile(assert(vim.env.FORGE_PARSER_TEST_INIT))\n", encoding='utf-8')
        cls.core = stand.BASE / ('parser-core.zip' if stand.WINDOWS else 'parser-core.tar.gz')
        publisher.package(stand.SDK, SITE, DEPS, cls.core)
        cls.good = cls.core.read_bytes()
        cls.routes['/parser-core'] = cls.good
        cls.catalog()

    @classmethod
    def catalog(cls):
        payload = cls.routes['/parser-core']
        (cls.source / 'scripts/runtime/artifacts.tsv').write_text('\t'.join([
            stand.PLATFORM, 'core', cls.url + '/parser-core', hashlib.sha256(payload).hexdigest()]) + '\n', encoding='utf-8')
        cls.publish_source(cls.ui_digest)

    def tearDown(self):
        self.routes['/parser-core'] = self.good
        self.catalog()

    def prepared(self, name):
        base, env, target = super().prepare(name)
        env.update(FORGE_E2E_DEPS=str(DEPS), FORGE_PARSER_TEST_INIT=str(ROOT / 'tests/diagnostics/install-parser-init.lua'))
        env['PATH'] = os.pathsep.join([str(Path(os.environ['SystemRoot']) / 'System32'), str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0')]) if stand.WINDOWS else '/usr/bin:/bin'
        if stand.WINDOWS: env['PATH'] += os.pathsep + str(Path(shutil.which('git')).parent)
        # A stale standard app parser must not shadow the delivered site after Lazy reset.
        shadow = Path(env['XDG_DATA_HOME']) / ('fride-data' if stand.WINDOWS else 'fride') / 'site/parser/lua.so'
        shadow.parent.mkdir(parents=True)
        shadow.write_bytes(b'invalid user parser')
        self.addCleanup(lambda: self.assertEqual(shadow.read_bytes(), b'invalid user parser'))
        return base, env, target

    def install_core(self, base, env, target):
        return self.root_entry(base, env, target, 'core', runtime=False)

    def test_parser_01_native_delivery_and_captures(self):
        base, env, target = self.prepared('parser-native')
        self.assert_ok(self.install_core(base, env, target))
        launcher = [stand.SHELL, '-NoProfile', '-File', str(target / 'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL, str(target / 'bin/fride')]
        self.assert_ok(self.run_process(launcher + ['--headless', '-i', 'NONE', '-l', str(ROOT / 'tests/diagnostics/install-parser-observe.lua'), str(base)], env, base, 'observe'))
        report = json.loads((base / 'parser.json').read_text(encoding='utf-8'))
        self.assertEqual(report['parsers'], 33)
        self.assertGreater(report['captures'], 0)
        self.assertTrue(Path(report['library']).is_relative_to(target / 'runtime'))
        self.assertIn('Parser readiness', (target / 'log/setup-parsers.log').read_text(encoding='utf-8'))

    @classmethod
    def changed_core(cls, relative, value):
        if stand.WINDOWS:
            with zipfile.ZipFile(io.BytesIO(cls.good)) as src:
                files = {p: src.read(p) for p in src.namelist()}
        else:
            with tarfile.open(fileobj=io.BytesIO(cls.good), mode='r:gz') as src:
                files = {p.name.removeprefix('./'): src.extractfile(p).read() for p in src if p.isfile()}
        manifest = json.loads(files['forge-runtime.json'])
        if value is None:
            del files[relative]
            del manifest['files'][relative]
        else:
            files[relative] = value
            manifest['files'][relative] = hashlib.sha256(value).hexdigest()
        files['forge-runtime.json'] = json.dumps(manifest).encode()
        output = io.BytesIO()
        if stand.WINDOWS:
            with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as dst:
                for name, data in files.items():
                    dst.writestr(name, data)
        else:
            with tarfile.open(fileobj=output, mode='w:gz') as dst:
                for name, data in files.items():
                    item = tarfile.TarInfo(name)
                    item.size, item.mode = len(data), 0o755 if name.startswith('bin/') else 0o644
                    dst.addfile(item, io.BytesIO(data))
        return output.getvalue()

    def test_parser_02_incomplete_or_invalid_keeps_previous_kit(self):
        base, env, target = self.prepared('parser-failure')
        self.assert_ok(self.install_core(base, env, target))
        marker = (target / '.forge-install.json').read_bytes()
        binary = target / 'runtime/treesitter/parser/lua.so'
        before = binary.read_bytes()
        for path, value in [('treesitter/parser/lua.so', None), ('treesitter/parser/lua.so', b'broken native parser'), ('treesitter/queries/lua/highlights.scm', None), ('treesitter/queries/lua/highlights.scm', b'(fride_nonexistent_node) @error')]:
            with self.subTest(path=path, missing=value is None):
                self.routes['/parser-core'] = self.changed_core(path, value)
                self.catalog()
                result = self.install_core(base, env, target)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('lua:', (target / 'log/setup-parsers.log').read_text(encoding='utf-8'))
                self.assertEqual((target / '.forge-install.json').read_bytes(), marker)
                self.assertEqual(binary.read_bytes(), before)

    def test_parser_03_publisher_rejects_revision_and_abi(self):
        base, env, target = self.prepared('parser-publisher')
        site = base / 'site'
        shutil.copytree(SITE, site)
        revision = site / 'parser-info/lua.revision'
        original = revision.read_bytes()
        revision.write_text('0' * 40)
        with self.assertRaisesRegex(ValueError, 'Parser revision mismatch: lua'):
            publisher.package(stand.SDK, site, DEPS, base / 'bad.zip')
        revision.write_bytes(original)
        (site / 'parser/lua.so').write_bytes(b'invalid ABI')
        with self.assertRaisesRegex(ValueError, 'lua:'):
            publisher.package(stand.SDK, site, DEPS, base / 'bad.zip')
        self.assertFalse((base / 'bad.zip').exists())
        self.assertFalse(target.exists())

    def test_parser_04_unmanaged_explicit_command(self):
        base, env, target = self.prepared('parser-unmanaged')
        env.pop('FORGE_NVIM_COMPONENTS', None)
        self.assert_ok(self.run_process([str(stand.NVIM), '--headless', '-u', 'NONE', '-i', 'NONE', '-l',
            str(ROOT / 'tests/diagnostics/install-parser-unmanaged.lua'), str(ROOT / 'nvim_forge'), str(DEPS),
            str(base / 'unmanaged.json')], env, base, 'unmanaged-process'))
        self.assertEqual(json.loads((base / 'unmanaged.json').read_text()), {'startup': 0, 'explicit': 1})
        self.assertFalse(target.exists())


if __name__ == '__main__':
    print('work:', stand.BASE, flush=True)
    names = sys.argv[1:] or [n for n in Parsers.__dict__ if n.startswith('test_parser_')]
    result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Parsers(n) for n in names))
    (stand.BASE / 'parser-summary.json').write_text(json.dumps({'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors), 'platform': stand.PLATFORM}, indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
