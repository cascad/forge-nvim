"""Настоящий orphan/file-lock worker: управление только через private файлы."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time

mode, target_name, control_name = sys.argv[1:]
target, control = Path(target_name), Path(control_name)
if mode == 'parent':
    child = subprocess.Popen(
        [sys.executable, '-B', __file__, 'worker', str(target), str(control)],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, close_fds=True,
    )
    (control / 'parent.json').write_text(
        json.dumps({'pid': os.getpid(), 'worker': child.pid}), encoding='utf-8')
elif mode == 'worker':
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('w', encoding='utf-8') as held:
        held.write('real owned worker file lock\n')
        held.flush()
        ready = control / 'ready.json'
        pending = control / 'pending.json'
        pending.write_text(json.dumps({'pid': os.getpid(), 'parent': os.getppid(),
                                       'target': str(target)}), encoding='utf-8')
        pending.replace(ready)
        deadline = time.monotonic() + 30
        while not (control / 'release').exists():
            if time.monotonic() >= deadline:
                sys.exit(124)
            time.sleep(0.02)
else:
    raise SystemExit('unknown worker mode: ' + mode)
