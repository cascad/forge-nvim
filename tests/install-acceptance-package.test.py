"""spec: IDE-BOOT-54. Native package entrypoints/frontend; fixture runtime, no host installation."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('acceptance_package', ROOT / 'scripts/package-acceptance-installer.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
BASE = Path(os.environ.get('FORGE_INSTALL_STAND_ROOT', str(ROOT / '.tests'))) / 'acceptance-package' / str(time.time_ns())
BASE.mkdir(parents=True)
FRONTEND = Path(os.environ.get('FORGE_INSTALL_UI_BINARY', str(ROOT / '.tools/installer-ui' / package.native_platform() / ('fride-setup.exe' if os.name == 'nt' else 'fride-setup'))))


def make_archive(path, component, files, native=None):
    manifest = dict(schema=1, platform=native or package.native_platform(), components=[component], paths=[], probes=[],
                    files={p: hashlib.sha256(data).hexdigest() for p, data in files.items()})
    if component == 'core':
        manifest['nvim'] = 'bin/nvim.exe' if os.name == 'nt' else 'bin/nvim'
        name = 'forge-runtime.json'
    else:
        manifest['kind'] = 'component'
        name = 'forge-component.json'
    with zipfile.ZipFile(path, 'w') as archive:
        for name_, data in files.items():
            archive.writestr(name_, data)
        archive.writestr(name, json.dumps(manifest))


class AcceptancePackage(unittest.TestCase):
    def setUp(self):
        self.root = BASE / (self._testMethodName + ' ü space')
        self.root.mkdir()
        self.source = self.root / 'source'
        self.source.mkdir()
        shutil.copytree(ROOT / 'installer-ui', self.source / 'installer-ui', ignore=shutil.ignore_patterns('target'))
        shutil.copytree(ROOT / 'scripts/acceptance', self.source / 'scripts/acceptance')
        for name in ('nvim_forge/init.lua', 'scripts/install-private.lua', 'scripts/install-private.ps1', 'scripts/install-private.sh', 'wezterm.lua'):
            destination = self.source / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text('-- tracked fixture\n', encoding='utf-8')
        (self.source / 'nvim_forge/scripts').mkdir()
        shutil.copy2(ROOT / 'nvim_forge/scripts/components.tsv', self.source / 'nvim_forge/scripts/components.tsv')
        subprocess.run(['git', 'init', '-q', str(self.source)], check=True, capture_output=True)
        subprocess.run(['git', '-C', str(self.source), 'add', 'nvim_forge', 'scripts', 'wezterm.lua'], check=True, capture_output=True)
        subprocess.run(['git', '-C', str(self.source), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True, capture_output=True)
        for name in ('.tests/private.txt', '.tools/private.txt', '99-SECRET.md'):
            destination = self.source / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text('PRIVATE_FIXTURE', encoding='utf-8')
        self.core = self.root / 'core.zip'
        self.exe = 'bin/nvim.exe' if os.name == 'nt' else 'bin/nvim'
        make_archive(self.core, 'core', {self.exe: b'fixture runtime'})
        self.output = self.root / 'installer ü'

    def build(self, terminal=None):
        with patch.object(package, 'ROOT', self.source):
            return package.package(self.core, FRONTEND, self.output, terminal)

    def entry(self, *arguments):
        if os.name == 'nt':
            command = [shutil.which('powershell.exe') or shutil.which('pwsh'), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(self.output / 'install.ps1')]
        else:
            command = ['bash', str(self.output / 'install.sh')]
        result = subprocess.run([*command, *arguments], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
        (self.root / ('entry-' + str(time.time_ns()) + '.json')).write_text(json.dumps(dict(exit=result.returncode, stdout=result.stdout, stderr=result.stderr)), encoding='utf-8')
        return result

    def test_01_actual_frontend_plan_and_unicode_parameters(self):
        self.build()
        target = str(self.root / 'absent parent ü' / 'kit')
        result = self.entry('--profile', 'custom', '--components', 'core', '--install-dir', target, '--print-plan')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan['components'], ['core'])
        self.assertEqual(Path(plan['install_dir']), Path(target))
        self.assertFalse(Path(target).exists())
        self.assertFalse((self.output / 'payload/source/99-SECRET.md').exists())
        self.assertFalse((self.output / 'payload/source/.tools').exists())
        self.assertFalse((self.output / 'payload/source/.tests').exists())

    def test_02_default_keeps_deferred_sdk_policy(self):
        self.build()
        result = self.entry('--print-plan')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        plan = json.loads(result.stdout)
        self.assertIn('go', plan['components'])
        self.assertIn('rust', plan['components'])
        self.assertFalse(plan['prepare_languages'])

    def test_03_tamper_fails_before_frontend(self):
        self.build()
        (self.output / 'payload/source/nvim_forge/init.lua').write_text('changed', encoding='utf-8')
        result = self.entry('--print-plan')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('mismatch', result.stdout + result.stderr)

    def test_04_missing_or_unexpected_payload_fails(self):
        self.build()
        (self.output / 'payload/runtime/extra.txt').write_text('extra', encoding='utf-8')
        result = self.entry('--print-plan')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unexpected', (result.stdout + result.stderr).lower())
        (self.output / 'payload/runtime/extra.txt').unlink()
        (self.output / 'payload/runtime' / self.exe).unlink()
        missing = self.entry('--print-plan')
        self.assertNotEqual(missing.returncode, 0)
        self.assertTrue(any(word in (missing.stdout + missing.stderr).lower() for word in ('missing', 'incomplete')))

    def test_05_existing_output_is_preserved(self):
        self.output.mkdir()
        marker = self.output / 'keep.txt'
        marker.write_text('keep', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Existing output'):
            self.build()
        self.assertEqual(marker.read_text(), 'keep')

    def test_06_stale_frontend_is_rejected(self):
        (self.source / 'installer-ui/src/main.rs').write_text('changed', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Stale frontend'):
            self.build()
        self.assertFalse(self.output.exists())

    def test_07_foreign_core_is_rejected(self):
        make_archive(self.core, 'core', {self.exe: b'fixture'}, 'foreign-x64')
        with self.assertRaisesRegex(ValueError, 'platform/components'):
            self.build()
        self.assertFalse(self.output.exists())

    def test_08_terminal_merge_and_collision(self):
        terminal = self.root / 'terminal.zip'
        make_archive(terminal, 'terminal', {'terminal/test.bin': b'fixture terminal'})
        self.build(terminal)
        manifest = json.loads((self.output / 'payload/runtime/forge-runtime.json').read_text())
        self.assertEqual(manifest['components'], ['core', 'terminal'])
        self.assertEqual((self.output / 'payload/runtime/terminal/test.bin').read_bytes(), b'fixture terminal')
        other = self.root / 'conflict.zip'
        make_archive(other, 'terminal', {self.exe: b'conflict'})
        with patch.object(package, 'ROOT', self.source), self.assertRaisesRegex(ValueError, 'conflict'):
            package.package(self.core, FRONTEND, self.root / 'conflicting', other)

    def test_09_reserved_overrides_are_rejected(self):
        self.build()
        result = self.entry('--source', str(self.source), '--print-plan')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('provided by this installer', result.stdout + result.stderr)

    def test_10_changed_core_archive_is_rejected(self):
        with zipfile.ZipFile(self.core, 'a') as archive:
            archive.writestr('untracked.txt', 'changed')
        with self.assertRaisesRegex(ValueError, 'unexpected archive'):
            self.build()
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    if not FRONTEND.is_file():
        raise SystemExit('Prepared native frontend required: set FORGE_INSTALL_UI_BINARY (with sibling manifest.json)')
    unittest.main(verbosity=2)
