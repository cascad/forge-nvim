"""Прозрачная задержка готового real git log между двумя worktree."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from git_gate import publish


def main():
    real_git, gate_path, *args = sys.argv[1:]
    gate = Path(gate_path)
    target = json.loads((gate / 'target.json').read_text(encoding='utf-8'))
    same = os.path.normcase(str(Path.cwd().resolve())) == os.path.normcase(str(Path(target).resolve()))
    if not (same and 'log' in args and '--no-patch' in args and not (gate / 'release').exists()):
        return subprocess.run([real_git, *args]).returncode
    # Снимок получен настоящим Git в исходной папке. Меняется только момент
    # доставки; stdin/stdout/stderr и формат records не синтезируются.
    result = subprocess.run([real_git, *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    token = str(os.getpid()) + '-' + str(time.monotonic_ns())
    (gate / ('captured-' + token + '.stdout')).write_bytes(result.stdout)
    publish(gate / ('started-' + token + '.json'), {
        'cwd': str(Path.cwd()), 'argv': args, 'code': result.returncode,
        'sha256': hashlib.sha256(result.stdout).hexdigest(),
    })
    deadline = time.monotonic() + 30
    while not (gate / 'release').exists():
        if time.monotonic() >= deadline:
            print('Forge worktree Git gate timed out', file=sys.stderr)
            return 124
        time.sleep(0.01)
    try:
        sys.stdout.buffer.write(result.stdout)
        sys.stderr.buffer.write(result.stderr)
        sys.stdout.buffer.flush()
        sys.stderr.buffer.flush()
    finally:
        publish(gate / ('done-' + token + '.json'), {'code': result.returncode})
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
