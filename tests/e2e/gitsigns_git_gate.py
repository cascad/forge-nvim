"""Доставка real Git результатов между index show, удалением и HEAD show."""
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
    original = os.environ.get('FORGE_GIT_PROXY_ORIGINAL_CWD', os.getcwd())
    target = json.loads((gate / 'target.json').read_text(encoding='utf-8'))
    effective = original
    for i, value in enumerate(args[:-1]):
        if value == '-C':
            effective = os.path.abspath(os.path.join(effective, args[i + 1]))
    same = os.path.normcase(effective) == os.path.normcase(os.path.abspath(target))
    # На Windows cwd удерживают и launcher, и Python. Настоящий Git уже
    # завершится до marker; после него ожидание не должно мешать удалению.
    os.chdir(os.environ['FORGE_GIT_PROXY_STABLE_CWD'])
    kind = None
    if same and 'gc.auto=0' in args and 'show' in args:
        kind = 'show'
    elif 'worktree' in args and 'remove' in args:
        kind = 'remove'
    if not kind:
        return subprocess.run([real_git, *args], cwd=original).returncode
    result = subprocess.run([real_git, *args], cwd=original, capture_output=True)
    token = kind + '-' + str(os.getpid()) + '-' + str(time.monotonic_ns())
    held = not (gate / (kind + '-release')).exists()
    (gate / (token + '.stdout')).write_bytes(result.stdout)
    (gate / (token + '.stderr')).write_bytes(result.stderr)
    publish(gate / (token + '.json'), dict(
        kind=kind, cwd=original, effective_cwd=effective, argv=args, code=result.returncode,
        held=held, sha256=hashlib.sha256(result.stdout).hexdigest()))
    deadline = time.monotonic() + 30
    while not (gate / (kind + '-release')).exists():
        if time.monotonic() >= deadline:
            print('Forge Gitsigns Git gate timed out', file=sys.stderr)
            return 124
        time.sleep(.01)
    sys.stdout.buffer.write(result.stdout)
    sys.stderr.buffer.write(result.stderr)
    sys.stdout.buffer.flush()
    sys.stderr.buffer.flush()
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
