"""Private directory links for cleanup E2E; never traverse/delete the target."""
import argparse
import os
from pathlib import Path
import struct

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('root', type=Path)
p.add_argument('link', type=Path)
p.add_argument('target', type=Path)
p.add_argument('--raw-slashes', action='store_true')
a = p.parse_args()
root = a.root.resolve()
assert a.link.parent.resolve().is_relative_to(root) and a.target.resolve().is_relative_to(root)
assert not os.path.lexists(a.link)
if os.name != 'nt':
    assert not a.raw_slashes
    os.symlink(a.target, a.link, target_is_directory=True)
else:
    import ctypes
    from ctypes import wintypes as W
    target = os.path.abspath(a.target)
    if a.raw_slashes: target = target.replace('\\', '/')
    substitute = ('\\??\\' + target).encode('utf-16-le')
    printed = target.encode('utf-16-le')
    body = struct.pack('<HHHH', 0, len(substitute), len(substitute) + 2, len(printed)) + substitute + b'\0\0' + printed + b'\0\0'
    data = struct.pack('<IHH', 0xA0000003, len(body), 0) + body
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateFileW.argtypes = (W.LPCWSTR,W.DWORD,W.DWORD,W.LPVOID,W.DWORD,W.DWORD,W.HANDLE)
    kernel.CreateFileW.restype = W.HANDLE
    kernel.DeviceIoControl.argtypes = (W.HANDLE,W.DWORD,W.LPVOID,W.DWORD,W.LPVOID,W.DWORD,ctypes.POINTER(W.DWORD),W.LPVOID)
    kernel.CloseHandle.argtypes = (W.HANDLE,)
    a.link.mkdir()
    handle = kernel.CreateFileW(str(a.link),0x40000000,7,None,3,0x02200000,None)
    assert handle != W.HANDLE(-1).value, ctypes.get_last_error()
    try:
        returned=W.DWORD();buffer=ctypes.create_string_buffer(data)
        assert kernel.DeviceIoControl(handle,0x900A4,buffer,len(data),None,0,ctypes.byref(returned),None), ctypes.get_last_error()
    finally:
        kernel.CloseHandle(handle)
