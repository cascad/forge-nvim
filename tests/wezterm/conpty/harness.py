"""Сеанс ConPTY с флагами WezTerm 20240203 — стенд для проб клавиатуры на Windows
(add-nvim-chords-on-windows, design, решение 6).

Стенд играет роль терминала: создаёт псевдоконсоль из conpty.dll поставки
WezTerm с теми же флагами (RESIZE_QUIRK | WIN32_INPUT_MODE), запускает в ней
программу, пишет байты, которые написал бы WezTerm, и читает всё, что программа
выводит. Отвечает на запросы как WezTerm 20240203 на Windows: на XTVERSION —
версией, на `CSI ? u` — ничего (kitty выключен, FIXLOG §41).

Ресурсы: дерево процессов сеанса живёт в Job object с KILL_ON_JOB_CLOSE, поэтому
закрытие сеанса (или падение стенда) гасит и программу, и её потомков;
псевдоконсоль закрывается ClosePseudoConsole (гасит OpenConsole.exe).

Энтропия собирается один раз в начале (provenance): путь, SHA-256 и версия
conpty.dll, версии WezTerm и nvim, активная раскладка.

    with Session(['nvim', '--clean']) as s:
        s.wait_for(lambda out: b'~' in out, 5)
        s.write(b'\\x1b[25;5~')
        text = s.output()
"""
import ctypes
import ctypes.wintypes as wt
import hashlib
import os
import subprocess
import threading
import time

CONPTY_DLL = os.environ.get('FORGE_CONPTY_DLL', r'C:\Program Files\WezTerm\conpty.dll')
NVIM = os.environ.get('FORGE_TEST_NVIM', 'nvim')
WEZTERM_VERSION = b'WezTerm 20240203-110809-5046fc22'

PSEUDOCONSOLE_RESIZE_QUIRK = 0x2
PSEUDOCONSOLE_WIN32_INPUT_MODE = 0x4
EXTENDED_STARTUPINFO_PRESENT = 0x00080000
CREATE_UNICODE_ENVIRONMENT = 0x00000400
CREATE_SUSPENDED = 0x00000004
PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = 0x00020016
STARTF_USESTDHANDLES = 0x100
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000
JobObjectExtendedLimitInformation = 9

k32 = ctypes.WinDLL('kernel32', use_last_error=True)
u32 = ctypes.WinDLL('user32', use_last_error=True)


class COORD(ctypes.Structure):
    _fields_ = [('X', ctypes.c_short), ('Y', ctypes.c_short)]


class STARTUPINFOW(ctypes.Structure):
    _fields_ = [('cb', wt.DWORD), ('lpReserved', wt.LPWSTR), ('lpDesktop', wt.LPWSTR),
                ('lpTitle', wt.LPWSTR), ('dwX', wt.DWORD), ('dwY', wt.DWORD),
                ('dwXSize', wt.DWORD), ('dwYSize', wt.DWORD), ('dwXCountChars', wt.DWORD),
                ('dwYCountChars', wt.DWORD), ('dwFillAttribute', wt.DWORD), ('dwFlags', wt.DWORD),
                ('wShowWindow', wt.WORD), ('cbReserved2', wt.WORD), ('lpReserved2', ctypes.c_void_p),
                ('hStdInput', wt.HANDLE), ('hStdOutput', wt.HANDLE), ('hStdError', wt.HANDLE)]


class STARTUPINFOEXW(ctypes.Structure):
    _fields_ = [('StartupInfo', STARTUPINFOW), ('lpAttributeList', ctypes.c_void_p)]


class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [('hProcess', wt.HANDLE), ('hThread', wt.HANDLE),
                ('dwProcessId', wt.DWORD), ('dwThreadId', wt.DWORD)]


class IO_COUNTERS(ctypes.Structure):
    _fields_ = [(n, ctypes.c_ulonglong) for n in (
        'ReadOperationCount', 'WriteOperationCount', 'OtherOperationCount',
        'ReadTransferCount', 'WriteTransferCount', 'OtherTransferCount')]


class JOBOBJECT_BASIC_LIMIT_INFORMATION(ctypes.Structure):
    _fields_ = [('PerProcessUserTimeLimit', ctypes.c_longlong), ('PerJobUserTimeLimit', ctypes.c_longlong),
                ('LimitFlags', wt.DWORD), ('MinimumWorkingSetSize', ctypes.c_size_t),
                ('MaximumWorkingSetSize', ctypes.c_size_t), ('ActiveProcessLimit', wt.DWORD),
                ('Affinity', ctypes.c_size_t), ('PriorityClass', wt.DWORD), ('SchedulingClass', wt.DWORD)]


class JOBOBJECT_EXTENDED_LIMIT_INFORMATION(ctypes.Structure):
    _fields_ = [('BasicLimitInformation', JOBOBJECT_BASIC_LIMIT_INFORMATION), ('IoInfo', IO_COUNTERS),
                ('ProcessMemoryLimit', ctypes.c_size_t), ('JobMemoryLimit', ctypes.c_size_t),
                ('PeakProcessMemoryUsed', ctypes.c_size_t), ('PeakJobMemoryUsed', ctypes.c_size_t)]


class HarnessError(RuntimeError):
    pass


def _check(ok, what):
    if not ok:
        raise HarnessError(f'{what}: {ctypes.WinError(ctypes.get_last_error())}')


def available():
    """→ (True, '') или (False, причина SKIP)."""
    if os.name != 'nt':
        return False, 'не Windows'
    if not os.path.isfile(CONPTY_DLL):
        return False, f'нет {CONPTY_DLL}'
    return True, ''


def _file_version(path):
    ver = ctypes.WinDLL('version')
    ver.VerQueryValueW.argtypes = [ctypes.c_void_p, wt.LPCWSTR, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(wt.UINT)]
    size = ver.GetFileVersionInfoSizeW(path, None)
    if not size:
        return None
    buf = ctypes.create_string_buffer(size)
    if not ver.GetFileVersionInfoW(path, 0, size, buf):
        return None
    ptr, n = ctypes.c_void_p(), wt.UINT()
    if not ver.VerQueryValueW(buf, '\\', ctypes.byref(ptr), ctypes.byref(n)):
        return None
    ffi = ctypes.cast(ptr, ctypes.POINTER(wt.DWORD * 13)).contents
    ms, ls = ffi[2], ffi[3]
    return f'{ms >> 16}.{ms & 0xFFFF}.{ls >> 16}.{ls & 0xFFFF}'


def keyboard_layout():
    """Активная раскладка (HKL) окна на переднем плане: 'ru' | 'en' | hex."""
    hwnd = u32.GetForegroundWindow()
    tid = u32.GetWindowThreadProcessId(hwnd, None) if hwnd else 0
    hkl = u32.GetKeyboardLayout(tid) & 0xFFFF
    return {0x0419: 'ru', 0x0409: 'en'}.get(hkl, f'{hkl:04x}')


def _first_line(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return (r.stdout or r.stderr).splitlines()[0].strip()
    except Exception as e:  # noqa: BLE001 — происхождение, не проверка
        return f'недоступно: {e}'


def provenance():
    """Энтропия стенда — один раз, в начале прогона."""
    with open(CONPTY_DLL, 'rb') as f:
        sha = hashlib.sha256(f.read()).hexdigest()
    return {
        'conpty_dll': CONPTY_DLL,
        'conpty_sha256': sha,
        'conpty_version': _file_version(CONPTY_DLL),
        'wezterm': _first_line(['wezterm', '--version']),
        'nvim': _first_line([NVIM, '--version']),
        'layout': keyboard_layout(),
    }


class Session:
    """Одна программа в одной псевдоконсоли. Контекстный менеджер."""

    def __init__(self, argv, env=None, cols=100, rows=30, timeout=30.0):
        self.argv = argv
        self.deadline = time.monotonic() + timeout
        self._received = bytearray()
        self._lock = threading.Lock()
        self._answered_xtversion = False
        self._handles = []
        self._hpc = None
        self._job = None
        self._pi = None
        self._conpty = ctypes.WinDLL(CONPTY_DLL, use_last_error=True)
        try:
            self._start(env or {}, cols, rows)
        except BaseException:
            self.close()
            raise

    # --- жизненный цикл -------------------------------------------------------
    def _pipe(self):
        r, w = wt.HANDLE(), wt.HANDLE()
        _check(k32.CreatePipe(ctypes.byref(r), ctypes.byref(w), None, 0), 'CreatePipe')
        return r, w

    def _start(self, env_extra, cols, rows):
        in_r, self._in_w = self._pipe()
        self._out_r, out_w = self._pipe()
        self._handles += [self._in_w, self._out_r]
        hpc = ctypes.c_void_p()
        create = self._conpty.CreatePseudoConsole
        create.argtypes = [COORD, wt.HANDLE, wt.HANDLE, wt.DWORD, ctypes.POINTER(ctypes.c_void_p)]
        hr = create(COORD(cols, rows), in_r, out_w,
                    PSEUDOCONSOLE_RESIZE_QUIRK | PSEUDOCONSOLE_WIN32_INPUT_MODE, ctypes.byref(hpc))
        # Псевдоконсоль держит свои копии; наши закрываем сразу — иначе поток
        # чтения не увидит EOF после ClosePseudoConsole.
        k32.CloseHandle(in_r)
        k32.CloseHandle(out_w)
        if hr != 0:
            raise HarnessError(f'CreatePseudoConsole hr={hr & 0xFFFFFFFF:#x}')
        self._hpc = hpc

        size = ctypes.c_size_t()
        k32.InitializeProcThreadAttributeList(None, 1, 0, ctypes.byref(size))
        self._attr = ctypes.create_string_buffer(size.value)
        _check(k32.InitializeProcThreadAttributeList(self._attr, 1, 0, ctypes.byref(size)),
               'InitializeProcThreadAttributeList')
        k32.UpdateProcThreadAttribute.argtypes = [ctypes.c_void_p, wt.DWORD, ctypes.c_size_t, ctypes.c_void_p,
                                                  ctypes.c_size_t, ctypes.c_void_p, ctypes.c_void_p]
        _check(k32.UpdateProcThreadAttribute(self._attr, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hpc,
                                             ctypes.sizeof(ctypes.c_void_p), None, None),
               'UpdateProcThreadAttribute')

        self._job = k32.CreateJobObjectW(None, None)
        _check(self._job, 'CreateJobObject')
        info = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
        info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        _check(k32.SetInformationJobObject(self._job, JobObjectExtendedLimitInformation,
                                           ctypes.byref(info), ctypes.sizeof(info)), 'SetInformationJobObject')

        si = STARTUPINFOEXW()
        si.StartupInfo.cb = ctypes.sizeof(STARTUPINFOEXW)
        si.lpAttributeList = ctypes.cast(self._attr, ctypes.c_void_p)
        si.StartupInfo.dwFlags = STARTF_USESTDHANDLES  # NULL-хэндлы → программа берёт псевдоконсоль
        env = dict(os.environ)
        env.update({'TERM_PROGRAM': 'WezTerm', 'TERM': 'xterm-256color'})
        env.update(env_extra)
        block = ctypes.create_unicode_buffer('\0'.join(f'{k}={v}' for k, v in env.items()) + '\0\0')
        cmdline = ctypes.create_unicode_buffer(subprocess.list2cmdline(self.argv))
        pi = PROCESS_INFORMATION()
        _check(k32.CreateProcessW(None, cmdline, None, None, False,
                                  EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT | CREATE_SUSPENDED,
                                  block, None, ctypes.byref(si), ctypes.byref(pi)), 'CreateProcessW')
        self._pi = pi
        _check(k32.AssignProcessToJobObject(self._job, pi.hProcess), 'AssignProcessToJobObject')
        k32.ResumeThread(pi.hThread)
        self._reader_thread = threading.Thread(target=self._reader, daemon=True)
        self._reader_thread.start()

    def _reader(self):
        chunk = ctypes.create_string_buffer(65536)
        n = wt.DWORD()
        while k32.ReadFile(self._out_r, chunk, 65536, ctypes.byref(n), None) and n.value:
            data = chunk.raw[:n.value]
            with self._lock:
                self._received.extend(data)
                if not self._answered_xtversion and b'\x1b[>0q' in self._received:
                    self._answered_xtversion = True
                    self.write(b'\x1bP>|' + WEZTERM_VERSION + b'\x1b\\')

    def close(self):
        if self._job:
            k32.CloseHandle(self._job)  # KILL_ON_JOB_CLOSE: гасит программу и потомков
            self._job = None
        if self._pi:
            k32.WaitForSingleObject(self._pi.hProcess, 3000)
            k32.CloseHandle(self._pi.hProcess)
            k32.CloseHandle(self._pi.hThread)
            self._pi = None
        if self._hpc:
            self._conpty.ClosePseudoConsole(self._hpc)  # гасит OpenConsole.exe, закрывает out-канал
            self._hpc = None
        # Закрыть канал, на котором висит ReadFile, нельзя — сначала EOF и выход потока.
        t = getattr(self, '_reader_thread', None)
        if t:
            t.join(5)
        for h in self._handles:
            k32.CloseHandle(h)
        self._handles = []

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False

    # --- ввод и вывод ---------------------------------------------------------
    def write(self, data):
        n = wt.DWORD()
        _check(k32.WriteFile(self._in_w, data, len(data), ctypes.byref(n), None), 'WriteFile')

    def output(self):
        with self._lock:
            return bytes(self._received)

    def wait_for(self, pred, timeout):
        """Ждать, пока pred(вывод) не станет истинным; → True/False (таймаут)."""
        end = min(time.monotonic() + timeout, self.deadline)
        while time.monotonic() < end:
            if pred(self.output()):
                return True
            time.sleep(0.05)
        return pred(self.output())

    def settle(self, seconds):
        """Подождать, пока программа отработает ввод (ни на что не завязываясь)."""
        time.sleep(max(0.0, min(seconds, self.deadline - time.monotonic())))


def win32_key(vk, sc, uc, down, ctrl_state, repeat=1):
    """Запись win32-input-mode: ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _"""
    return f'\x1b[{vk};{sc};{uc};{1 if down else 0};{ctrl_state};{repeat}_'.encode()


READERS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'readers')
READERS = {
    # читатель → argv; журнал — в $FORGE_KEYLOG
    'nvim': lambda: [NVIM, '--clean', '-u', 'NONE', '-i', 'NONE', '-n',
                     '--cmd', 'luafile ' + os.path.join(READERS_DIR, 'nvim_onkey.lua')],
    'records': lambda: ['python', os.path.join(READERS_DIR, 'records.py')],
    'vt': lambda: ['python', os.path.join(READERS_DIR, 'vt.py')],
    # nvim_forge этого репо (NVIM_APPNAME + XDG_CONFIG_HOME задаёт вызывающий)
    'nvim_forge': lambda: [NVIM, '--cmd', 'luafile ' + os.path.join(READERS_DIR, 'forge_onkey.lua')],
}


def read_keys(reader, inputs, pause=0.25, timeout=60.0, env=None):
    """Запустить читателя в псевдоконсоли и подать ему входы по одному.
    → список (вход, [строки журнала на этот вход]). Журнал — во временном
    файле, удаляется на всех путях."""
    import tempfile
    base = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(READERS_DIR))), '..', '.tests', 'tmp')
    os.makedirs(base, exist_ok=True)
    fd, log = tempfile.mkstemp(prefix='forge-conpty-', suffix='.log', dir=base)
    os.close(fd)
    try:
        with Session(READERS[reader](), env=dict(env or {}, FORGE_KEYLOG=log), timeout=timeout) as s:
            def lines():
                with open(log, encoding='utf-8', errors='replace') as f:
                    return f.read().splitlines()
            end = time.monotonic() + 40
            while time.monotonic() < end and not lines()[:1] == ['ready']:
                time.sleep(0.05)
            if lines()[:1] != ['ready']:
                raise HarnessError(f'читатель {reader} не запустился: {s.output()[-300:]!r}')
            s.settle({'nvim': 0.5, 'nvim_forge': 2.0}.get(reader, 0.2))
            out = []
            for data in inputs:
                before = len(lines())
                s.write(data)
                s.settle(pause)
                out.append((data, lines()[before:]))
            return out
    finally:
        try:
            os.remove(log)
        except OSError:
            pass
