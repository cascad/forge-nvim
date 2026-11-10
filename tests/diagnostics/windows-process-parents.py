"""Read-only Win32 ancestry audit: снимок и query-only process handles."""
import argparse
import ctypes
from ctypes import wintypes as W
import datetime
import hashlib
import json
import os
from pathlib import Path


def audit():
    if os.name != 'nt':
        raise SystemExit('Windows-only native metadata probe; Linux/macOS SDK не меняется')
    class Entry(ctypes.Structure):
        _fields_ = [('size', W.DWORD), ('usage', W.DWORD), ('pid', W.DWORD),
                    ('heap', ctypes.c_size_t), ('module', W.DWORD), ('threads', W.DWORD),
                    ('parent', W.DWORD), ('priority', W.LONG), ('flags', W.DWORD),
                    ('exe', W.WCHAR * 260)]
    k = ctypes.WinDLL('kernel32', use_last_error=True)
    k.CreateToolhelp32Snapshot.argtypes = [W.DWORD, W.DWORD]
    k.CreateToolhelp32Snapshot.restype = W.HANDLE
    for name in ('Process32FirstW', 'Process32NextW'):
        getattr(k, name).argtypes = [W.HANDLE, ctypes.POINTER(Entry)]
        getattr(k, name).restype = W.BOOL
    k.OpenProcess.argtypes = [W.DWORD, W.BOOL, W.DWORD]
    k.OpenProcess.restype = W.HANDLE
    k.CloseHandle.argtypes = [W.HANDLE]
    k.CloseHandle.restype = W.BOOL
    k.GetProcessTimes.argtypes = [W.HANDLE] + [ctypes.POINTER(W.FILETIME)] * 4
    k.GetProcessTimes.restype = W.BOOL
    snapshot = k.CreateToolhelp32Snapshot(2, 0)
    if snapshot in (None, ctypes.c_void_p(-1).value):
        raise ctypes.WinError(ctypes.get_last_error())
    rows, handles = [], []
    try:
        entry = Entry(); entry.size = ctypes.sizeof(entry)
        if not k.Process32FirstW(snapshot, ctypes.byref(entry)):
            raise ctypes.WinError(ctypes.get_last_error())
        while True:
            row = {'pid': int(entry.pid), 'parent': int(entry.parent), 'name': entry.exe}
            handle = k.OpenProcess(0x1000, False, entry.pid)  # QUERY_LIMITED_INFORMATION.
            if handle:
                handles.append(handle)  # Держим identity до конца классификации.
                times = [W.FILETIME() for _ in range(4)]
                if k.GetProcessTimes(handle, *(ctypes.byref(t) for t in times)):
                    row['creation_100ns'] = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
                else:
                    row['query_error'] = ctypes.get_last_error()
            else:
                row['open_error'] = ctypes.get_last_error()
            rows.append(row)
            if not k.Process32NextW(snapshot, ctypes.byref(entry)):
                error = ctypes.get_last_error()
                if error != 18:  # ERROR_NO_MORE_FILES.
                    raise ctypes.WinError(error)
                break
        index = {r['pid']: r for r in rows}
        for row in rows:
            parent = index.get(row['parent'])
            if row['parent'] <= 4 or row['pid'] <= 4:
                row['edge'] = 'kernel_special'
            elif not parent:
                row['edge'] = 'parent_missing'
            elif 'creation_100ns' not in row or 'creation_100ns' not in parent:
                row['edge'] = 'unknown'
            elif row['creation_100ns'] < parent['creation_100ns']:
                row['edge'] = 'older_than_parent'
                row['parent_creation_100ns'] = parent['creation_100ns']
            else:
                row['edge'] = 'creation_order_consistent'
        return {'mode': 'read-only-non-atomic-snapshot',
                'observer_pid': os.getpid(),
                'source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'captured_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'counts': {kind: sum(r['edge'] == kind for r in rows) for kind in sorted({r['edge'] for r in rows})},
                'rows': rows,
                'limits': 'Creation order is necessary, not complete ownership proof; no caller attribution.'}
    finally:
        for handle in handles:
            k.CloseHandle(handle)
        k.CloseHandle(snapshot)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    print(json.dumps({'output': str(args.output), 'counts': report['counts']}, ensure_ascii=True))
