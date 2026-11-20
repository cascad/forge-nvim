"""spec: IDE-BOOT-55. Publisher transitions; native official asset is a separate explicit case."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import platform
import tarfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('native_neovim', ROOT / 'scripts/prepare-native-neovim.py')
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)
BASE = Path(os.environ.get('FORGE_INSTALL_STAND_ROOT', str(ROOT / '.tests'))) / 'native-neovim' / str(time.time_ns())
BASE.mkdir(parents=True)


def archive(entries):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode='w:gz') as tar:
        for name, data, link in entries:
            item = tarfile.TarInfo('nvim-fixture/' + name)
            if link:
                item.type = tarfile.SYMTYPE
                item.linkname = link
                tar.addfile(item)
            else:
                item.size, item.mode = len(data), 0o755
                tar.addfile(item, io.BytesIO(data))
    return output.getvalue()


class NativeNeovim(unittest.TestCase):
    def fixture(self, entries=None):
        raw = archive(entries or [('bin/nvim', b'fixture', None)])
        path = BASE / (self._testMethodName + '.tar.gz')
        path.write_bytes(raw)
        source = dict(version='0.12.2', url='https://example.invalid/native', archive='nvim-fixture.tar.gz', sha256=hashlib.sha256(raw).hexdigest())
        return path, source, BASE / self._testMethodName

    def test_01_policies_match_upstream_and_platforms(self):
        for name in ('linux-x64', 'linux-arm64', 'macos-x64', 'macos-arm64'):
            source = native.source(name)
            self.assertEqual(len(source['sha256']), 64)
            self.assertTrue(source['url'].startswith('https://github.com/neovim/neovim/releases/download/v0.12.2/'))
        self.assertNotEqual(native.source('macos-x64')['sha256'], native.source('macos-arm64')['sha256'])

    def test_02_prepare_and_repeat_without_download(self):
        path, source, output = self.fixture()
        with patch.object(native, 'native_platform', return_value='linux-x64'), patch.object(native, 'source', return_value=source), patch.object(native, 'version', return_value='NVIM v0.12.2'), patch.object(native.urllib.request, 'urlopen', side_effect=AssertionError('Unexpected download')):
            first = native.prepare(output, path)
            self.assertEqual(first, native.prepare(output))
            self.assertEqual(first['files'], {'bin/nvim': hashlib.sha256(b'fixture').hexdigest()})

    def test_03_wrong_sha_leaves_no_output(self):
        path, source, output = self.fixture()
        path.write_bytes(b'broken')
        with patch.object(native, 'native_platform', return_value='linux-x64'), patch.object(native, 'source', return_value=source):
            with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                native.prepare(output, path)
        self.assertFalse(output.exists())

    def test_04_failed_probe_does_not_publish(self):
        path, source, output = self.fixture()
        with patch.object(native, 'native_platform', return_value='linux-x64'), patch.object(native, 'source', return_value=source), patch.object(native, 'version', side_effect=ValueError('Unexpected native version')):
            with self.assertRaisesRegex(ValueError, 'native version'):
                native.prepare(output, path)
        self.assertFalse(output.exists())

    def test_05_external_links_are_rejected(self):
        path, source, output = self.fixture([('bin/nvim', b'', '../../../outside')])
        with patch.object(native, 'native_platform', return_value='linux-x64'), patch.object(native, 'source', return_value=source):
            with self.assertRaisesRegex(ValueError, 'External'):
                native.prepare(output, path)
        self.assertFalse(output.exists())

    def test_06_existing_payload_is_preserved_on_mismatch(self):
        path, source, output = self.fixture()
        with patch.object(native, 'native_platform', return_value='linux-x64'), patch.object(native, 'source', return_value=source), patch.object(native, 'version', return_value='NVIM v0.12.2'):
            native.prepare(output, path)
            (output / 'bin/nvim').write_bytes(b'user change')
            with self.assertRaisesRegex(ValueError, 'payload mismatch'):
                native.prepare(output, path, download=True)
            self.assertEqual((output / 'bin/nvim').read_bytes(), b'user change')

    @unittest.skipUnless(os.environ.get('FORGE_NATIVE_NVIM_ARCHIVE') and platform.system() in ('Linux', 'Darwin'), 'Explicit native official archive required; fixture cases do not claim native acceptance')
    def test_07_actual_native_archive_and_repeat(self):
        output = BASE / 'actual native ü space'
        first = native.prepare(output, Path(os.environ['FORGE_NATIVE_NVIM_ARCHIVE']))
        self.assertEqual(first, native.prepare(output))
        self.assertEqual(first['native_version'], 'NVIM v0.12.2')
        (BASE / 'actual.json').write_text(json.dumps(first, indent=2), encoding='utf-8')


if __name__ == '__main__':
    unittest.main(verbosity=2)
