"""IDE-039: наблюдение настоящей ConPTY-пробы без смены HKL/эталона/вердикта.

Windows: задать FORGE_TEST_NVIM SDK общего runner и TEMP/TMP/TMPDIR на F:.
Все артефакты — новый .tests/artifacts/conpty-layout-* каждого запуска.
--fixture читает явно выбранную копию; обновления эталона здесь нет.
"""
import argparse
import contextlib
import ctypes
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import traceback


ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tests/wezterm/conpty'


def save(folder, name, value):
    (folder / name).write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n',
                               encoding='utf-8')


def differences(want, got, path='$'):
    """Массив — одно поле: не теряем исходные записи/порядок клавиш."""
    if isinstance(want, dict) and isinstance(got, dict):
        rows = []
        for key in sorted(want.keys() | got.keys()):
            if key not in want or key not in got:
                rows.append({'path': f'{path}.{key}', 'expected_present': key in want,
                             'actual_present': key in got, 'expected': want.get(key), 'actual': got.get(key)})
            else:
                rows.extend(differences(want[key], got[key], f'{path}.{key}'))
        return rows
    return [] if want == got else [{'path': path, 'expected': want, 'actual': got}]


class Tee:
    def __init__(self, stream, log):
        self.stream, self.log = stream, log

    def write(self, text):
        self.stream.write(text)
        return self.log.write(text)

    def flush(self):
        self.stream.flush()
        self.log.flush()


def file_info(path):
    path = Path(path)
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} if path.is_file() else None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--layout', choices=('ru', 'en'))
    ap.add_argument('--fixture', type=Path, help='явная read-only копия эталона для диагностики')
    args = ap.parse_args()
    if os.name != 'nt':
        print('  SKIP WT-KBD-9 диагностика ConPTY  -- не Windows', flush=True)
        return 0

    base = ROOT / '.tests/artifacts'
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix='conpty-layout-', dir=base))
    print(f'Артефакты ConPTY: {folder}', flush=True)
    sys.path.insert(0, str(HERE))
    import harness as h
    spec = importlib.util.spec_from_file_location('forge_chords_observed', HERE / 'chords.test.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    fixture_path = (args.fixture or Path(module.FIXTURE)).resolve()
    module.FIXTURE = str(fixture_path)
    manifest = {'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'requested_layout': args.layout, 'id_filter': os.getenv('FORGE_TEST_ID'),
                'fixture': file_info(fixture_path), 'windows': list(sys.getwindowsversion()),
                'python': sys.executable, 'layout_note':
                'HKL foreground/observer/reader — метаданные, не доказательство раскладки input thread OpenConsole.'}
    original_probe, original_session, original_read = module.probe, h.Session, h.read_keys
    result, sessions, reader_context = {}, [], ['direct']
    u32 = ctypes.WinDLL('user32', use_last_error=True)
    from ctypes import wintypes as wt
    u32.GetForegroundWindow.restype = wt.HWND
    u32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
    u32.GetWindowThreadProcessId.restype = wt.DWORD
    u32.GetKeyboardLayout.argtypes = [wt.DWORD]
    u32.GetKeyboardLayout.restype = wt.HANDLE

    class ObservedSession(original_session):
        def __init__(self, argv, *a, **kw):
            self.observation = {'reader': reader_context[0], 'argv': argv, 'samples': []}
            sessions.append(self.observation)
            self.sample('create-before')
            super().__init__(argv, *a, **kw)
            self.observation.update(pid=self._pi.dwProcessId, primary_tid=self._pi.dwThreadId)
            self.sample('create-after')

        def sample(self, phase, data=None):
            row = {'phase': phase, 'monotonic_ns': time.monotonic_ns()}
            try:
                hwnd = u32.GetForegroundWindow()
                pid = wt.DWORD()
                tid = u32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid)) if hwnd else 0
                hkl = u32.GetKeyboardLayout(tid) if tid else None
                row.update(foreground_pid=pid.value, foreground_tid=tid,
                           foreground_hkl=hex(hkl or 0),
                           foreground_layout={0x419: 'ru', 0x409: 'en'}.get((hkl or 0) & 0xffff),
                           observer_thread_hkl=hex(u32.GetKeyboardLayout(0) or 0))
                pi = getattr(self, '_pi', None)
                if pi:
                    row['reader_primary_thread_hkl'] = hex(u32.GetKeyboardLayout(pi.dwThreadId) or 0)
            except Exception as e:
                row['observation_error'] = str(e)
            if data is not None:
                row['synthetic_input_hex'] = data.hex()
            self.observation['samples'].append(row)

        def write(self, data):
            self.sample('write', data)
            return super().write(data)

        def close(self):
            self.sample('close')
            return super().close()

    def observed_read(reader, *a, **kw):
        previous = reader_context[0]
        reader_context[0] = reader
        try:
            return original_read(reader, *a, **kw)
        finally:
            reader_context[0] = previous

    def observed_probe(*a, **kw):
        value = original_probe(*a, **kw)
        result.update(value)
        return value

    h.Session, h.read_keys, module.probe = ObservedSession, observed_read, observed_probe
    original_argv = sys.argv
    sys.argv = [str(HERE / 'chords.test.py')] + (['--layout', args.layout] if args.layout else [])
    code = 1
    try:
        with (folder / 'probe.log').open('w', encoding='utf-8') as log:
            with contextlib.redirect_stdout(Tee(sys.stdout, log)), contextlib.redirect_stderr(Tee(sys.stderr, log)):
                try:
                    ok, why = h.available()
                    if ok:
                        manifest['provenance'] = h.provenance()
                        manifest['openconsole'] = file_info(Path(h.CONPTY_DLL).with_name('OpenConsole.exe'))
                        manifest['nvim'] = file_info(h.NVIM)
                    else:
                        manifest['unavailable'] = why
                    code = module.main()
                except Exception as e:
                    manifest['exception'] = f'{type(e).__name__}: {e}'
                    traceback.print_exc()
    finally:
        sys.argv = original_argv
        h.Session, h.read_keys, module.probe = original_session, original_read, original_probe
        expected = None
        if result and fixture_path.is_file():
            try:
                fixture = json.loads(fixture_path.read_text(encoding='utf-8'))
                expected = fixture.get('layouts', {}).get(result['layout'])
            except Exception as e:
                manifest['fixture_read_error'] = f'{type(e).__name__}: {e}'
        foregrounds = sorted({row['foreground_layout'] for session in sessions for row in session['samples']
                              if row.get('foreground_layout')})
        manifest.update(exit_code=code, status='FAIL' if code else ('PASS' if result else 'SKIP'),
                        fixture_after=file_info(fixture_path), session_count=len(sessions),
                        probe_layout=result.get('layout'), foreground_layouts=foregrounds,
                        foreground_changed=len(foregrounds) > 1,
                        finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
        save(folder, 'actual.json', result or None)
        save(folder, 'expected.json', expected)
        delta = differences(expected, result) if result else []
        save(folder, 'difference.json', delta)
        save(folder, 'sessions.json', sessions)
        save(folder, 'manifest.json', manifest)
    for row in delta:
        print(f"DIFF {row['path']}: expected={row.get('expected')!r} actual={row.get('actual')!r}", flush=True)
    print(f"ConPTY {manifest['status']}: exit={code}, sessions={len(sessions)}, diff={len(delta)}; {folder}", flush=True)
    return code


if __name__ == '__main__':
    sys.exit(main())
