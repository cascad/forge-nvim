"""Hold a real, owned directory against deletion; restore permissions on exit."""
import ctypes
import json
import os
from pathlib import Path
import sys
import time

owned, target, ready, release = map(lambda value: Path(value).resolve(), sys.argv[1:])
assert target.is_relative_to(owned) and target != owned and target.is_dir()
assert ready.is_relative_to(owned) and release.is_relative_to(owned)
handle = None
mode = target.parent.stat().st_mode & 0o777
try:
    if os.name == 'nt':
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                      ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
        kernel.CreateFileW.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.CreateFileW(str(target), 0x80000000, 0x3, None, 3, 0x02000000, None)
        if handle == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        kernel.RemoveDirectoryW.argtypes = [ctypes.c_wchar_p]
        kernel.RemoveDirectoryW.restype = ctypes.c_int
        if kernel.RemoveDirectoryW(str(target)):
            target.mkdir()
            raise AssertionError('Fixture did not deny native RemoveDirectoryW')
        native_error = ctypes.get_last_error()
        assert native_error in (5, 32), native_error
        reason = 'native RemoveDirectoryW denied: Windows error ' + str(native_error)
    else:
        assert os.geteuid() != 0, 'POSIX denial needs the ordinary test user'
        target.parent.chmod(0o555)
        reason = 'native parent permissions 0555'
    ready.write_text(json.dumps({'pid': os.getpid(), 'target': str(target), 'reason': reason}), encoding='utf-8')
    deadline = time.monotonic() + 45
    while not release.exists():
        if time.monotonic() >= deadline:
            raise TimeoutError('Owned test must release its denial fixture')
        time.sleep(0.01)
finally:
    if handle is not None and handle != ctypes.c_void_p(-1).value:
        kernel.CloseHandle(handle)
    if os.name != 'nt':
        target.parent.chmod(mode)
