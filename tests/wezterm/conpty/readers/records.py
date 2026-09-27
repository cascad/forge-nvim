"""Читатель «записи консоли»: ReadConsoleInputW в псевдоконсоли, журнал
KEY_EVENT: vk, sc, uc, down, ctrl_state (add-nvim-chords-on-windows, design,
решение 6). Путь журнала — $FORGE_KEYLOG, первая строка — ready."""
import ctypes
import ctypes.wintypes as wt
import os

k32 = ctypes.WinDLL('kernel32', use_last_error=True)


class KEY_EVENT_RECORD(ctypes.Structure):
    _fields_ = [('bKeyDown', wt.BOOL), ('wRepeatCount', wt.WORD), ('wVirtualKeyCode', wt.WORD),
                ('wVirtualScanCode', wt.WORD), ('uChar', wt.WCHAR), ('dwControlKeyState', wt.DWORD)]


class _EVENT(ctypes.Union):
    _fields_ = [('KeyEvent', KEY_EVENT_RECORD), ('_pad', ctypes.c_byte * 16)]


class INPUT_RECORD(ctypes.Structure):
    _fields_ = [('EventType', wt.WORD), ('Event', _EVENT)]


h = k32.GetStdHandle(-10)
k32.SetConsoleMode(h, 0)  # без обработки: каждая запись как есть
rec = (INPUT_RECORD * 64)()
n = wt.DWORD()
with open(os.environ['FORGE_KEYLOG'], 'w', encoding='utf-8') as f:
    f.write('ready\n')
    f.flush()
    while k32.ReadConsoleInputW(h, rec, 64, ctypes.byref(n)):
        for i in range(n.value):
            if rec[i].EventType != 1:
                continue
            k = rec[i].Event.KeyEvent
            f.write(f'vk={k.wVirtualKeyCode} sc={k.wVirtualScanCode} uc={ord(k.uChar) if k.uChar else 0} '
                    f'down={int(bool(k.bKeyDown))} cs={k.dwControlKeyState}\n')
        f.flush()
