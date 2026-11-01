"""Внешний процесс держит настоящий файл для e2e временной блокировки Windows."""
from pathlib import Path
import sys
import time

target, ready, release = map(Path, sys.argv[1:])
with target.open('w', encoding='utf-8') as opened:
    opened.write('held by a real child process')
    opened.flush()
    ready.write_text('ready', encoding='utf-8')
    deadline = time.monotonic() + 5
    while not release.exists():
        if time.monotonic() >= deadline:
            sys.exit(124)
        time.sleep(0.01)
