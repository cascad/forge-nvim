"""Читатель «сырой VT-ввод»: консольный ввод в режиме
ENABLE_VIRTUAL_TERMINAL_INPUT без обработки — байты, как их отдаёт ConPTY
программе в VT-режиме (add-nvim-chords-on-windows, design, решение 6). Журнал
$FORGE_KEYLOG: первая строка ready, дальше — hex каждого чтения."""
import ctypes
import os

k32 = ctypes.WinDLL('kernel32', use_last_error=True)
h = k32.GetStdHandle(-10)
k32.SetConsoleMode(h, 0x200)  # только ENABLE_VIRTUAL_TERMINAL_INPUT
buf = ctypes.create_string_buffer(256)
n = ctypes.c_uint()
with open(os.environ['FORGE_KEYLOG'], 'w', encoding='utf-8') as f:
    f.write('ready\n')
    f.flush()
    while k32.ReadFile(h, buf, 256, ctypes.byref(n), None):
        f.write(buf.raw[:n.value].hex(' ') + '\n')
        f.flush()
