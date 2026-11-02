"""Живой Git либо доставка готового результата между index show и удалением."""
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
    worktree = target['worktree'] if isinstance(target, dict) else target
    effective = original
    for i, value in enumerate(args[:-1]):
        if value == '-C':
            effective = os.path.abspath(os.path.join(effective, args[i + 1]))
    def normalized(path):
        return os.path.normcase(os.path.abspath(path))

    same = normalized(effective) == normalized(worktree)
    if isinstance(target, dict) and '--git-dir' in args:
        same = same or normalized(args[args.index('--git-dir') + 1]) == normalized(target['gitdir'])
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
    mode = os.environ.get('FORGE_GITSIGNS_GATE_MODE', 'completed')
    if kind == 'show' and mode == 'live' and not (gate / 'show-release').exists():
        child = subprocess.Popen([real_git, *args], cwd=original, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        token = 'show-live-' + str(os.getpid()) + '-' + str(time.monotonic_ns())
        try:
            first = child.stdout.read(1)
            publish(gate / (token + '.json'), dict(
                kind=kind, phase='live', cwd=original, effective_cwd=effective, argv=args,
                git_pid=child.pid, alive=child.poll() is None, held=True))
            deadline = time.monotonic() + 30
            while not (gate / 'show-release').exists():
                if time.monotonic() >= deadline:
                    raise TimeoutError('Forge live Git gate timed out')
                time.sleep(.01)
            alive_before_release = child.poll() is None
            output, errors = child.communicate(timeout=5)
            output = first + output
            (gate / (token + '.stdout')).write_bytes(output)
            (gate / (token + '.stderr')).write_bytes(errors)
            publish(gate / ('show-result-' + token + '.json'), dict(
                kind=kind, phase='result', code=child.returncode, held=False,
                alive_before_release=alive_before_release, bytes=len(output),
                sha256=hashlib.sha256(output).hexdigest()))
            sys.stdout.buffer.write(output)
            sys.stderr.buffer.write(errors)
            return child.returncode
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate(timeout=5)
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
