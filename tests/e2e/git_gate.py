"""Прозрачный real-Git proxy: задержка show для e2e незавершённой загрузки."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def publish(path, value):
    # Наблюдатель видит только целый JSON, а не файл между open и write.
    pending = path.with_suffix('.pending')
    pending.write_text(json.dumps(value), encoding='utf-8')
    pending.replace(path)


def main():
    real_git, gate_path, *args = sys.argv[1:]
    gate = Path(gate_path)
    delayed = 'show' in args and any(arg.endswith(':file_one.txt') for arg in args)
    if not delayed:
        return subprocess.run([real_git, *args]).returncode
    gate.mkdir(parents=True, exist_ok=True)
    token = str(os.getpid()) + '-' + str(time.monotonic_ns())
    publish(gate / ('started-' + token + '.json'), args)
    deadline = time.monotonic() + 25
    while not (gate / 'release').exists():
        if time.monotonic() >= deadline:
            print('Forge e2e Git gate timed out', file=sys.stderr)
            return 124
        time.sleep(0.01)
    result = subprocess.run([real_git, *args])
    publish(gate / ('done-' + token + '.json'), {'code': result.returncode})
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
