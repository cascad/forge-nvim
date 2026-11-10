"""Private deadline-bounded native job tree; no process-name/PID termination."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

mode, folder = sys.argv[1], Path(sys.argv[2])
deadline = time.monotonic() + 45
if mode == 'root':
    child = subprocess.Popen([sys.executable, '-B', __file__, 'child', str(folder)])
    while not (folder / 'child.json').exists():
        if child.poll() is not None or time.monotonic() > deadline:
            raise SystemExit('Child did not become ready')
        time.sleep(.01)
data = folder / (mode + '.json')
temporary = data.with_suffix('.tmp')
temporary.write_text(json.dumps({'pid': os.getpid(), 'ppid': os.getppid()}), 'utf-8')
temporary.replace(data)
while not (folder / 'release').exists() and time.monotonic() < deadline:
    time.sleep(.02)
